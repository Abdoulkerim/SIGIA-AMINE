begin;

create table public.subject_class_assignments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  coefficient_override numeric(8,2),
  weekly_hours_override numeric(6,2),
  is_required boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_year_id, class_id, subject_id),
  check(coefficient_override is null or coefficient_override > 0),
  check(weekly_hours_override is null or weekly_hours_override > 0)
);

create index idx_subject_class_assignments_school_year_class
  on public.subject_class_assignments(school_id, school_year_id, class_id, is_active);
create index idx_subject_class_assignments_subject
  on public.subject_class_assignments(school_id, subject_id, is_active);

insert into public.subject_class_assignments(
  school_id, school_year_id, class_id, subject_id,
  coefficient_override, weekly_hours_override, is_required, is_active
)
select
  assignment.school_id, assignment.school_year_id, class.id, assignment.subject_id,
  assignment.coefficient_override, assignment.weekly_hours_override,
  assignment.is_required, assignment.is_active
from public.subject_level_assignments assignment
join public.classes class
  on class.school_id = assignment.school_id
  and class.school_year_id = assignment.school_year_id
  and class.level_id = assignment.level_id
on conflict (school_year_id, class_id, subject_id) do update set
  coefficient_override = excluded.coefficient_override,
  weekly_hours_override = excluded.weekly_hours_override,
  is_required = excluded.is_required,
  is_active = excluded.is_active,
  updated_at = now();

update public.subject_level_assignments set is_active = false;
alter table public.subject_level_assignments rename to subject_level_assignments_legacy;
revoke all on public.subject_level_assignments_legacy from anon, authenticated;

create trigger trg_subject_class_assignments_updated_at
before update on public.subject_class_assignments
for each row execute function app.set_updated_at();

create or replace function app.validate_subject_class_assignment_integrity()
returns trigger
language plpgsql
set search_path = public, app
as $$
declare
  v_school uuid;
  v_class_year uuid;
begin
  select school_id, school_year_id into v_school, v_class_year
  from public.classes
  where id = new.class_id and is_active = true;
  if v_school is null then raise exception 'INVALID_CLASS'; end if;
  if v_school <> new.school_id then raise exception 'CROSS_SCHOOL: subject_class_assignments.class_id'; end if;
  if v_class_year <> new.school_year_id then raise exception 'CLASS_YEAR_MISMATCH'; end if;

  select school_id into v_school from public.school_years where id = new.school_year_id;
  if v_school is null or v_school <> new.school_id then raise exception 'INVALID_SCHOOL_YEAR'; end if;

  select school_id into v_school from public.subjects where id = new.subject_id;
  if v_school is null then raise exception 'INVALID_SUBJECT'; end if;
  if v_school <> new.school_id then raise exception 'CROSS_SCHOOL: subject_class_assignments.subject_id'; end if;

  return new;
end;
$$;

create trigger trg_validate_subject_class_assignment_integrity
before insert or update on public.subject_class_assignments
for each row execute function app.validate_subject_class_assignment_integrity();

alter table public.subject_class_assignments enable row level security;
create policy subject_class_assignments_select
on public.subject_class_assignments for select to authenticated
using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      app.has_permission('subjects.view', school_id)
      or app.has_permission('subjects.manage', school_id)
      or app.has_permission('classes.view', school_id)
      or app.has_permission('classes.manage', school_id)
      or app.has_permission('teachers.manage', school_id)
      or app.has_permission('assessments.manage', school_id)
    )
  )
);
create policy subject_class_assignments_insert
on public.subject_class_assignments for insert to authenticated
with check (app.is_super_admin() or app.has_permission('subjects.manage', school_id));
create policy subject_class_assignments_update
on public.subject_class_assignments for update to authenticated
using (app.is_super_admin() or app.has_permission('subjects.manage', school_id))
with check (app.is_super_admin() or app.has_permission('subjects.manage', school_id));
create policy subject_class_assignments_delete
on public.subject_class_assignments for delete to authenticated
using (app.is_super_admin() or app.has_permission('subjects.manage', school_id));
grant select, insert, update, delete on public.subject_class_assignments to authenticated, service_role;

create or replace function public.set_subject_active(p_subject_id uuid, p_is_active boolean)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_active_assignments bigint;
begin
  select school_id into v_school_id from public.subjects where id = p_subject_id;
  if v_school_id is null then raise exception 'SUBJECT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;

  if not p_is_active then
    select count(*) into v_active_assignments
    from public.subject_class_assignments
    where subject_id = p_subject_id and is_active = true;
    if v_active_assignments > 0 then raise exception 'SUBJECT_HAS_ACTIVE_CLASS_ASSIGNMENTS'; end if;
  end if;

  update public.subjects set is_active = p_is_active where id = p_subject_id;
  return p_subject_id;
end;
$$;

create or replace function public.assign_subject_to_class(
  p_school_year_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_coefficient_override numeric default null,
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

  if p_coefficient_override is not null and p_coefficient_override <= 0 then raise exception 'SUBJECT_COEFFICIENT_INVALID'; end if;
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

create or replace function public.set_subject_class_active(p_assignment_id uuid, p_is_active boolean)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
begin
  select school_id into v_school_id from public.subject_class_assignments where id = p_assignment_id;
  if v_school_id is null then raise exception 'SUBJECT_CLASS_ASSIGNMENT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;
  update public.subject_class_assignments set is_active = p_is_active where id = p_assignment_id;
  return p_assignment_id;
end;
$$;

revoke all on function public.assign_subject_to_level(uuid, uuid, uuid, numeric, numeric, boolean) from public, anon, authenticated;
revoke all on function public.set_subject_level_active(uuid, boolean) from public, anon, authenticated;
grant execute on function public.assign_subject_to_class(uuid, uuid, uuid, numeric, numeric, boolean) to authenticated;
grant execute on function public.set_subject_class_active(uuid, boolean) to authenticated;
grant execute on function public.set_subject_active(uuid, boolean) to authenticated;

create or replace function app.validate_teacher_assignment_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school uuid;
  v_teacher_school uuid;
  v_class_school uuid;
  v_subject_school uuid;
  v_class_year uuid;
  v_teacher_status text;
  v_has_profile boolean;
begin
  select school_id, status into v_teacher_school, v_teacher_status
  from public.employees where id = new.teacher_id;
  if v_teacher_school is null then raise exception 'INVALID_TEACHER'; end if;
  if v_teacher_school <> new.school_id then raise exception 'CROSS_SCHOOL: teacher_assignments.teacher_id'; end if;
  if lower(trim(coalesce(v_teacher_status, ''))) <> 'active' then raise exception 'TEACHER_NOT_ACTIVE'; end if;

  select exists(select 1 from public.teacher_profiles tp where tp.employee_id = new.teacher_id) into v_has_profile;
  if not v_has_profile then raise exception 'TEACHER_PROFILE_REQUIRED'; end if;

  select school_id, school_year_id into v_class_school, v_class_year
  from public.classes where id = new.class_id;
  if v_class_school is null then raise exception 'INVALID_CLASS'; end if;
  if v_class_school <> new.school_id then raise exception 'CROSS_SCHOOL: teacher_assignments.class_id'; end if;
  if v_class_year <> new.school_year_id then raise exception 'CLASS_YEAR_MISMATCH'; end if;

  select school_id into v_subject_school from public.subjects where id = new.subject_id;
  if v_subject_school is null then raise exception 'INVALID_SUBJECT'; end if;
  if v_subject_school <> new.school_id then raise exception 'CROSS_SCHOOL: teacher_assignments.subject_id'; end if;

  select school_id into v_school from public.school_years where id = new.school_year_id;
  if v_school is null or v_school <> new.school_id then raise exception 'INVALID_SCHOOL_YEAR'; end if;

  if not exists (
    select 1 from public.subject_class_assignments assignment
    where assignment.school_year_id = new.school_year_id
      and assignment.class_id = new.class_id
      and assignment.subject_id = new.subject_id
      and assignment.school_id = new.school_id
      and assignment.is_active = true
  ) then raise exception 'SUBJECT_NOT_ASSIGNED_TO_CLASS'; end if;

  if new.weekly_hours is not null and new.weekly_hours <= 0 then raise exception 'WEEKLY_HOURS_INVALID'; end if;
  return new;
end;
$$;

create or replace function public.assign_teacher(
  p_school_year_id uuid,
  p_teacher_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_weekly_hours numeric default null,
  p_is_primary boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_user public.users%rowtype;
  v_school_id uuid;
  v_class_school uuid;
  v_class_year uuid;
  v_teacher_school uuid;
  v_subject_school uuid;
  v_assignment uuid;
begin
  select * into v_user from public.users where id = auth.uid() and status = 'active';
  if v_user.id is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app.is_super_admin() and not app.has_permission('teachers.manage', v_user.school_id) then raise exception 'FORBIDDEN_TEACHER_MANAGE'; end if;

  select school_id into v_school_id from public.school_years where id = p_school_year_id;
  if v_school_id is null or v_school_id <> v_user.school_id then raise exception 'INVALID_SCHOOL_YEAR'; end if;

  select school_id, school_year_id into v_class_school, v_class_year
  from public.classes where id = p_class_id and is_active = true;
  if v_class_school is null then raise exception 'INVALID_CLASS'; end if;
  if v_class_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: class'; end if;
  if v_class_year <> p_school_year_id then raise exception 'CLASS_YEAR_MISMATCH'; end if;

  select school_id into v_teacher_school from public.employees where id = p_teacher_id and status = 'active';
  if v_teacher_school is null then raise exception 'INVALID_TEACHER'; end if;
  if v_teacher_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: teacher'; end if;
  if not exists(select 1 from public.teacher_profiles where employee_id = p_teacher_id) then raise exception 'TEACHER_PROFILE_REQUIRED'; end if;

  select school_id into v_subject_school from public.subjects where id = p_subject_id and is_active = true;
  if v_subject_school is null then raise exception 'INVALID_SUBJECT'; end if;
  if v_subject_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: subject'; end if;
  if not exists (
    select 1 from public.subject_class_assignments assignment
    where assignment.school_id = v_user.school_id
      and assignment.school_year_id = p_school_year_id
      and assignment.class_id = p_class_id
      and assignment.subject_id = p_subject_id
      and assignment.is_active = true
  ) then raise exception 'SUBJECT_NOT_ASSIGNED_TO_CLASS'; end if;

  if p_weekly_hours is not null and p_weekly_hours <= 0 then raise exception 'WEEKLY_HOURS_INVALID'; end if;
  insert into public.teacher_assignments(school_id, school_year_id, teacher_id, class_id, subject_id, weekly_hours, is_primary)
  values(v_user.school_id, p_school_year_id, p_teacher_id, p_class_id, p_subject_id, p_weekly_hours, p_is_primary)
  on conflict (school_year_id, teacher_id, class_id, subject_id)
  do update set weekly_hours = excluded.weekly_hours, is_primary = excluded.is_primary
  returning id into v_assignment;
  return v_assignment;
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
  if new.coefficient <= 0 then raise exception 'ASSESSMENT_COEFFICIENT_INVALID'; end if;
  return new;
end;
$$;

create or replace function public.generate_report_card_draft(
  p_student_id uuid,
  p_school_year_id uuid,
  p_period_id uuid
)
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

  select id into v_report_id from public.report_cards
  where student_id = p_student_id and period_id = p_period_id for update;

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
    where assignment.school_id = v_user_school
      and assignment.school_year_id = p_school_year_id
      and assignment.class_id = v_enrollment.class_id
      and assignment.is_active = true and subject.is_active = true
    order by subject.name
  loop
    select round(sum(g.normalized_score * g.coefficient) / nullif(sum(g.coefficient), 0), 2)
    into v_average
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

comment on table public.subject_level_assignments_legacy is 'Anciennes associations matière-niveau, conservées en lecture service pour historique. Les affectations actives sont dans subject_class_assignments.';
comment on table public.subject_class_assignments is 'Association d’une matière à une classe et une année, avec coefficients et horaires spécifiques.';

commit;