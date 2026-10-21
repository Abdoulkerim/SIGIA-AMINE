-- Require a coefficient for every subject in every class-year assignment.
-- Existing assignments inherit their former subject coefficient once as a safe backfill.
begin;

update public.subject_class_assignments assignment
set coefficient_override = subject.coefficient
from public.subjects subject
where subject.id = assignment.subject_id
  and assignment.coefficient_override is null;

alter table public.subject_class_assignments
  alter column coefficient_override set not null;

-- PostgreSQL cannot remove an argument default with CREATE OR REPLACE.
-- Drop the prior signature first so the coefficient can become mandatory.
drop function if exists public.assign_subject_to_class(uuid, uuid, uuid, numeric, numeric, boolean);

create or replace function public.assign_subject_to_class(
  p_school_year_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_coefficient_override numeric,
  p_weekly_hours_override numeric default null,
  p_is_required boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_user public.users%rowtype;
  v_class_school uuid;
  v_class_year uuid;
  v_subject_school uuid;
  v_id uuid;
begin
  select * into v_user from public.users where id = auth.uid() and status = 'active';
  if v_user.id is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_user.school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;

  select school_id, school_year_id into v_class_school, v_class_year
  from public.classes where id = p_class_id and is_active = true;
  if v_class_school is null then raise exception 'INVALID_CLASS'; end if;
  if v_class_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: class'; end if;
  if v_class_year <> p_school_year_id then raise exception 'CLASS_YEAR_MISMATCH'; end if;

  if not exists (
    select 1 from public.school_years
    where id = p_school_year_id and school_id = v_user.school_id
  ) then raise exception 'INVALID_SCHOOL_YEAR'; end if;

  select school_id into v_subject_school
  from public.subjects where id = p_subject_id and is_active = true;
  if v_subject_school is null then raise exception 'INVALID_SUBJECT'; end if;
  if v_subject_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: subject'; end if;

  if p_coefficient_override is null or p_coefficient_override <= 0 then raise exception 'SUBJECT_COEFFICIENT_INVALID'; end if;
  if p_weekly_hours_override is not null and p_weekly_hours_override <= 0 then raise exception 'SUBJECT_WEEKLY_HOURS_INVALID'; end if;

  insert into public.subject_class_assignments(
    school_id, school_year_id, class_id, subject_id,
    coefficient_override, weekly_hours_override, is_required, is_active
  ) values (
    v_user.school_id, p_school_year_id, p_class_id, p_subject_id,
    p_coefficient_override, p_weekly_hours_override, p_is_required, true
  )
  on conflict (school_year_id, class_id, subject_id) do update set
    coefficient_override = excluded.coefficient_override,
    weekly_hours_override = excluded.weekly_hours_override,
    is_required = excluded.is_required,
    is_active = true,
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.assign_subject_to_class(uuid, uuid, uuid, numeric, numeric, boolean) from public, anon;
grant execute on function public.assign_subject_to_class(uuid, uuid, uuid, numeric, numeric, boolean) to authenticated;

CREATE OR REPLACE FUNCTION public.generate_report_card_draft(
  p_student_id uuid,
  p_school_year_id uuid,
  p_period_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_school uuid;
  v_student_school uuid;
  v_period public.academic_periods%rowtype;
  v_enrollment public.enrollments%rowtype;
  v_report_id uuid;
  v_average numeric;
  v_coefficient numeric;
  v_total numeric := 0;
  v_weight numeric := 0;
  v_item record;
BEGIN
  SELECT school_id
  INTO v_user_school
  FROM public.users
  WHERE id = (SELECT auth.uid());

  SELECT school_id
  INTO v_student_school
  FROM public.students
  WHERE id = p_student_id;

  IF v_user_school IS NULL OR v_student_school IS NULL THEN
    RAISE EXCEPTION 'SCHOOL_CONTEXT_REQUIRED';
  END IF;

  IF v_user_school <> v_student_school THEN
    RAISE EXCEPTION 'CROSS_SCHOOL_STUDENT';
  END IF;

  IF NOT app.is_super_admin()
     AND NOT app.has_permission('report_cards.generate', v_user_school) THEN
    RAISE EXCEPTION 'PERMISSION_REQUIRED:report_cards.generate';
  END IF;

  SELECT *
  INTO v_period
  FROM public.academic_periods
  WHERE id = p_period_id;

  IF NOT FOUND OR v_period.school_year_id <> p_school_year_id THEN
    RAISE EXCEPTION 'PERIOD_YEAR_MISMATCH';
  END IF;

  IF v_period.is_closed = false
     AND NOT app.has_permission('report_cards.generate', v_user_school) THEN
    RAISE EXCEPTION 'REPORT_CARD_GENERATION_NOT_AUTHORIZED';
  END IF;

  SELECT *
  INTO v_enrollment
  FROM public.enrollments e
  WHERE e.student_id = p_student_id
    AND e.school_year_id = p_school_year_id
    AND e.status = 'enrolled'
  ORDER BY e.updated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'STUDENT_NOT_ENROLLED';
  END IF;

  -- Vérifier l'existence de la classe sans variable inutilisée.
  IF NOT EXISTS (
    SELECT 1
    FROM public.classes
    WHERE id = v_enrollment.class_id
  ) THEN
    RAISE EXCEPTION 'CLASS_NOT_FOUND';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.grades g
    JOIN public.assessments a ON a.id = g.assessment_id
    WHERE g.student_id = p_student_id
      AND a.school_year_id = p_school_year_id
      AND a.period_id = p_period_id
      AND a.class_id = v_enrollment.class_id
      AND a.is_published = true
  ) THEN
    RAISE EXCEPTION 'NO_PUBLISHED_GRADES';
  END IF;

  SELECT id
  INTO v_report_id
  FROM public.report_cards
  WHERE student_id = p_student_id
    AND period_id = p_period_id
  FOR UPDATE;

  IF v_report_id IS NULL THEN
    INSERT INTO public.report_cards (
      student_id,
      school_id,
      school_year_id,
      period_id,
      class_id,
      status,
      generated_at
    )
    VALUES (
      p_student_id,
      v_user_school,
      p_school_year_id,
      p_period_id,
      v_enrollment.class_id,
      'draft',
      now()
    )
    RETURNING id INTO v_report_id;
  ELSE
    IF EXISTS (
      SELECT 1
      FROM public.report_cards rc
      WHERE rc.id = v_report_id
        AND rc.status = 'published'
    ) THEN
      RAISE EXCEPTION 'PUBLISHED_REPORT_CARD_EXISTS';
    END IF;

    UPDATE public.report_cards
    SET class_id = v_enrollment.class_id,
        school_year_id = p_school_year_id,
        status = 'draft',
        generated_at = now(),
        published_at = NULL,
        updated_at = now()
    WHERE id = v_report_id;

    DELETE FROM public.report_card_items
    WHERE report_card_id = v_report_id;
  END IF;

  FOR v_item IN
    SELECT
      assignment.subject_id,
      assignment.coefficient_override AS effective_coefficient,
      subject.name AS subject_name
    FROM public.subject_class_assignments assignment
    JOIN public.subjects subject
      ON subject.id = assignment.subject_id
    WHERE assignment.school_id = v_user_school
      AND assignment.school_year_id = p_school_year_id
      AND assignment.class_id = v_enrollment.class_id
      AND assignment.is_active = true
      AND subject.is_active = true
    ORDER BY subject.name
  LOOP
    SELECT ROUND(AVG(g.normalized_score), 2)
    INTO v_average
    FROM public.grades g
    JOIN public.assessments a
      ON a.id = g.assessment_id
    WHERE g.student_id = p_student_id
      AND a.school_year_id = p_school_year_id
      AND a.period_id = p_period_id
      AND a.class_id = v_enrollment.class_id
      AND a.subject_id = v_item.subject_id
      AND a.is_published = true;

    IF v_average IS NOT NULL THEN
      v_coefficient := v_item.effective_coefficient;

      INSERT INTO public.report_card_items (
        report_card_id,
        subject_id,
        average,
        coefficient
      )
      VALUES (
        v_report_id,
        v_item.subject_id,
        v_average,
        v_coefficient
      );

      v_total := v_total + (v_average * v_coefficient);
      v_weight := v_weight + v_coefficient;
    END IF;
  END LOOP;

  IF v_weight <= 0 THEN
    RAISE EXCEPTION 'NO_REPORT_CARD_ITEMS';
  END IF;

  UPDATE public.report_cards
  SET general_average = ROUND(v_total / v_weight, 2),
      rank = NULL,
      decision = NULL,
      status = 'draft',
      generated_at = COALESCE(generated_at, now()),
      published_at = NULL,
      updated_at = now()
  WHERE id = v_report_id;

  RETURN v_report_id;
END;
$$;

notify pgrst, 'reload schema';
commit;
