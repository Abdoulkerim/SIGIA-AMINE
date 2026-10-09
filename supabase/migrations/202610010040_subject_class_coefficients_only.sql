begin;

create or replace function app.validate_assessment_publication()
returns trigger
language plpgsql
as $$
begin
  if new.is_published and not app.has_permission('grades.publish', new.school_id) and not app.is_super_admin() then
    if tg_op = 'INSERT' or (tg_op = 'UPDATE' and not old.is_published) then
      raise exception 'PERMISSION_REQUIRED: grades.publish';
    end if;
  end if;
  if tg_op = 'UPDATE' and old.is_published and (
    new.title is distinct from old.title
    or new.max_score is distinct from old.max_score
    or new.class_id is distinct from old.class_id
    or new.subject_id is distinct from old.subject_id
  ) then
    raise exception 'PUBLISHED_ASSESSMENT_LOCKED';
  end if;
  return new;
end;
$$;

drop function public.create_assessment_type(text, text, numeric);
drop function public.create_assessment(uuid, uuid, uuid, uuid, uuid, uuid, text, date, numeric, numeric);

create function public.create_assessment_type(p_code text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_id uuid;
begin
  select school_id into v_school_id from public.users where id = (select auth.uid());
  if v_school_id is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if not app.is_super_admin() and not app.has_permission('assessments.manage', v_school_id) then
    raise exception 'PERMISSION_REQUIRED: assessments.manage';
  end if;
  insert into public.assessment_types(school_id, code, name)
  values(v_school_id, trim(p_code), trim(p_name))
  returning id into v_id;
  return v_id;
end;
$$;

create function public.create_assessment(
  p_school_year_id uuid,
  p_period_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_teacher_id uuid,
  p_assessment_type_id uuid,
  p_title text,
  p_assessment_date date,
  p_max_score numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_id uuid;
begin
  select school_id into v_school_id from public.users where id = (select auth.uid());
  if v_school_id is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if not app.is_super_admin() and not app.can_manage_assessment_for_class_subject(v_school_id, p_school_year_id, p_class_id, p_subject_id) then
    raise exception 'PERMISSION_REQUIRED: assessments.manage';
  end if;
  insert into public.assessments(
    school_id, school_year_id, period_id, class_id, subject_id,
    teacher_id, assessment_type_id, title, assessment_date, max_score
  ) values (
    v_school_id, p_school_year_id, p_period_id, p_class_id, p_subject_id,
    p_teacher_id, p_assessment_type_id, trim(p_title), p_assessment_date, p_max_score
  ) returning id into v_id;
  return v_id;
end;
$$;

create or replace function app.validate_assessment_021()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year public.school_years%rowtype;
  v_period public.academic_periods%rowtype;
  v_class public.classes%rowtype;
  v_subject public.subjects%rowtype;
  v_type public.assessment_types%rowtype;
  v_teacher public.employees%rowtype;
begin
  select * into v_year from public.school_years where id = new.school_year_id;
  if not found then raise exception 'INVALID_SCHOOL_YEAR'; end if;
  if v_year.school_id <> new.school_id then raise exception 'CROSS_SCHOOL: assessments.school_year_id'; end if;

  select * into v_period from public.academic_periods where id = new.period_id;
  if not found then raise exception 'INVALID_PERIOD'; end if;
  if v_period.school_year_id <> new.school_year_id then raise exception 'PERIOD_YEAR_MISMATCH'; end if;
  if v_period.is_closed then raise exception 'PERIOD_CLOSED'; end if;
  if new.assessment_date < v_period.start_date or new.assessment_date > v_period.end_date then raise exception 'ASSESSMENT_DATE_OUTSIDE_PERIOD'; end if;

  select * into v_class from public.classes where id = new.class_id;
  if not found then raise exception 'INVALID_CLASS'; end if;
  if v_class.school_id <> new.school_id or v_class.school_year_id <> new.school_year_id then raise exception 'INVALID_CLASS_YEAR'; end if;
  if not v_class.is_active then raise exception 'CLASS_INACTIVE'; end if;

  select * into v_subject from public.subjects where id = new.subject_id;
  if not found then raise exception 'INVALID_SUBJECT'; end if;
  if v_subject.school_id <> new.school_id or not v_subject.is_active then raise exception 'SUBJECT_INACTIVE'; end if;
  if not exists (
    select 1 from public.subject_class_assignments assignment
    where assignment.school_id = new.school_id
      and assignment.school_year_id = new.school_year_id
      and assignment.class_id = new.class_id
      and assignment.subject_id = new.subject_id
      and assignment.is_active = true
  ) then raise exception 'SUBJECT_NOT_ASSIGNED_TO_CLASS'; end if;

  if new.teacher_id is null then raise exception 'ASSESSMENT_TEACHER_REQUIRED'; end if;
  select * into v_teacher from public.employees where id = new.teacher_id;
  if not found then raise exception 'INVALID_TEACHER'; end if;
  if v_teacher.school_id <> new.school_id or v_teacher.status <> 'active' then raise exception 'TEACHER_INVALID_OR_INACTIVE'; end if;
  if not exists(select 1 from public.teacher_profiles tp where tp.employee_id = v_teacher.id) then raise exception 'TEACHER_PROFILE_REQUIRED'; end if;
  if not exists (
    select 1 from public.teacher_assignments ta
    where ta.school_id = new.school_id and ta.school_year_id = new.school_year_id
      and ta.teacher_id = new.teacher_id and ta.class_id = new.class_id and ta.subject_id = new.subject_id
  ) then raise exception 'TEACHER_NOT_ASSIGNED_TO_CLASS_SUBJECT'; end if;

  if new.assessment_type_id is not null then
    select * into v_type from public.assessment_types where id = new.assessment_type_id;
    if not found then raise exception 'INVALID_ASSESSMENT_TYPE'; end if;
    if v_type.school_id <> new.school_id or not v_type.is_active then raise exception 'ASSESSMENT_TYPE_INACTIVE'; end if;
  end if;
  if new.max_score <= 0 then raise exception 'MAX_SCORE_INVALID'; end if;
  return new;
end;
$$;

create or replace function app.validate_grade_021()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ass public.assessments%rowtype;
  v_period public.academic_periods%rowtype;
  v_student_school uuid;
  v_student_enrolled boolean;
begin
  select * into v_ass from public.assessments where id = new.assessment_id;
  if not found then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  if v_ass.is_published and (tg_op = 'INSERT' or new.score is distinct from old.score or new.observation is distinct from old.observation) then
    raise exception 'PUBLISHED_GRADE_LOCKED';
  end if;
  select is_closed into v_period.is_closed from public.academic_periods where id = v_ass.period_id;
  if v_period.is_closed then raise exception 'PERIOD_CLOSED'; end if;

  select school_id into v_student_school from public.students where id = new.student_id;
  if v_student_school is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  if v_student_school <> v_ass.school_id then raise exception 'GRADE_CROSS_SCHOOL'; end if;

  select exists(
    select 1 from public.enrollments e
    where e.student_id = new.student_id
      and e.school_year_id = v_ass.school_year_id
      and e.class_id = v_ass.class_id
      and e.status = 'enrolled'
  ) into v_student_enrolled;
  if not v_student_enrolled then raise exception 'STUDENT_NOT_ENROLLED_IN_ASSESSMENT_CLASS'; end if;
  if new.score < 0 or new.score > v_ass.max_score then raise exception 'GRADE_OUT_OF_RANGE'; end if;
  new.coefficient := 1;
  new.normalized_score := round((new.score / v_ass.max_score) * 20, 2);
  return new;
end;
$$;

create or replace function public.save_assessment_grades(p_assessment_id uuid, p_grades jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ass public.assessments%rowtype;
  v_period_closed boolean;
  v_school_id uuid;
  v_count integer := 0;
  v_student_id uuid;
  v_score numeric;
  v_observation text;
  v_item jsonb;
  v_duplicate uuid;
begin
  if jsonb_typeof(p_grades) <> 'array' or jsonb_array_length(p_grades) = 0 then raise exception 'GRADES_PAYLOAD_EMPTY'; end if;
  select * into v_ass from public.assessments where id = p_assessment_id for update;
  if not found then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  v_school_id := v_ass.school_id;
  if not app.is_super_admin() and not app.has_permission('grades.publish', v_school_id) and not app.is_teacher_for_assessment(p_assessment_id) then
    if not app.has_permission('grades.enter', v_school_id) then raise exception 'PERMISSION_REQUIRED: grades.enter'; end if;
    raise exception 'TEACHER_ASSESSMENT_SCOPE_REQUIRED';
  end if;
  if v_ass.is_published then raise exception 'PUBLISHED_ASSESSMENT_LOCKED'; end if;
  select is_closed into v_period_closed from public.academic_periods where id = v_ass.period_id;
  if v_period_closed then raise exception 'PERIOD_CLOSED'; end if;

  select x.student_id into v_duplicate
  from (
    select (e->>'student_id')::uuid as student_id
    from jsonb_array_elements(p_grades) e
    group by (e->>'student_id')::uuid
    having count(*) > 1
  ) x limit 1;
  if v_duplicate is not null then raise exception 'DUPLICATE_STUDENT_IN_PAYLOAD:%', v_duplicate; end if;

  for v_item in select * from jsonb_array_elements(p_grades) loop
    v_student_id := (v_item->>'student_id')::uuid;
    v_score := nullif(v_item->>'score', '')::numeric;
    v_observation := nullif(trim(v_item->>'observation'), '');
    if v_score is null then raise exception 'GRADE_SCORE_REQUIRED:%', v_student_id; end if;
    if not exists (
      select 1 from public.enrollments e
      where e.student_id = v_student_id and e.school_year_id = v_ass.school_year_id
        and e.class_id = v_ass.class_id and e.status = 'enrolled'
    ) then raise exception 'STUDENT_NOT_ENROLLED_IN_ASSESSMENT_CLASS:%', v_student_id; end if;

    insert into public.grades(assessment_id, student_id, score, coefficient, observation, entered_by)
    values(p_assessment_id, v_student_id, v_score, 1, v_observation, (select auth.uid()))
    on conflict(assessment_id, student_id) do update
      set score = excluded.score, coefficient = 1,
          observation = excluded.observation, entered_by = (select auth.uid());
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function app.subject_average(p_student_id uuid, p_subject_id uuid, p_period_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public, app
as $$
  select round(avg(g.normalized_score), 2)
  from public.grades g
  join public.assessments a on a.id = g.assessment_id
  where g.student_id = p_student_id and a.subject_id = p_subject_id
    and a.period_id = p_period_id and a.is_published = true
$$;

create or replace function public.generate_report_card_draft(p_student_id uuid, p_school_year_id uuid, p_period_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_school uuid;
  v_student_school uuid;
  v_period public.academic_periods%rowtype;
  v_enrollment public.enrollments%rowtype;
  v_class public.classes%rowtype;
  v_report_id uuid;
  v_average numeric;
  v_coefficient numeric;
  v_total numeric := 0;
  v_weight numeric := 0;
  v_item record;
begin
  select school_id into v_user_school from public.users where id = (select auth.uid());
  select school_id into v_student_school from public.students where id = p_student_id;
  if v_user_school is null or v_student_school is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if v_user_school <> v_student_school then raise exception 'CROSS_SCHOOL_STUDENT'; end if;
  if not app.is_super_admin() and not app.has_permission('report_cards.generate', v_user_school) then raise exception 'PERMISSION_REQUIRED: report_cards.generate'; end if;

  select * into v_period from public.academic_periods where id = p_period_id;
  if not found or v_period.school_year_id <> p_school_year_id then raise exception 'PERIOD_YEAR_MISMATCH'; end if;
  if v_period.is_closed = false and not app.has_permission('report_cards.generate', v_user_school) then raise exception 'REPORT_CARD_GENERATION_NOT_AUTHORIZED'; end if;

  select * into v_enrollment from public.enrollments e
  where e.student_id = p_student_id and e.school_year_id = p_school_year_id and e.status = 'enrolled'
  order by e.updated_at desc limit 1;
  if not found then raise exception 'STUDENT_NOT_ENROLLED'; end if;
  select * into v_class from public.classes where id = v_enrollment.class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;

  if not exists (
    select 1 from public.grades g join public.assessments a on a.id = g.assessment_id
    where g.student_id = p_student_id and a.school_year_id = p_school_year_id
      and a.period_id = p_period_id and a.class_id = v_enrollment.class_id and a.is_published = true
  ) then raise exception 'NO_PUBLISHED_GRADES'; end if;

  select id into v_report_id from public.report_cards where student_id = p_student_id and period_id = p_period_id for update;
  if v_report_id is null then
    insert into public.report_cards(student_id, school_id, school_year_id, period_id, class_id, status, generated_at)
    values(p_student_id, v_user_school, p_school_year_id, p_period_id, v_enrollment.class_id, 'draft', now())
    returning id into v_report_id;
  else
    if exists(select 1 from public.report_cards rc where rc.id = v_report_id and rc.status = 'published') then raise exception 'PUBLISHED_REPORT_CARD_EXISTS'; end if;
    update public.report_cards set class_id = v_enrollment.class_id, school_year_id = p_school_year_id,
      status = 'draft', generated_at = now(), published_at = null, updated_at = now()
    where id = v_report_id;
    delete from public.report_card_items where report_card_id = v_report_id;
  end if;

  for v_item in
    select assignment.subject_id,
      coalesce(assignment.coefficient_override, subject.coefficient) as effective_coefficient,
      subject.name as subject_name
    from public.subject_class_assignments assignment
    join public.subjects subject on subject.id = assignment.subject_id
    where assignment.school_id = v_user_school and assignment.school_year_id = p_school_year_id
      and assignment.class_id = v_enrollment.class_id and assignment.is_active = true and subject.is_active = true
    order by subject.name
  loop
    select round(avg(g.normalized_score), 2) into v_average
    from public.grades g join public.assessments a on a.id = g.assessment_id
    where g.student_id = p_student_id and a.school_year_id = p_school_year_id
      and a.period_id = p_period_id and a.class_id = v_enrollment.class_id
      and a.subject_id = v_item.subject_id and a.is_published = true;
    if v_average is not null then
      v_coefficient := v_item.effective_coefficient;
      insert into public.report_card_items(report_card_id, subject_id, average, coefficient)
      values(v_report_id, v_item.subject_id, v_average, v_coefficient);
      v_total := v_total + (v_average * v_coefficient);
      v_weight := v_weight + v_coefficient;
    end if;
  end loop;
  if v_weight <= 0 then raise exception 'NO_REPORT_CARD_ITEMS'; end if;
  update public.report_cards set general_average = round(v_total / v_weight, 2), rank = null,
    decision = null, status = 'draft', generated_at = coalesce(generated_at, now()),
    published_at = null, updated_at = now()
  where id = v_report_id;
  return v_report_id;
end;
$$;

alter table public.assessment_types drop column default_coefficient;
alter table public.assessments drop column coefficient;

revoke all on function public.create_assessment_type(text, text) from public, anon;
revoke all on function public.create_assessment(uuid, uuid, uuid, uuid, uuid, uuid, text, date, numeric) from public, anon;
grant execute on function public.create_assessment_type(text, text) to authenticated;
grant execute on function public.create_assessment(uuid, uuid, uuid, uuid, uuid, uuid, text, date, numeric) to authenticated;
grant execute on function app.is_teacher_for_assessment(uuid) to authenticated;
grant execute on function app.can_manage_assessment_for_class_subject(uuid, uuid, uuid, uuid) to authenticated;

comment on column public.grades.coefficient is 'Legacy value; weighting is stored on subject_class_assignments and is not applied to individual grades.';
comment on column public.assessments.max_score is 'Maximum score for the assessment; weighting is defined by the subject-class assignment.';

notify pgrst, 'reload schema';
commit;