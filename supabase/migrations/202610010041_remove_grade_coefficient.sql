begin;

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

    insert into public.grades(assessment_id, student_id, score, observation, entered_by)
    values(p_assessment_id, v_student_id, v_score, v_observation, (select auth.uid()))
    on conflict(assessment_id, student_id) do update
      set score = excluded.score, observation = excluded.observation,
          entered_by = (select auth.uid());
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

alter table public.grades drop column coefficient;
commit;