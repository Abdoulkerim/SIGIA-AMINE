-- SIGIA-AMINE — Migration 015: Workflow Admissions / Préinscriptions
-- Étape 7
-- Objectifs :
-- 1) enrichir le dossier de candidature avant création de l'élève ;
-- 2) sécuriser les relations inter-écoles ;
-- 3) encadrer les transitions de statut ;
-- 4) séparer la permission admissions de la permission inscriptions ;
-- 5) indexer les recherches fréquentes.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

alter table public.admission_applications
  add column if not exists candidate_first_name text,
  add column if not exists candidate_last_name text,
  add column if not exists candidate_gender app.gender_type,
  add column if not exists candidate_date_of_birth date,
  add column if not exists candidate_place_of_birth text,
  add column if not exists candidate_nationality text,
  add column if not exists candidate_address text,
  add column if not exists desired_level_label text,
  add column if not exists primary_parent_id uuid references public.parents(id) on delete set null,
  add column if not exists updated_at timestamptz not null default now();

alter table public.admission_applications
  alter column application_number set default (
    'ADM-' || to_char(current_date, 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
  ),
  alter column submitted_at set default now();

update public.admission_applications
set updated_at = coalesce(updated_at, created_at, now())
where updated_at is null;

create index if not exists idx_admission_school_status_created
  on public.admission_applications(school_id, status, created_at desc);

create index if not exists idx_admission_school_year_status
  on public.admission_applications(school_id, desired_year_id, status);

create index if not exists idx_admission_school_level_status
  on public.admission_applications(school_id, desired_level_id, status);

create index if not exists idx_admission_school_parent
  on public.admission_applications(school_id, primary_parent_id)
  where primary_parent_id is not null;

create index if not exists idx_admission_candidate_name
  on public.admission_applications(school_id, lower(candidate_last_name), lower(candidate_first_name));

create or replace function app.validate_admission_cross_school()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school uuid;
begin
  if new.student_id is not null then
    select school_id into v_school from public.students where id = new.student_id;
    if v_school is null or v_school <> new.school_id then
      raise exception 'CROSS_SCHOOL: admission_applications.student_id';
    end if;
  end if;

  if new.desired_level_id is not null then
    select school_id into v_school from public.levels where id = new.desired_level_id;
    if v_school is null or v_school <> new.school_id then
      raise exception 'CROSS_SCHOOL: admission_applications.desired_level_id';
    end if;
  end if;

  if new.desired_year_id is not null then
    select school_id into v_school from public.school_years where id = new.desired_year_id;
    if v_school is null or v_school <> new.school_id then
      raise exception 'CROSS_SCHOOL: admission_applications.desired_year_id';
    end if;
  end if;

  if new.primary_parent_id is not null then
    select school_id into v_school from public.parents where id = new.primary_parent_id;
    if v_school is null or v_school <> new.school_id then
      raise exception 'CROSS_SCHOOL: admission_applications.primary_parent_id';
    end if;
  end if;

  if new.reviewed_by is not null then
    select school_id into v_school from public.users where id = new.reviewed_by;
    if v_school is null or v_school <> new.school_id then
      raise exception 'CROSS_SCHOOL: admission_applications.reviewed_by';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_admission_cross_school on public.admission_applications;
create trigger trg_admission_cross_school
before insert or update on public.admission_applications
for each row execute function app.validate_admission_cross_school();

create or replace function app.validate_admission_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending' then
      raise exception 'ADMISSION_STATUS: une nouvelle préinscription doit commencer en pending';
    end if;
    return new;
  end if;

  if old.status = 'enrolled' and new.status <> old.status then
    raise exception 'ADMISSION_STATUS: une admission enrolled est verrouillée depuis le workflow admission';
  end if;

  if old.status = new.status then
    return new;
  end if;

  if old.status = 'pending' and new.status in ('approved','rejected','cancelled') then
    return new;
  end if;

  if old.status = 'approved' and new.status in ('enrolled','cancelled') then
    return new;
  end if;

  if old.status = 'rejected' and new.status in ('pending','cancelled') then
    return new;
  end if;

  if old.status = 'cancelled' and new.status = 'pending' then
    return new;
  end if;

  raise exception 'ADMISSION_STATUS: transition % -> % interdite', old.status, new.status;
end;
$$;

drop trigger if exists trg_admission_status_transition on public.admission_applications;
create trigger trg_admission_status_transition
before update of status on public.admission_applications
for each row execute function app.validate_admission_status_transition();

create or replace function app.validate_admission_review_fields()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
begin
  if new.status in ('approved','rejected','cancelled') then
    if new.reviewed_at is null or new.reviewed_by is null then
      raise exception 'ADMISSION_REVIEW: reviewed_at et reviewed_by sont obligatoires';
    end if;
  end if;

  if new.status = 'pending' then
    new.reviewed_at := null;
    new.reviewed_by := null;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_admission_review_fields on public.admission_applications;
create trigger trg_admission_review_fields
before insert or update on public.admission_applications
for each row execute function app.validate_admission_review_fields();

-- Permissionnement spécifique aux admissions.
insert into public.permissions(code,name,module,action,description)
values
  ('admissions.view','Consulter admissions','admissions','view','Consulter les dossiers de préinscription et leurs statuts'),
  ('admissions.manage','Gérer admissions','admissions','manage','Créer, examiner et statuer sur les préinscriptions')
on conflict(code) do update set
  name = excluded.name,
  module = excluded.module,
  action = excluded.action,
  description = excluded.description;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('admissions.view','admissions.manage')
where r.code in ('super_admin','founder','direction','admin')
on conflict do nothing;

-- Remplace les policies générales 014 utilisant enrollments.manage.
drop policy if exists admission_applications_select_secure on public.admission_applications;
drop policy if exists admission_applications_insert_secure on public.admission_applications;
drop policy if exists admission_applications_update_secure on public.admission_applications;
drop policy if exists admission_applications_delete_secure on public.admission_applications;

create policy admission_applications_select_015
on public.admission_applications
for select
using (
  app.has_permission('admissions.view', school_id)
  or app.has_permission('admissions.manage', school_id)
  or app.has_role_code('direction', school_id)
  or app.has_role_code('founder', school_id)
  or app.is_super_admin()
);

create policy admission_applications_insert_015
on public.admission_applications
for insert
with check (
  app.has_permission('admissions.manage', school_id)
  or app.has_role_code('direction', school_id)
  or app.has_role_code('founder', school_id)
  or app.is_super_admin()
);

create policy admission_applications_update_015
on public.admission_applications
for update
using (
  app.has_permission('admissions.manage', school_id)
  or app.has_role_code('direction', school_id)
  or app.has_role_code('founder', school_id)
  or app.is_super_admin()
)
with check (
  app.has_permission('admissions.manage', school_id)
  or app.has_role_code('direction', school_id)
  or app.has_role_code('founder', school_id)
  or app.is_super_admin()
);

create policy admission_applications_delete_015
on public.admission_applications
for delete
using (
  app.has_permission('admissions.manage', school_id)
  or app.has_role_code('direction', school_id)
  or app.has_role_code('founder', school_id)
  or app.is_super_admin()
);

comment on table public.admission_applications is 'Préinscriptions et admissions : dossier candidat avant conversion en élève/inscription.';
comment on column public.admission_applications.desired_level_label is 'Libellé saisi lors de la préinscription si le référentiel des niveaux n’est pas encore configuré; sera rapproché de desired_level_id ensuite.';
comment on column public.admission_applications.primary_parent_id is 'Parent/tuteur principal connu au moment de la préinscription; relation scolaire multi-enfants gérée ultérieurement.';

commit;
