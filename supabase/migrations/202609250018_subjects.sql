-- SIGIA-AMINE
-- Migration 018: subjects and subject-level configuration
-- Étape 10 — Matières
--
-- Distinction importante :
--   subjects = catalogue stable des matières de l'établissement.
--   subject_level_assignments = activation d'une matière pour un niveau et une année,
--                               avec éventuels surcharges de coefficient/volume horaire.
--   programs = contenu/progression pédagogique, développé ultérieurement.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- A. QUALITÉ DU CATALOGUE DES MATIÈRES
-- =========================================================
alter table public.subjects
  drop constraint if exists subjects_code_not_blank,
  drop constraint if exists subjects_name_not_blank,
  drop constraint if exists subjects_domain_not_blank,
  drop constraint if exists subjects_weekly_hours_positive;

alter table public.subjects
  add constraint subjects_code_not_blank check (length(trim(code)) > 0),
  add constraint subjects_name_not_blank check (length(trim(name)) > 0),
  add constraint subjects_domain_not_blank check (length(trim(domain)) > 0),
  add constraint subjects_weekly_hours_positive check (weekly_hours is null or weekly_hours > 0);

create unique index if not exists uq_subjects_school_code_ci
  on public.subjects(school_id, lower(trim(code)));

create unique index if not exists uq_subjects_school_name_ci
  on public.subjects(school_id, lower(trim(name)));

create index if not exists idx_subjects_school_active_domain
  on public.subjects(school_id, is_active, domain, name);

-- =========================================================
-- B. CONFIGURATION D'UNE MATIÈRE PAR NIVEAU ET ANNÉE
-- =========================================================
create table if not exists public.subject_level_assignments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  level_id uuid not null references public.levels(id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  coefficient_override numeric(8,2),
  weekly_hours_override numeric(6,2),
  is_required boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_year_id, level_id, subject_id),
  check(coefficient_override is null or coefficient_override > 0),
  check(weekly_hours_override is null or weekly_hours_override > 0)
);

create index if not exists idx_subject_level_assignments_school_year_level
  on public.subject_level_assignments(school_id, school_year_id, level_id, is_active);

create index if not exists idx_subject_level_assignments_subject
  on public.subject_level_assignments(school_id, subject_id, is_active);

-- updated_at
 drop trigger if exists trg_subject_level_assignments_updated_at on public.subject_level_assignments;
 create trigger trg_subject_level_assignments_updated_at
 before update on public.subject_level_assignments
 for each row execute function app.set_updated_at();

-- =========================================================
-- C. INTÉGRITÉ MULTI-ÉCOLES
-- =========================================================
create or replace function app.validate_subject_level_assignment_integrity()
returns trigger
language plpgsql
set search_path = public, app
as $$
declare
  v_school uuid;
begin
  select school_id into v_school
  from public.school_years
  where id = new.school_year_id;
  if v_school is null then raise exception 'INVALID_SCHOOL_YEAR'; end if;
  if v_school <> new.school_id then raise exception 'CROSS_SCHOOL: subject_level_assignments.school_year_id'; end if;

  select school_id into v_school
  from public.levels
  where id = new.level_id;
  if v_school is null then raise exception 'INVALID_LEVEL'; end if;
  if v_school <> new.school_id then raise exception 'CROSS_SCHOOL: subject_level_assignments.level_id'; end if;

  select school_id into v_school
  from public.subjects
  where id = new.subject_id;
  if v_school is null then raise exception 'INVALID_SUBJECT'; end if;
  if v_school <> new.school_id then raise exception 'CROSS_SCHOOL: subject_level_assignments.subject_id'; end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_subject_level_assignment_integrity on public.subject_level_assignments;
create trigger trg_validate_subject_level_assignment_integrity
before insert or update on public.subject_level_assignments
for each row execute function app.validate_subject_level_assignment_integrity();

-- =========================================================
-- D. PERMISSIONS
-- =========================================================
insert into public.permissions(code, name, module, action, description)
values
  ('subjects.view', 'Consulter matières', 'academic', 'view', 'Consulter le catalogue des matières'),
  ('subjects.manage', 'Gérer matières', 'academic', 'manage', 'Créer, modifier, archiver et paramétrer les matières')
on conflict(code) do update
set name = excluded.name,
    module = excluded.module,
    action = excluded.action,
    description = excluded.description;

-- Admin / direction / responsable pédagogique
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('subjects.view','subjects.manage')
where r.code in ('super_admin','founder','direction','admin','academic_director')
on conflict do nothing;

-- Enseignant : lecture du catalogue et de ses configurations
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'subjects.view'
where r.code = 'teacher'
on conflict do nothing;

-- =========================================================
-- E. RLS SUBJECTS
-- =========================================================
drop policy if exists subjects_select_secure on public.subjects;
drop policy if exists subjects_insert_secure on public.subjects;
drop policy if exists subjects_update_secure on public.subjects;
drop policy if exists subjects_delete_secure on public.subjects;

drop policy if exists subjects_select_018 on public.subjects;
drop policy if exists subjects_insert_018 on public.subjects;
drop policy if exists subjects_update_018 on public.subjects;
drop policy if exists subjects_delete_018 on public.subjects;

create policy subjects_select_018
on public.subjects
for select to authenticated
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

create policy subjects_insert_018
on public.subjects
for insert to authenticated
with check (
  app.is_super_admin() or app.has_permission('subjects.manage', school_id)
);

create policy subjects_update_018
on public.subjects
for update to authenticated
using (app.is_super_admin() or app.has_permission('subjects.manage', school_id))
with check (app.is_super_admin() or app.has_permission('subjects.manage', school_id));

create policy subjects_delete_018
on public.subjects
for delete to authenticated
using (app.is_super_admin() or app.has_permission('subjects.manage', school_id));

-- =========================================================
-- F. RLS SUBJECT-LEVEL ASSIGNMENTS
-- =========================================================
alter table public.subject_level_assignments enable row level security;

drop policy if exists subject_level_assignments_select_018 on public.subject_level_assignments;
drop policy if exists subject_level_assignments_insert_018 on public.subject_level_assignments;
drop policy if exists subject_level_assignments_update_018 on public.subject_level_assignments;
drop policy if exists subject_level_assignments_delete_018 on public.subject_level_assignments;

create policy subject_level_assignments_select_018
on public.subject_level_assignments
for select to authenticated
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

create policy subject_level_assignments_insert_018
on public.subject_level_assignments
for insert to authenticated
with check (app.is_super_admin() or app.has_permission('subjects.manage', school_id));

create policy subject_level_assignments_update_018
on public.subject_level_assignments
for update to authenticated
using (app.is_super_admin() or app.has_permission('subjects.manage', school_id))
with check (app.is_super_admin() or app.has_permission('subjects.manage', school_id));

create policy subject_level_assignments_delete_018
on public.subject_level_assignments
for delete to authenticated
using (app.is_super_admin() or app.has_permission('subjects.manage', school_id));

-- =========================================================
-- G. RPC MÉTIER
-- =========================================================
create or replace function public.create_subject(
  p_code text,
  p_name text,
  p_domain text default 'general',
  p_coefficient numeric default 1,
  p_weekly_hours numeric default null,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_user public.users%rowtype;
  v_id uuid;
begin
  select * into v_user
  from public.users
  where id = auth.uid() and status = 'active';

  if v_user.id is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_user.school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then raise exception 'SUBJECT_CODE_REQUIRED'; end if;
  if length(trim(coalesce(p_name,''))) = 0 then raise exception 'SUBJECT_NAME_REQUIRED'; end if;
  if length(trim(coalesce(p_domain,''))) = 0 then raise exception 'SUBJECT_DOMAIN_REQUIRED'; end if;
  if p_coefficient is null or p_coefficient <= 0 then raise exception 'SUBJECT_COEFFICIENT_INVALID'; end if;
  if p_weekly_hours is not null and p_weekly_hours <= 0 then raise exception 'SUBJECT_WEEKLY_HOURS_INVALID'; end if;

  insert into public.subjects(school_id, code, name, domain, coefficient, weekly_hours, description, is_active)
  values (
    v_user.school_id,
    trim(p_code),
    trim(p_name),
    lower(trim(p_domain)),
    p_coefficient,
    p_weekly_hours,
    nullif(trim(p_description), ''),
    true
  ) returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_subject(
  p_subject_id uuid,
  p_code text,
  p_name text,
  p_domain text,
  p_coefficient numeric,
  p_weekly_hours numeric default null,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
begin
  select school_id into v_school_id from public.subjects where id=p_subject_id;
  if v_school_id is null then raise exception 'SUBJECT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then raise exception 'SUBJECT_CODE_REQUIRED'; end if;
  if length(trim(coalesce(p_name,''))) = 0 then raise exception 'SUBJECT_NAME_REQUIRED'; end if;
  if length(trim(coalesce(p_domain,''))) = 0 then raise exception 'SUBJECT_DOMAIN_REQUIRED'; end if;
  if p_coefficient is null or p_coefficient <= 0 then raise exception 'SUBJECT_COEFFICIENT_INVALID'; end if;
  if p_weekly_hours is not null and p_weekly_hours <= 0 then raise exception 'SUBJECT_WEEKLY_HOURS_INVALID'; end if;

  update public.subjects
  set code=trim(p_code),
      name=trim(p_name),
      domain=lower(trim(p_domain)),
      coefficient=p_coefficient,
      weekly_hours=p_weekly_hours,
      description=nullif(trim(p_description), '')
  where id=p_subject_id;

  return p_subject_id;
end;
$$;

create or replace function public.set_subject_active(
  p_subject_id uuid,
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
  select school_id into v_school_id from public.subjects where id=p_subject_id;
  if v_school_id is null then raise exception 'SUBJECT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;

  if not p_is_active then
    select count(*) into v_active_assignments
    from public.subject_level_assignments
    where subject_id=p_subject_id and is_active=true;
    if v_active_assignments > 0 then raise exception 'SUBJECT_HAS_ACTIVE_LEVEL_ASSIGNMENTS'; end if;
  end if;

  update public.subjects set is_active=p_is_active where id=p_subject_id;
  return p_subject_id;
end;
$$;

create or replace function public.assign_subject_to_level(
  p_school_year_id uuid,
  p_level_id uuid,
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
  v_school_id uuid;
  v_level_school uuid;
  v_subject_school uuid;
  v_id uuid;
begin
  select * into v_user from public.users where id=auth.uid() and status='active';
  if v_user.id is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_user.school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;

  select school_id into v_school_id from public.school_years where id=p_school_year_id;
  if v_school_id is null or v_school_id<>v_user.school_id then raise exception 'INVALID_SCHOOL_YEAR'; end if;

  select school_id into v_level_school from public.levels where id=p_level_id and is_active=true;
  if v_level_school is null or v_level_school<>v_user.school_id then raise exception 'INVALID_LEVEL'; end if;

  select school_id into v_subject_school from public.subjects where id=p_subject_id and is_active=true;
  if v_subject_school is null or v_subject_school<>v_user.school_id then raise exception 'INVALID_SUBJECT'; end if;

  if p_coefficient_override is not null and p_coefficient_override<=0 then raise exception 'SUBJECT_COEFFICIENT_INVALID'; end if;
  if p_weekly_hours_override is not null and p_weekly_hours_override<=0 then raise exception 'SUBJECT_WEEKLY_HOURS_INVALID'; end if;

  insert into public.subject_level_assignments(
    school_id, school_year_id, level_id, subject_id,
    coefficient_override, weekly_hours_override, is_required, is_active
  ) values (
    v_user.school_id, p_school_year_id, p_level_id, p_subject_id,
    p_coefficient_override, p_weekly_hours_override, p_is_required, true
  )
  on conflict (school_year_id, level_id, subject_id)
  do update set
    coefficient_override=excluded.coefficient_override,
    weekly_hours_override=excluded.weekly_hours_override,
    is_required=excluded.is_required,
    is_active=true,
    updated_at=now()
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.set_subject_level_active(
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
  select school_id into v_school_id from public.subject_level_assignments where id=p_assignment_id;
  if v_school_id is null then raise exception 'SUBJECT_LEVEL_ASSIGNMENT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('subjects.manage', v_school_id) then
    raise exception 'FORBIDDEN_SUBJECT_MANAGE';
  end if;
  update public.subject_level_assignments set is_active=p_is_active where id=p_assignment_id;
  return p_assignment_id;
end;
$$;

revoke all on function public.create_subject(text,text,text,numeric,numeric,text) from public;
revoke all on function public.update_subject(uuid,text,text,text,numeric,numeric,text) from public;
revoke all on function public.set_subject_active(uuid,boolean) from public;
revoke all on function public.assign_subject_to_level(uuid,uuid,uuid,numeric,numeric,boolean) from public;
revoke all on function public.set_subject_level_active(uuid,boolean) from public;

grant execute on function public.create_subject(text,text,text,numeric,numeric,text) to authenticated;
grant execute on function public.update_subject(uuid,text,text,text,numeric,numeric,text) to authenticated;
grant execute on function public.set_subject_active(uuid,boolean) to authenticated;
grant execute on function public.assign_subject_to_level(uuid,uuid,uuid,numeric,numeric,boolean) to authenticated;
grant execute on function public.set_subject_level_active(uuid,boolean) to authenticated;

comment on table public.subjects is 'Catalogue stable des matières de l''établissement. Les paramètres par niveau/année sont gérés dans subject_level_assignments.';
comment on table public.subject_level_assignments is 'Association d''une matière à un niveau et une année, avec coefficient/volume horaire éventuellement surchargés.';

commit;
