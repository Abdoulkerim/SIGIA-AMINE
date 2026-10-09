-- SIGIA-AMINE
-- Migration 017: academic_levels_classes
-- Étape 9 — Niveaux / Classes
--
-- Objectifs :
-- 1. Sécuriser le référentiel des niveaux et classes.
-- 2. Empêcher les relations inter-écoles.
-- 3. Ajouter des permissions de lecture/gestion distinctes.
-- 4. Fournir des RPC atomiques pour les opérations sensibles.
-- 5. Ajouter les index de recherche réellement utiles.
-- 6. Ne pas inventer les niveaux/classes officiels d'Al Amine.
--
begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- ---------------------------------------------------------
-- A. Contraintes de qualité
-- ---------------------------------------------------------
alter table public.levels
  drop constraint if exists levels_code_not_blank,
  drop constraint if exists levels_name_not_blank,
  drop constraint if exists levels_sequence_nonnegative;

alter table public.levels
  add constraint levels_code_not_blank check (length(trim(code)) > 0),
  add constraint levels_name_not_blank check (length(trim(name)) > 0),
  add constraint levels_sequence_nonnegative check (sequence_no is null or sequence_no >= 0);

alter table public.classes
  drop constraint if exists classes_code_not_blank,
  drop constraint if exists classes_name_not_blank,
  drop constraint if exists classes_capacity_positive,
  drop constraint if exists classes_level_required;

alter table public.classes
  add constraint classes_code_not_blank check (length(trim(code)) > 0),
  add constraint classes_name_not_blank check (length(trim(name)) > 0),
  add constraint classes_capacity_positive check (capacity is null or capacity > 0),
  add constraint classes_level_required check (is_active = false or level_id is not null);

alter table public.classes
  alter column level_id set not null;

-- ---------------------------------------------------------
-- B. Index uniques insensibles à la casse
-- ---------------------------------------------------------
create unique index if not exists uq_levels_school_code_ci
  on public.levels(school_id, lower(trim(code)));

create unique index if not exists uq_levels_school_name_ci
  on public.levels(school_id, lower(trim(name)));

create unique index if not exists uq_classes_school_year_code_ci
  on public.classes(school_id, school_year_id, lower(trim(code)));

create unique index if not exists uq_classes_school_year_name_section_ci
  on public.classes(
    school_id,
    school_year_id,
    lower(trim(name)),
    lower(trim(coalesce(section, '')))
  );

create index if not exists idx_levels_school_active_sequence
  on public.levels(school_id, is_active, sequence_no, name);

create index if not exists idx_classes_school_year_active_level
  on public.classes(school_id, school_year_id, is_active, level_id, name);

create index if not exists idx_classes_school_year_section
  on public.classes(school_id, school_year_id, section);

-- ---------------------------------------------------------
-- C. Validation des relations inter-écoles
-- ---------------------------------------------------------
create or replace function app.validate_level_class_integrity()
returns trigger
language plpgsql
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_level_school uuid;
begin
  if TG_TABLE_NAME = 'classes' then
    select school_id into v_school_id
    from public.school_years
    where id = NEW.school_year_id;

    if v_school_id is null then
      raise exception 'INVALID_SCHOOL_YEAR';
    end if;

    if v_school_id <> NEW.school_id then
      raise exception 'CROSS_SCHOOL: classes.school_year_id';
    end if;

    select school_id into v_level_school
    from public.levels
    where id = NEW.level_id;

    if v_level_school is null then
      raise exception 'INVALID_LEVEL';
    end if;

    if v_level_school <> NEW.school_id then
      raise exception 'CROSS_SCHOOL: classes.level_id';
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_validate_level_class_integrity on public.classes;
create trigger trg_validate_level_class_integrity
before insert or update on public.classes
for each row
execute function app.validate_level_class_integrity();

-- ---------------------------------------------------------
-- D. Permissions
-- ---------------------------------------------------------
insert into public.permissions(code, name, module, action, description)
values
  ('levels.view', 'Consulter niveaux', 'academic', 'view', 'Consulter le référentiel des niveaux'),
  ('levels.manage', 'Gérer niveaux', 'academic', 'manage', 'Créer, modifier et archiver les niveaux'),
  ('classes.view', 'Consulter classes', 'academic', 'view', 'Consulter les classes et leurs capacités'),
  ('classes.manage', 'Gérer classes', 'academic', 'manage', 'Créer, modifier et archiver les classes')
on conflict(code) do update
set
  name = excluded.name,
  module = excluded.module,
  action = excluded.action,
  description = excluded.description;

-- Admin / direction / pédagogique
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'levels.view','levels.manage','classes.view','classes.manage'
)
where r.code in ('super_admin','founder','direction','admin','academic_director')
on conflict do nothing;

-- Enseignants : lecture uniquement
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'classes.view'
where r.code = 'teacher'
on conflict do nothing;

-- Personnel encadrement : lecture des classes
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'classes.view'
where r.code in ('supervisor','boarding_manager','tahfiz_manager','arabic_manager','wushu_manager')
on conflict do nothing;

-- ---------------------------------------------------------
-- E. RLS propre pour levels/classes
-- ---------------------------------------------------------
drop policy if exists levels_select_secure on public.levels;
drop policy if exists levels_insert_secure on public.levels;
drop policy if exists levels_update_secure on public.levels;
drop policy if exists levels_delete_secure on public.levels;

create policy levels_select_017
on public.levels
for select
to authenticated
using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      app.has_permission('levels.view', school_id)
      or app.has_permission('levels.manage', school_id)
      or app.has_permission('classes.view', school_id)
      or app.has_permission('classes.manage', school_id)
    )
  )
);

create policy levels_insert_017
on public.levels
for insert
to authenticated
with check (
  app.is_super_admin()
  or app.has_permission('levels.manage', school_id)
);

create policy levels_update_017
on public.levels
for update
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('levels.manage', school_id)
)
with check (
  app.is_super_admin()
  or app.has_permission('levels.manage', school_id)
);

create policy levels_delete_017
on public.levels
for delete
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('levels.manage', school_id)
);

drop policy if exists classes_select_secure on public.classes;
drop policy if exists classes_insert_secure on public.classes;
drop policy if exists classes_update_secure on public.classes;
drop policy if exists classes_delete_secure on public.classes;

create policy classes_select_017
on public.classes
for select
to authenticated
using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      app.has_permission('classes.view', school_id)
      or app.has_permission('classes.manage', school_id)
    )
  )
);

create policy classes_insert_017
on public.classes
for insert
to authenticated
with check (
  app.is_super_admin()
  or app.has_permission('classes.manage', school_id)
);

create policy classes_update_017
on public.classes
for update
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('classes.manage', school_id)
)
with check (
  app.is_super_admin()
  or app.has_permission('classes.manage', school_id)
);

create policy classes_delete_017
on public.classes
for delete
to authenticated
using (
  app.is_super_admin()
  or app.has_permission('classes.manage', school_id)
);

-- ---------------------------------------------------------
-- F. RPC — niveaux
-- ---------------------------------------------------------
create or replace function public.create_level(
  p_code text,
  p_name text,
  p_education_cycle text default null,
  p_sequence_no integer default null
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
  where id = auth.uid()
    and status = 'active';

  if v_user.id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not app.has_permission('levels.manage', v_user.school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_LEVEL_MANAGE';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then
    raise exception 'LEVEL_CODE_REQUIRED';
  end if;

  if length(trim(coalesce(p_name,''))) = 0 then
    raise exception 'LEVEL_NAME_REQUIRED';
  end if;

  if p_sequence_no is not null and p_sequence_no < 0 then
    raise exception 'LEVEL_SEQUENCE_INVALID';
  end if;

  insert into public.levels(school_id, code, name, education_cycle, sequence_no, is_active)
  values (
    v_user.school_id,
    trim(p_code),
    trim(p_name),
    nullif(trim(p_education_cycle), ''),
    p_sequence_no,
    true
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_level(
  p_level_id uuid,
  p_code text,
  p_name text,
  p_education_cycle text default null,
  p_sequence_no integer default null
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
  from public.levels
  where id = p_level_id;

  if v_school_id is null then
    raise exception 'LEVEL_NOT_FOUND';
  end if;

  if not app.has_permission('levels.manage', v_school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_LEVEL_MANAGE';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then
    raise exception 'LEVEL_CODE_REQUIRED';
  end if;

  if length(trim(coalesce(p_name,''))) = 0 then
    raise exception 'LEVEL_NAME_REQUIRED';
  end if;

  if p_sequence_no is not null and p_sequence_no < 0 then
    raise exception 'LEVEL_SEQUENCE_INVALID';
  end if;

  update public.levels
  set
    code = trim(p_code),
    name = trim(p_name),
    education_cycle = nullif(trim(p_education_cycle), ''),
    sequence_no = p_sequence_no
  where id = p_level_id;

  return p_level_id;
end;
$$;

create or replace function public.set_level_active(
  p_level_id uuid,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_active_classes bigint;
begin
  select school_id into v_school_id
  from public.levels
  where id = p_level_id;

  if v_school_id is null then
    raise exception 'LEVEL_NOT_FOUND';
  end if;

  if not app.has_permission('levels.manage', v_school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_LEVEL_MANAGE';
  end if;

  if not p_is_active then
    select count(*) into v_active_classes
    from public.classes
    where level_id = p_level_id and is_active = true;

    if v_active_classes > 0 then
      raise exception 'LEVEL_HAS_ACTIVE_CLASSES';
    end if;
  end if;

  update public.levels
  set is_active = p_is_active
  where id = p_level_id;

  return p_level_id;
end;
$$;

-- ---------------------------------------------------------
-- G. RPC — classes
-- ---------------------------------------------------------
create or replace function public.create_class(
  p_school_year_id uuid,
  p_level_id uuid,
  p_name text,
  p_code text,
  p_section text default null,
  p_room_name text default null,
  p_capacity integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_user public.users%rowtype;
  v_year_school uuid;
  v_level_school uuid;
  v_id uuid;
begin
  select * into v_user
  from public.users
  where id = auth.uid()
    and status = 'active';

  if v_user.id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not app.has_permission('classes.manage', v_user.school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_CLASS_MANAGE';
  end if;

  select school_id into v_year_school
  from public.school_years
  where id = p_school_year_id;

  if v_year_school is null or (v_year_school <> v_user.school_id and not app.is_super_admin()) then
    raise exception 'INVALID_SCHOOL_YEAR';
  end if;

  select school_id into v_level_school
  from public.levels
  where id = p_level_id
    and is_active = true;

  if v_level_school is null or (v_level_school <> v_user.school_id and not app.is_super_admin()) then
    raise exception 'INVALID_LEVEL';
  end if;

  if length(trim(coalesce(p_name,''))) = 0 then
    raise exception 'CLASS_NAME_REQUIRED';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then
    raise exception 'CLASS_CODE_REQUIRED';
  end if;

  if p_capacity is not null and p_capacity <= 0 then
    raise exception 'CLASS_CAPACITY_INVALID';
  end if;

  insert into public.classes(
    school_id, school_year_id, level_id, name, code, section,
    room_name, capacity, is_active
  )
  values (
    v_user.school_id,
    p_school_year_id,
    p_level_id,
    trim(p_name),
    trim(p_code),
    nullif(trim(p_section), ''),
    nullif(trim(p_room_name), ''),
    p_capacity,
    true
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_class(
  p_class_id uuid,
  p_school_year_id uuid,
  p_level_id uuid,
  p_name text,
  p_code text,
  p_section text default null,
  p_room_name text default null,
  p_capacity integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_year_school uuid;
  v_level_school uuid;
begin
  select school_id into v_school_id
  from public.classes
  where id = p_class_id;

  if v_school_id is null then
    raise exception 'CLASS_NOT_FOUND';
  end if;

  if not app.has_permission('classes.manage', v_school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_CLASS_MANAGE';
  end if;

  select school_id into v_year_school
  from public.school_years
  where id = p_school_year_id;

  if v_year_school is distinct from v_school_id then
    raise exception 'CROSS_SCHOOL: classes.school_year_id';
  end if;

  select school_id into v_level_school
  from public.levels
  where id = p_level_id
    and is_active = true;

  if v_level_school is distinct from v_school_id then
    raise exception 'CROSS_SCHOOL: classes.level_id';
  end if;

  if length(trim(coalesce(p_name,''))) = 0 then
    raise exception 'CLASS_NAME_REQUIRED';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then
    raise exception 'CLASS_CODE_REQUIRED';
  end if;

  if p_capacity is not null and p_capacity <= 0 then
    raise exception 'CLASS_CAPACITY_INVALID';
  end if;

  update public.classes
  set
    school_year_id = p_school_year_id,
    level_id = p_level_id,
    name = trim(p_name),
    code = trim(p_code),
    section = nullif(trim(p_section), ''),
    room_name = nullif(trim(p_room_name), ''),
    capacity = p_capacity
  where id = p_class_id;

  return p_class_id;
end;
$$;

create or replace function public.set_class_active(
  p_class_id uuid,
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
  from public.classes
  where id = p_class_id;

  if v_school_id is null then
    raise exception 'CLASS_NOT_FOUND';
  end if;

  if not app.has_permission('classes.manage', v_school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_CLASS_MANAGE';
  end if;

  update public.classes
  set is_active = p_is_active
  where id = p_class_id;

  return p_class_id;
end;
$$;

revoke all on function public.create_level(text,text,text,integer) from public;
revoke all on function public.update_level(uuid,text,text,text,integer) from public;
revoke all on function public.set_level_active(uuid,boolean) from public;
revoke all on function public.create_class(uuid,uuid,text,text,text,text,integer) from public;
revoke all on function public.update_class(uuid,uuid,uuid,text,text,text,text,integer) from public;
revoke all on function public.set_class_active(uuid,boolean) from public;

grant execute on function public.create_level(text,text,text,integer) to authenticated;
grant execute on function public.update_level(uuid,text,text,text,integer) to authenticated;
grant execute on function public.set_level_active(uuid,boolean) to authenticated;
grant execute on function public.create_class(uuid,uuid,text,text,text,text,integer) to authenticated;
grant execute on function public.update_class(uuid,uuid,uuid,text,text,text,text,integer) to authenticated;
grant execute on function public.set_class_active(uuid,boolean) to authenticated;

comment on table public.levels is 'Référentiel des niveaux pédagogiques par établissement. Les données officielles d''Al Amine sont saisies par l''administration et non inventées dans le seed.';
comment on table public.classes is 'Classes par année scolaire et niveau. Une classe active doit être rattachée à un niveau.';
comment on column public.classes.capacity is 'Capacité maximale autorisée pour la classe; le contrôle de dépassement est assuré lors de la finalisation des inscriptions.';

commit;
