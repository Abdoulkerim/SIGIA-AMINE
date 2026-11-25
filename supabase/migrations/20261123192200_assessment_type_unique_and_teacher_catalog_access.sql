begin;

create unique index if not exists uq_assessment_one_type_per_class_subject_period
  on public.assessments(
    school_id,
    school_year_id,
    period_id,
    class_id,
    subject_id,
    assessment_type_id
  )
  where assessment_type_id is not null;

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
  if not exists (select 1 from public.teacher_profiles tp where tp.employee_id = v_teacher.id) then raise exception 'TEACHER_PROFILE_REQUIRED'; end if;
  if not exists (
    select 1 from public.teacher_assignments ta
    where ta.school_id = new.school_id
      and ta.school_year_id = new.school_year_id
      and ta.teacher_id = new.teacher_id
      and ta.class_id = new.class_id
      and ta.subject_id = new.subject_id
  ) then raise exception 'TEACHER_NOT_ASSIGNED_TO_CLASS_SUBJECT'; end if;

  if new.assessment_type_id is not null then
    select * into v_type from public.assessment_types where id = new.assessment_type_id;
    if not found then raise exception 'INVALID_ASSESSMENT_TYPE'; end if;
    if v_type.school_id <> new.school_id or not v_type.is_active then raise exception 'ASSESSMENT_TYPE_INACTIVE'; end if;
    new.title := v_type.name;

    if exists (
      select 1
      from public.assessments a
      where a.id is distinct from new.id
        and a.school_id = new.school_id
        and a.school_year_id = new.school_year_id
        and a.period_id = new.period_id
        and a.class_id = new.class_id
        and a.subject_id = new.subject_id
        and a.assessment_type_id = new.assessment_type_id
    ) then
      raise exception 'ASSESSMENT_DUPLICATE_TYPE: Une seule évaluation de ce type est autorisée pour cette matière, cette classe et cette période.';
    end if;
  end if;

  if new.max_score <= 0 then raise exception 'MAX_SCORE_INVALID'; end if;
  return new;
end;
$$;

drop trigger if exists trg_assessment_types_updated_at on public.assessment_types;
create trigger trg_assessment_types_updated_at
before update on public.assessment_types
for each row execute function app.set_updated_at();

drop trigger if exists trg_021_validate_assessment on public.assessments;
create trigger trg_021_validate_assessment
before insert or update on public.assessments
for each row execute function app.validate_assessment_021();

drop policy if exists assessment_types_select_021 on public.assessment_types;
create policy assessment_types_select_021 on public.assessment_types
for select to authenticated
using (
  app.is_super_admin()
  or app.has_permission('assessments.view', school_id)
  or app.has_permission('assessments.manage', school_id)
  or app.has_permission('grades.enter', school_id)
);

drop policy if exists assessment_types_insert_021 on public.assessment_types;
create policy assessment_types_insert_021 on public.assessment_types
for insert to authenticated
with check (
  app.is_super_admin()
  or app.has_permission('assessments.manage', school_id)
);

create or replace function public.create_assessment_type(p_code text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_id uuid;
begin
  select school_id into v_school_id
  from public.users
  where id = (select auth.uid());

  if v_school_id is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if app.has_role_code('teacher', v_school_id)
     and not app.has_role_code('direction', v_school_id)
     and not app.has_role_code('academic_director', v_school_id)
     and not app.has_role_code('founder', v_school_id)
     and not app.is_super_admin() then
    raise exception 'ASSESSMENT_TYPES_TEACHER_CREATE_FORBIDDEN';
  end if;
  if not app.is_super_admin()
     and not app.has_permission('assessments.manage', v_school_id) then
    raise exception 'PERMISSION_REQUIRED: assessments.manage';
  end if;

  insert into public.assessment_types(school_id, code, name)
  values(v_school_id, trim(p_code), trim(p_name))
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_assessment_type(text, text) from public, anon;
grant execute on function public.create_assessment_type(text, text) to authenticated;

commit;
