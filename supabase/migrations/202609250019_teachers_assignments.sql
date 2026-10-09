-- SIGIA-AMINE
-- Migration 019: teachers and teaching assignments
-- Étape 11 — Enseignants / Affectations
--
-- Objectifs :
-- 1. Distinguer personnel général et enseignants.
-- 2. Sécuriser teacher_profiles et teacher_assignments.
-- 3. Empêcher les affectations inter-écoles.
-- 4. Exiger qu'un enseignant ait un profil enseignant actif.
-- 5. Vérifier que matière + niveau + année correspondent.
-- 6. Garantir une seule affectation principale par classe/matière/année.
-- 7. Donner aux enseignants une lecture de leur propre périmètre.
-- 8. Garder la gestion du personnel général sous HR.
--
begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- A. QUALITÉ DES EMPLOYÉS / ENSEIGNANTS
-- =========================================================
alter table public.employees
  drop constraint if exists employees_number_not_blank,
  drop constraint if exists employees_name_not_blank,
  drop constraint if exists employees_status_not_blank;

alter table public.employees
  add constraint employees_number_not_blank check (length(trim(employee_number)) > 0),
  add constraint employees_name_not_blank check (length(trim(first_name)) > 0 and length(trim(last_name)) > 0),
  add constraint employees_status_not_blank check (length(trim(status)) > 0);

create unique index if not exists uq_employees_school_number_ci
  on public.employees(school_id, lower(trim(employee_number)));

create index if not exists idx_employees_school_status_name
  on public.employees(school_id, status, last_name, first_name);

create index if not exists idx_teacher_profiles_speciality
  on public.teacher_profiles(speciality);

-- =========================================================
-- B. TEACHER ASSIGNMENTS
-- =========================================================
alter table public.teacher_assignments
  drop constraint if exists teacher_assignments_weekly_hours_positive;

alter table public.teacher_assignments
  add constraint teacher_assignments_weekly_hours_positive
  check (weekly_hours is null or weekly_hours > 0);

create unique index if not exists uq_teacher_primary_assignment
  on public.teacher_assignments(school_year_id, class_id, subject_id)
  where is_primary = true;

create index if not exists idx_teacher_assignments_school_year_teacher_active
  on public.teacher_assignments(school_id, school_year_id, teacher_id);

create index if not exists idx_teacher_assignments_school_year_class_active
  on public.teacher_assignments(school_id, school_year_id, class_id);

create index if not exists idx_teacher_assignments_school_year_subject_active
  on public.teacher_assignments(school_id, school_year_id, subject_id);

-- =========================================================
-- C. INTÉGRITÉ MÉTIER DES AFFECTATIONS
-- =========================================================
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
  v_class_level uuid;
  v_teacher_status text;
  v_has_profile boolean;
  v_subject_config boolean;
begin
  select school_id, status
    into v_teacher_school, v_teacher_status
  from public.employees
  where id = new.teacher_id;

  if v_teacher_school is null then
    raise exception 'INVALID_TEACHER';
  end if;

  if v_teacher_school <> new.school_id then
    raise exception 'CROSS_SCHOOL: teacher_assignments.teacher_id';
  end if;

  if lower(trim(coalesce(v_teacher_status, ''))) <> 'active' then
    raise exception 'TEACHER_NOT_ACTIVE';
  end if;

  select exists(
    select 1
    from public.teacher_profiles tp
    where tp.employee_id = new.teacher_id
  )
  into v_has_profile;

  if not v_has_profile then
    raise exception 'TEACHER_PROFILE_REQUIRED';
  end if;

  select school_id, school_year_id, level_id
    into v_class_school, v_class_year, v_class_level
  from public.classes
  where id = new.class_id;

  if v_class_school is null then
    raise exception 'INVALID_CLASS';
  end if;

  if v_class_school <> new.school_id then
    raise exception 'CROSS_SCHOOL: teacher_assignments.class_id';
  end if;

  if v_class_year <> new.school_year_id then
    raise exception 'CLASS_YEAR_MISMATCH';
  end if;

  select school_id into v_subject_school
  from public.subjects
  where id = new.subject_id;

  if v_subject_school is null then
    raise exception 'INVALID_SUBJECT';
  end if;

  if v_subject_school <> new.school_id then
    raise exception 'CROSS_SCHOOL: teacher_assignments.subject_id';
  end if;

  select school_id into v_school
  from public.school_years
  where id = new.school_year_id;

  if v_school is null or v_school <> new.school_id then
    raise exception 'INVALID_SCHOOL_YEAR';
  end if;

  select exists(
    select 1
    from public.subject_level_assignments sla
    where sla.school_year_id = new.school_year_id
      and sla.level_id = v_class_level
      and sla.subject_id = new.subject_id
      and sla.school_id = new.school_id
      and sla.is_active = true
  )
  into v_subject_config;

  if not v_subject_config then
    raise exception 'SUBJECT_NOT_ASSIGNED_TO_CLASS_LEVEL';
  end if;

  if new.weekly_hours is not null and new.weekly_hours <= 0 then
    raise exception 'WEEKLY_HOURS_INVALID';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_teacher_assignment_integrity on public.teacher_assignments;
create trigger trg_validate_teacher_assignment_integrity
before insert or update on public.teacher_assignments
for each row
execute function app.validate_teacher_assignment_integrity();


-- =========================================================
-- C.1. HELPERS SECURITY DEFINER
-- Évite les récursions RLS entre employees et teacher_profiles.
-- =========================================================
create or replace function app.employee_is_teacher(p_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, app
as $$
  select exists(
    select 1
    from public.teacher_profiles tp
    where tp.employee_id = p_employee_id
  )
$$;

create or replace function app.employee_belongs_to_user(p_employee_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, app
as $$
  select exists(
    select 1
    from public.employees e
    where e.id = p_employee_id
      and e.user_id = p_user_id
  )
$$;

create or replace function app.teacher_assignment_belongs_to_user(p_teacher_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, app
as $$
  select exists(
    select 1
    from public.employees e
    where e.id = p_teacher_id
      and e.user_id = p_user_id
  )
$$;

-- =========================================================
-- D. INTÉGRITÉ DU PROFIL ENSEIGNANT / EMPLOYÉ
-- =========================================================
create or replace function app.validate_teacher_profile_employee()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_status text;
begin
  select status into v_status
  from public.employees
  where id = new.employee_id;

  if v_status is null then
    raise exception 'EMPLOYEE_NOT_FOUND';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_teacher_profile_employee on public.teacher_profiles;
create trigger trg_validate_teacher_profile_employee
before insert or update on public.teacher_profiles
for each row
execute function app.validate_teacher_profile_employee();

-- =========================================================
-- E. PERMISSIONS
-- =========================================================
insert into public.permissions(code, name, module, action, description)
values
  ('teachers.view', 'Consulter enseignants', 'academic', 'view', 'Consulter les enseignants et leurs affectations autorisées'),
  ('teachers.manage', 'Gérer enseignants', 'academic', 'manage', 'Créer, modifier, archiver les enseignants et gérer leurs affectations')
on conflict(code) do update
set
  name = excluded.name,
  module = excluded.module,
  action = excluded.action,
  description = excluded.description;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('teachers.view','teachers.manage')
where r.code in ('super_admin','founder','direction','admin','academic_director')
on conflict do nothing;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code = 'teachers.view'
where r.code in ('teacher','supervisor','hr_manager')
on conflict do nothing;

-- =========================================================
-- F. RLS EMPLOYEES
-- =========================================================
drop policy if exists employees_select_secure on public.employees;
drop policy if exists employees_insert_secure on public.employees;
drop policy if exists employees_update_secure on public.employees;
drop policy if exists employees_delete_secure on public.employees;

create policy employees_select_019
on public.employees
for select
to authenticated
using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      user_id = auth.uid()
      or app.has_permission('hr.manage', school_id)
      or app.has_role_code('direction', school_id)
      or app.has_role_code('founder', school_id)
      or (
        app.employee_is_teacher(employees.id)
        and (
          app.has_permission('teachers.view', school_id)
          or app.has_permission('teachers.manage', school_id)
        )
      )
    )
  )
);

create policy employees_insert_019
on public.employees
for insert
to authenticated
with check (
  app.is_super_admin()
  or app.has_permission('hr.manage', school_id)
);

create policy employees_update_019
on public.employees
for update
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('hr.manage', school_id)
  or (
    app.employee_is_teacher(employees.id)
    and app.has_permission('teachers.manage', school_id)
  )
  or user_id = auth.uid()
)
with check (
  app.is_super_admin()
  or app.has_permission('hr.manage', school_id)
  or (
    app.employee_is_teacher(employees.id)
    and app.has_permission('teachers.manage', school_id)
  )
  or user_id = auth.uid()
);

create policy employees_delete_019
on public.employees
for delete
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('hr.manage', school_id)
);

-- =========================================================
-- G. RLS TEACHER PROFILES
-- =========================================================
drop policy if exists teacher_profiles_secure on public.teacher_profiles;
drop policy if exists teacher_profiles_select_019 on public.teacher_profiles;
drop policy if exists teacher_profiles_insert_019 on public.teacher_profiles;
drop policy if exists teacher_profiles_update_019 on public.teacher_profiles;
drop policy if exists teacher_profiles_delete_019 on public.teacher_profiles;

create policy teacher_profiles_select_019
on public.teacher_profiles
for select
to authenticated
using (
  app.is_super_admin()
  or exists(
    select 1
    from public.employees e
    where e.id = teacher_profiles.employee_id
      and e.school_id in (select app.my_school_ids())
      and (
        e.user_id = auth.uid()
        or app.has_permission('hr.manage', e.school_id)
        or app.has_permission('teachers.view', e.school_id)
        or app.has_permission('teachers.manage', e.school_id)
        or app.has_role_code('direction', e.school_id)
        or app.has_role_code('founder', e.school_id)
      )
  )
);

create policy teacher_profiles_insert_019
on public.teacher_profiles
for insert
to authenticated
with check (
  app.is_super_admin()
  or exists(
    select 1 from public.employees e
    where e.id = teacher_profiles.employee_id
      and (
        app.has_permission('hr.manage', e.school_id)
        or app.has_permission('teachers.manage', e.school_id)
      )
  )
);

create policy teacher_profiles_update_019
on public.teacher_profiles
for update
to authenticated
using (
  app.is_super_admin()
  or exists(
    select 1 from public.employees e
    where e.id = teacher_profiles.employee_id
      and (
        app.has_permission('hr.manage', e.school_id)
        or app.has_permission('teachers.manage', e.school_id)
        or e.user_id = auth.uid()
      )
  )
)
with check (
  app.is_super_admin()
  or exists(
    select 1 from public.employees e
    where e.id = teacher_profiles.employee_id
      and (
        app.has_permission('hr.manage', e.school_id)
        or app.has_permission('teachers.manage', e.school_id)
        or e.user_id = auth.uid()
      )
  )
);

create policy teacher_profiles_delete_019
on public.teacher_profiles
for delete
to authenticated
using (
  app.is_super_admin()
  or exists(
    select 1 from public.employees e
    where e.id = teacher_profiles.employee_id
      and (
        app.has_permission('hr.manage', e.school_id)
        or app.has_permission('teachers.manage', e.school_id)
      )
  )
);

-- =========================================================
-- H. RLS TEACHER ASSIGNMENTS
-- =========================================================
drop policy if exists teacher_assignments_select_secure on public.teacher_assignments;
drop policy if exists teacher_assignments_insert_secure on public.teacher_assignments;
drop policy if exists teacher_assignments_update_secure on public.teacher_assignments;
drop policy if exists teacher_assignments_delete_secure on public.teacher_assignments;

create policy teacher_assignments_select_019
on public.teacher_assignments
for select
to authenticated
using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      app.teacher_assignment_belongs_to_user(teacher_assignments.teacher_id)
      or app.has_permission('teachers.view', school_id)
      or app.has_permission('teachers.manage', school_id)
      or app.has_permission('assessments.manage', school_id)
      or app.has_role_code('direction', school_id)
      or app.has_role_code('founder', school_id)
    )
  )
);

create policy teacher_assignments_insert_019
on public.teacher_assignments
for insert
to authenticated
with check (
  app.is_super_admin()
  or app.has_permission('teachers.manage', school_id)
);

create policy teacher_assignments_update_019
on public.teacher_assignments
for update
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('teachers.manage', school_id)
)
with check (
  app.is_super_admin()
  or app.has_permission('teachers.manage', school_id)
);

create policy teacher_assignments_delete_019
on public.teacher_assignments
for delete
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('teachers.manage', school_id)
);

-- =========================================================
-- I. RPC — CRÉATION D'ENSEIGNANT
-- =========================================================
create or replace function public.create_teacher(
  p_employee_number text,
  p_first_name text,
  p_last_name text,
  p_gender app.gender_type default null,
  p_date_of_birth date default null,
  p_place_of_birth text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null,
  p_qualification text default null,
  p_hire_date date default null,
  p_speciality text default null,
  p_diploma text default null,
  p_pedagogical_role text default null,
  p_biography text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_user public.users%rowtype;
  v_teacher_id uuid;
begin
  select * into v_user
  from public.users
  where id = auth.uid() and status = 'active';

  if v_user.id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not app.is_super_admin()
     and not app.has_permission('teachers.manage', v_user.school_id)
     and not app.has_permission('hr.manage', v_user.school_id) then
    raise exception 'FORBIDDEN_TEACHER_MANAGE';
  end if;

  if length(trim(coalesce(p_employee_number,''))) = 0 then
    raise exception 'EMPLOYEE_NUMBER_REQUIRED';
  end if;

  if length(trim(coalesce(p_first_name,''))) = 0 then
    raise exception 'FIRST_NAME_REQUIRED';
  end if;

  if length(trim(coalesce(p_last_name,''))) = 0 then
    raise exception 'LAST_NAME_REQUIRED';
  end if;

  insert into public.employees(
    school_id, employee_number, first_name, last_name, gender,
    date_of_birth, place_of_birth, phone, email, address,
    job_title, department, qualification, hire_date, status
  )
  values (
    v_user.school_id, trim(p_employee_number), trim(p_first_name), trim(p_last_name), p_gender,
    p_date_of_birth, nullif(trim(p_place_of_birth), ''), nullif(trim(p_phone), ''),
    nullif(trim(p_email), ''), nullif(trim(p_address), ''),
    'Enseignant', 'Pédagogie', nullif(trim(p_qualification), ''), p_hire_date, 'active'
  )
  returning id into v_teacher_id;

  insert into public.teacher_profiles(
    employee_id, speciality, diploma, pedagogical_role, biography
  )
  values(
    v_teacher_id,
    nullif(trim(p_speciality), ''),
    nullif(trim(p_diploma), ''),
    nullif(trim(p_pedagogical_role), ''),
    nullif(trim(p_biography), '')
  );

  return v_teacher_id;
end;
$$;

-- =========================================================
-- J. RPC — MODIFICATION ENSEIGNANT
-- =========================================================
create or replace function public.update_teacher(
  p_teacher_id uuid,
  p_employee_number text,
  p_first_name text,
  p_last_name text,
  p_gender app.gender_type default null,
  p_date_of_birth date default null,
  p_place_of_birth text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null,
  p_qualification text default null,
  p_hire_date date default null,
  p_speciality text default null,
  p_diploma text default null,
  p_pedagogical_role text default null,
  p_biography text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
begin
  select school_id into v_school_id
  from public.employees
  where id = p_teacher_id
    and app.employee_is_teacher(employees.id);

  if v_school_id is null then
    raise exception 'TEACHER_NOT_FOUND';
  end if;

  if not app.is_super_admin()
     and not app.has_permission('teachers.manage', v_school_id)
     and not app.has_permission('hr.manage', v_school_id) then
    raise exception 'FORBIDDEN_TEACHER_MANAGE';
  end if;

  if length(trim(coalesce(p_employee_number,''))) = 0 then
    raise exception 'EMPLOYEE_NUMBER_REQUIRED';
  end if;

  if length(trim(coalesce(p_first_name,''))) = 0 then
    raise exception 'FIRST_NAME_REQUIRED';
  end if;

  if length(trim(coalesce(p_last_name,''))) = 0 then
    raise exception 'LAST_NAME_REQUIRED';
  end if;

  update public.employees
  set employee_number = trim(p_employee_number),
      first_name = trim(p_first_name),
      last_name = trim(p_last_name),
      gender = p_gender,
      date_of_birth = p_date_of_birth,
      place_of_birth = nullif(trim(p_place_of_birth), ''),
      phone = nullif(trim(p_phone), ''),
      email = nullif(trim(p_email), ''),
      address = nullif(trim(p_address), ''),
      qualification = nullif(trim(p_qualification), ''),
      hire_date = p_hire_date
  where id = p_teacher_id;

  update public.teacher_profiles
  set speciality = nullif(trim(p_speciality), ''),
      diploma = nullif(trim(p_diploma), ''),
      pedagogical_role = nullif(trim(p_pedagogical_role), ''),
      biography = nullif(trim(p_biography), '')
  where employee_id = p_teacher_id;

  return p_teacher_id;
end;
$$;

-- =========================================================
-- K. RPC — ACTIVATION / ARCHIVAGE ENSEIGNANT
-- =========================================================
create or replace function public.set_teacher_active(
  p_teacher_id uuid,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_active_assignments bigint;
begin
  select school_id into v_school_id
  from public.employees
  where id = p_teacher_id
    and app.employee_is_teacher(employees.id);

  if v_school_id is null then
    raise exception 'TEACHER_NOT_FOUND';
  end if;

  if not app.is_super_admin()
     and not app.has_permission('teachers.manage', v_school_id)
     and not app.has_permission('hr.manage', v_school_id) then
    raise exception 'FORBIDDEN_TEACHER_MANAGE';
  end if;

  if not p_is_active then
    select count(*) into v_active_assignments
    from public.teacher_assignments
    where teacher_id = p_teacher_id;

    if v_active_assignments > 0 then
      raise exception 'TEACHER_HAS_ASSIGNMENTS';
    end if;
  end if;

  update public.employees
  set status = case when p_is_active then 'active' else 'inactive' end
  where id = p_teacher_id;

  return p_teacher_id;
end;
$$;

-- =========================================================
-- L. RPC — AFFECTATION ENSEIGNANT
-- =========================================================
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
  v_class_level uuid;
  v_teacher_school uuid;
  v_subject_school uuid;
  v_assignment uuid;
begin
  select * into v_user
  from public.users
  where id = auth.uid() and status = 'active';

  if v_user.id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not app.is_super_admin() and not app.has_permission('teachers.manage', v_user.school_id) then
    raise exception 'FORBIDDEN_TEACHER_MANAGE';
  end if;

  select school_id into v_school_id
  from public.school_years
  where id = p_school_year_id;

  if v_school_id is null or v_school_id <> v_user.school_id then
    raise exception 'INVALID_SCHOOL_YEAR';
  end if;

  select school_id, school_year_id, level_id into v_class_school, v_class_year, v_class_level
  from public.classes
  where id = p_class_id and is_active = true;

  if v_class_school is null then raise exception 'INVALID_CLASS'; end if;
  if v_class_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: class'; end if;
  if v_class_year <> p_school_year_id then raise exception 'CLASS_YEAR_MISMATCH'; end if;

  select school_id into v_teacher_school
  from public.employees
  where id = p_teacher_id
    and status = 'active';

  if v_teacher_school is null then raise exception 'INVALID_TEACHER'; end if;
  if v_teacher_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: teacher'; end if;

  if not exists(select 1 from public.teacher_profiles where employee_id = p_teacher_id) then
    raise exception 'TEACHER_PROFILE_REQUIRED';
  end if;

  select school_id into v_subject_school
  from public.subjects
  where id = p_subject_id and is_active = true;

  if v_subject_school is null then raise exception 'INVALID_SUBJECT'; end if;
  if v_subject_school <> v_user.school_id then raise exception 'CROSS_SCHOOL: subject'; end if;

  if not exists(
    select 1
    from public.subject_level_assignments sla
    where sla.school_id = v_user.school_id
      and sla.school_year_id = p_school_year_id
      and sla.level_id = v_class_level
      and sla.subject_id = p_subject_id
      and sla.is_active = true
  ) then
    raise exception 'SUBJECT_NOT_ASSIGNED_TO_CLASS_LEVEL';
  end if;

  if p_weekly_hours is not null and p_weekly_hours <= 0 then
    raise exception 'WEEKLY_HOURS_INVALID';
  end if;

  insert into public.teacher_assignments(
    school_id, school_year_id, teacher_id, class_id, subject_id,
    weekly_hours, is_primary
  )
  values(
    v_user.school_id, p_school_year_id, p_teacher_id, p_class_id, p_subject_id,
    p_weekly_hours, p_is_primary
  )
  on conflict (school_year_id, teacher_id, class_id, subject_id)
  do update set
    weekly_hours = excluded.weekly_hours,
    is_primary = excluded.is_primary
  returning id into v_assignment;

  return v_assignment;
end;
$$;

create or replace function public.set_teacher_assignment_active(
  p_assignment_id uuid,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
begin
  select school_id into v_school_id
  from public.teacher_assignments
  where id = p_assignment_id;

  if v_school_id is null then
    raise exception 'TEACHER_ASSIGNMENT_NOT_FOUND';
  end if;

  if not app.is_super_admin() and not app.has_permission('teachers.manage', v_school_id) then
    raise exception 'FORBIDDEN_TEACHER_MANAGE';
  end if;

  if p_is_active then
    update public.teacher_assignments
    set is_primary = is_primary
    where id = p_assignment_id;
  else
    -- Une désactivation doit être réalisée en retirant l'affectation.
    delete from public.teacher_assignments where id = p_assignment_id;
  end if;

  return p_assignment_id;
end;
$$;


revoke all on function app.employee_is_teacher(uuid) from public;
revoke all on function app.employee_belongs_to_user(uuid,uuid) from public;
revoke all on function app.teacher_assignment_belongs_to_user(uuid,uuid) from public;
grant execute on function app.employee_is_teacher(uuid) to authenticated;
grant execute on function app.employee_belongs_to_user(uuid,uuid) to authenticated;
grant execute on function app.teacher_assignment_belongs_to_user(uuid,uuid) to authenticated;

revoke all on function public.create_teacher(text,text,text,app.gender_type,date,text,text,text,text,text,date,text,text,text,text) from public;
revoke all on function public.update_teacher(uuid,text,text,text,app.gender_type,date,text,text,text,text,text,date,text,text,text,text) from public;
revoke all on function public.set_teacher_active(uuid,boolean) from public;
revoke all on function public.assign_teacher(uuid,uuid,uuid,uuid,numeric,boolean) from public;
revoke all on function public.set_teacher_assignment_active(uuid,boolean) from public;

grant execute on function public.create_teacher(text,text,text,app.gender_type,date,text,text,text,text,text,date,text,text,text,text) to authenticated;
grant execute on function public.update_teacher(uuid,text,text,text,app.gender_type,date,text,text,text,text,text,date,text,text,text,text) to authenticated;
grant execute on function public.set_teacher_active(uuid,boolean) to authenticated;
grant execute on function public.assign_teacher(uuid,uuid,uuid,uuid,numeric,boolean) to authenticated;
grant execute on function public.set_teacher_assignment_active(uuid,boolean) to authenticated;

comment on table public.teacher_profiles is 'Profil pédagogique complémentaire d''un employé enseignant.';
comment on table public.teacher_assignments is 'Affectation d''un enseignant à une classe et une matière pour une année donnée.';
comment on column public.teacher_assignments.is_primary is 'Une seule affectation principale par classe/matière/année.';
comment on column public.teacher_assignments.weekly_hours is 'Volume hebdomadaire de cette affectation.';

commit;
