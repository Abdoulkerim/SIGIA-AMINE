-- SIGIA-AMINE
-- Migration 024: boarding workflows
-- Étape 16 — Internat
-- Périmètre : bâtiments/dortoirs, chambres/lits, affectations, mouvements,
-- présences d'internat et contrôles de cohérence.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- 01. PERMISSIONS
-- =========================================================
insert into public.permissions(code,name,module,action,description)
values
  ('boarding.view','Consulter internat','boarding','view','Consulter structures, affectations, mouvements et présences d’internat')
on conflict (code) do update
set name = excluded.name,
    module = excluded.module,
    action = excluded.action,
    description = excluded.description;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.permissions p on p.code='boarding.view'
where r.code in ('super_admin','founder','direction','boarding_manager')
on conflict do nothing;

-- =========================================================
-- 02. QUALITÉ / CONTRAINTES / INDEXES
-- =========================================================
create unique index if not exists ux_boarding_buildings_school_lower_code
  on public.boarding_buildings(school_id, lower(trim(code)));

create unique index if not exists ux_boarding_buildings_school_lower_name
  on public.boarding_buildings(school_id, lower(trim(name)));

create unique index if not exists ux_boarding_dormitories_building_lower_name
  on public.boarding_dormitories(building_id, lower(trim(name)));

create unique index if not exists ux_boarding_rooms_dormitory_lower_name
  on public.boarding_rooms(dormitory_id, lower(trim(name)));

create unique index if not exists ux_boarding_beds_room_lower_number
  on public.boarding_beds(room_id, lower(trim(bed_number)));

create index if not exists ix_boarding_dormitories_building
  on public.boarding_dormitories(building_id);

create index if not exists ix_boarding_rooms_dormitory_status
  on public.boarding_rooms(dormitory_id,status);

create index if not exists ix_boarding_beds_room_status
  on public.boarding_beds(room_id,status);

create index if not exists ix_boarding_assignments_school_status_dates
  on public.boarding_assignments(school_id,status,start_date,end_date);

create index if not exists ix_boarding_assignments_student_dates
  on public.boarding_assignments(student_id,start_date desc,end_date desc);

create index if not exists ix_boarding_movements_school_student_date
  on public.boarding_movements(school_id,student_id,movement_at desc);

create index if not exists ix_boarding_attendance_school_date
  on public.boarding_attendance(school_id,attendance_date desc);

alter table public.boarding_buildings drop constraint if exists boarding_buildings_code_ck;
alter table public.boarding_buildings add constraint boarding_buildings_code_ck
  check (length(trim(code)) between 1 and 40);

alter table public.boarding_buildings drop constraint if exists boarding_buildings_name_ck;
alter table public.boarding_buildings add constraint boarding_buildings_name_ck
  check (length(trim(name)) between 1 and 160);

alter table public.boarding_dormitories drop constraint if exists boarding_dormitories_name_ck;
alter table public.boarding_dormitories add constraint boarding_dormitories_name_ck
  check (length(trim(name)) between 1 and 160);

alter table public.boarding_rooms drop constraint if exists boarding_rooms_name_ck;
alter table public.boarding_rooms add constraint boarding_rooms_name_ck
  check (length(trim(name)) between 1 and 80);

alter table public.boarding_beds drop constraint if exists boarding_beds_number_ck;
alter table public.boarding_beds add constraint boarding_beds_number_ck
  check (length(trim(bed_number)) between 1 and 40);

alter table public.boarding_rooms drop constraint if exists boarding_rooms_status_ck;
alter table public.boarding_rooms add constraint boarding_rooms_status_ck
  check (status in ('active','maintenance','closed'));

alter table public.boarding_beds drop constraint if exists boarding_beds_status_ck;
alter table public.boarding_beds add constraint boarding_beds_status_ck
  check (status in ('available','occupied','maintenance','inactive'));

alter table public.boarding_assignments drop constraint if exists boarding_assignments_status_ck;
alter table public.boarding_assignments add constraint boarding_assignments_status_ck
  check (status in ('active','completed','cancelled'));

alter table public.boarding_attendance drop constraint if exists boarding_attendance_date_ck;
alter table public.boarding_attendance add constraint boarding_attendance_date_ck
  check (attendance_date is not null);

-- =========================================================
-- 03. HELPERS DE SÉCURITÉ / RÉSOLUTION D'ÉCOLE
-- =========================================================
create or replace function app.boarding_building_school_id(p_building_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.school_id
  from public.boarding_buildings b
  where b.id = p_building_id;
$$;

create or replace function app.boarding_dormitory_school_id(p_dormitory_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.school_id
  from public.boarding_dormitories d
  join public.boarding_buildings b on b.id=d.building_id
  where d.id=p_dormitory_id;
$$;

create or replace function app.boarding_room_school_id(p_room_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.school_id
  from public.boarding_rooms r
  join public.boarding_dormitories d on d.id=r.dormitory_id
  join public.boarding_buildings b on b.id=d.building_id
  where r.id=p_room_id;
$$;

create or replace function app.boarding_bed_school_id(p_bed_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.school_id
  from public.boarding_beds bed
  join public.boarding_rooms r on r.id=bed.room_id
  join public.boarding_dormitories d on d.id=r.dormitory_id
  join public.boarding_buildings b on b.id=d.building_id
  where bed.id=p_bed_id;
$$;

revoke all on function app.boarding_building_school_id(uuid) from public;
revoke all on function app.boarding_dormitory_school_id(uuid) from public;
revoke all on function app.boarding_room_school_id(uuid) from public;
revoke all on function app.boarding_bed_school_id(uuid) from public;
grant execute on function app.boarding_building_school_id(uuid) to authenticated;
grant execute on function app.boarding_dormitory_school_id(uuid) to authenticated;
grant execute on function app.boarding_room_school_id(uuid) to authenticated;
grant execute on function app.boarding_bed_school_id(uuid) to authenticated;

-- =========================================================
-- 04. INTÉGRITÉ DES AFFECTATIONS
-- =========================================================
create or replace function app.validate_boarding_assignment_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_school uuid;
  v_student_status app.student_status;
  v_student_residence app.residence_type;
  v_student_gender app.gender_type;
  v_bed_school uuid;
  v_bed_status text;
  v_dorm_gender app.gender_type;
  v_start date;
  v_end date;
begin
  select s.school_id, s.status, s.residence_type, s.gender
    into v_student_school, v_student_status, v_student_residence, v_student_gender
  from public.students s
  where s.id=new.student_id;

  if v_student_school is null then
    raise exception 'BOARDING_STUDENT_NOT_FOUND';
  end if;

  if new.school_id <> v_student_school then
    raise exception 'BOARDING_CROSS_SCHOOL';
  end if;

  if v_student_status not in ('active') then
    raise exception 'BOARDING_STUDENT_NOT_ACTIVE';
  end if;

  if v_student_residence <> 'internal' then
    raise exception 'BOARDING_STUDENT_NOT_INTERNAL';
  end if;

  select b.school_id, bed.status, d.gender
    into v_bed_school, v_bed_status, v_dorm_gender
  from public.boarding_beds bed
  join public.boarding_rooms r on r.id=bed.room_id
  join public.boarding_dormitories d on d.id=r.dormitory_id
  join public.boarding_buildings b on b.id=d.building_id
  where bed.id=new.bed_id;

  if v_bed_school is null then
    raise exception 'BOARDING_BED_NOT_FOUND';
  end if;

  if v_bed_school <> new.school_id then
    raise exception 'BOARDING_CROSS_SCHOOL';
  end if;

  if v_bed_status not in ('available','occupied') then
    raise exception 'BOARDING_BED_NOT_AVAILABLE';
  end if;

  if v_dorm_gender is not null and v_student_gender is not null and v_dorm_gender <> v_student_gender then
    raise exception 'BOARDING_GENDER_MISMATCH';
  end if;

  v_start := new.start_date;
  v_end := coalesce(new.end_date, 'infinity'::date);

  if v_end < v_start then
    raise exception 'BOARDING_INVALID_ASSIGNMENT_DATES';
  end if;

  if new.status='active' and new.end_date is not null then
    raise exception 'BOARDING_ACTIVE_ASSIGNMENT_REQUIRES_OPEN_END';
  end if;

  if exists (
    select 1
    from public.boarding_assignments x
    where x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
      and x.school_id=new.school_id
      and x.status in ('active','completed')
      and daterange(x.start_date,coalesce(x.end_date,'infinity'::date),'[]')
          && daterange(v_start,v_end,'[]')
      and (x.student_id=new.student_id or x.bed_id=new.bed_id)
  ) then
    raise exception 'BOARDING_OVERLAPPING_ASSIGNMENT';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_boarding_assignment_v2 on public.boarding_assignments;
create trigger trg_validate_boarding_assignment_v2
before insert or update on public.boarding_assignments
for each row execute function app.validate_boarding_assignment_v2();

-- Une chambre ne peut pas recevoir plus de lits que sa capacité.
create or replace function app.validate_boarding_bed_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_capacity integer;
  v_count integer;
begin
  select r.capacity into v_capacity
  from public.boarding_rooms r
  where r.id=new.room_id;

  select count(*) into v_count
  from public.boarding_beds bed
  where bed.room_id=new.room_id
    and bed.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);

  if v_count >= v_capacity then
    raise exception 'BOARDING_ROOM_CAPACITY_EXCEEDED';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_boarding_bed_capacity on public.boarding_beds;
create trigger trg_validate_boarding_bed_capacity
before insert on public.boarding_beds
for each row execute function app.validate_boarding_bed_capacity();

-- Synchronisation de l'état d'un lit avec l'affectation active.
create or replace function app.sync_boarding_bed_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op='INSERT' and new.status='active' then
    update public.boarding_beds set status='occupied' where id=new.bed_id;
  elsif tg_op='UPDATE' and old.bed_id<>new.bed_id then
    update public.boarding_beds set status='available'
    where id=old.bed_id
      and not exists (
        select 1 from public.boarding_assignments x
        where x.id<>new.id and x.bed_id=old.bed_id and x.status='active' and x.end_date is null
      );
    if new.status='active' then
      update public.boarding_beds set status='occupied' where id=new.bed_id;
    end if;
  elsif tg_op='UPDATE' and new.status<>'active' then
    update public.boarding_beds set status='available'
    where id=new.bed_id
      and not exists (
        select 1 from public.boarding_assignments x
        where x.id<>new.id and x.bed_id=new.bed_id and x.status='active' and x.end_date is null
      );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_boarding_bed_status on public.boarding_assignments;
create trigger trg_sync_boarding_bed_status
after insert or update on public.boarding_assignments
for each row execute function app.sync_boarding_bed_status();

-- =========================================================
-- 05. INTÉGRITÉ DES MOUVEMENTS / PRÉSENCES
-- =========================================================
create or replace function app.validate_boarding_movement_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_last_type text;
  v_has_active_assignment boolean;
begin
  select school_id into v_school from public.students where id=new.student_id;
  if v_school is null or v_school<>new.school_id then
    raise exception 'BOARDING_MOVEMENT_CROSS_SCHOOL';
  end if;

  select exists (
    select 1 from public.boarding_assignments a
    where a.student_id=new.student_id
      and a.school_id=new.school_id
      and a.status='active'
      and a.start_date<=new.movement_at::date
      and (a.end_date is null or a.end_date>=new.movement_at::date)
  ) into v_has_active_assignment;

  if not v_has_active_assignment then
    raise exception 'BOARDING_NO_ACTIVE_ASSIGNMENT';
  end if;

  select m.movement_type into v_last_type
  from public.boarding_movements m
  where m.student_id=new.student_id and m.school_id=new.school_id and m.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
  order by m.movement_at desc
  limit 1;

  if new.movement_type in ('exit','temporary_leave')
     and v_last_type in ('exit','temporary_leave') then
    raise exception 'BOARDING_STUDENT_ALREADY_OUT';
  end if;

  if new.movement_type='return'
     and coalesce(v_last_type,'') not in ('exit','temporary_leave') then
    raise exception 'BOARDING_RETURN_WITHOUT_EXIT';
  end if;

  if new.movement_type='entry'
     and v_last_type in ('entry','return') then
    raise exception 'BOARDING_DUPLICATE_ENTRY';
  end if;

  if new.movement_type in ('exit','temporary_leave')
    and nullif(trim(new."authorization"),'') is null then
    raise exception 'BOARDING_AUTHORIZATION_REQUIRED';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_boarding_movement_v2 on public.boarding_movements;
create trigger trg_validate_boarding_movement_v2
before insert or update on public.boarding_movements
for each row execute function app.validate_boarding_movement_v2();

create or replace function app.validate_boarding_attendance_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.boarding_assignments a
    where a.student_id=new.student_id
      and a.school_id=new.school_id
      and a.status='active'
      and a.start_date<=new.attendance_date
      and (a.end_date is null or a.end_date>=new.attendance_date)
  ) then
    raise exception 'BOARDING_NO_ACTIVE_ASSIGNMENT_FOR_ATTENDANCE';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_boarding_attendance_v2 on public.boarding_attendance;
create trigger trg_validate_boarding_attendance_v2
before insert or update on public.boarding_attendance
for each row execute function app.validate_boarding_attendance_v2();

-- =========================================================
-- 06. RLS : LECTURE PAR PERMISSION, MUTATIONS PAR RPC
-- =========================================================
-- Structures hiérarchiques : la school_id est reconstruite par relation.
drop policy if exists boarding_buildings_insert_secure on public.boarding_buildings;
drop policy if exists boarding_buildings_update_secure on public.boarding_buildings;
drop policy if exists boarding_buildings_delete_secure on public.boarding_buildings;
drop policy if exists boarding_buildings_select_secure on public.boarding_buildings;
create policy boarding_buildings_select_secure on public.boarding_buildings
for select using (
  app.has_permission('boarding.view',school_id)
  or app.has_permission('boarding.manage',school_id)
  or app.has_role_code('direction',school_id)
  or app.has_role_code('founder',school_id)
  or app.is_super_admin()
);

drop policy if exists boarding_dormitories_select_secure on public.boarding_dormitories;
create policy boarding_dormitories_select_secure on public.boarding_dormitories
for select using (
  app.has_permission('boarding.view',app.boarding_building_school_id(building_id))
  or app.has_permission('boarding.manage',app.boarding_building_school_id(building_id))
  or app.has_role_code('direction',app.boarding_building_school_id(building_id))
  or app.has_role_code('founder',app.boarding_building_school_id(building_id))
  or app.is_super_admin()
);

drop policy if exists boarding_rooms_select_secure on public.boarding_rooms;
create policy boarding_rooms_select_secure on public.boarding_rooms
for select using (
  app.has_permission('boarding.view',app.boarding_dormitory_school_id(dormitory_id))
  or app.has_permission('boarding.manage',app.boarding_dormitory_school_id(dormitory_id))
  or app.has_role_code('direction',app.boarding_dormitory_school_id(dormitory_id))
  or app.has_role_code('founder',app.boarding_dormitory_school_id(dormitory_id))
  or app.is_super_admin()
);

drop policy if exists boarding_beds_select_secure on public.boarding_beds;
create policy boarding_beds_select_secure on public.boarding_beds
for select using (
  app.has_permission('boarding.view',app.boarding_room_school_id(room_id))
  or app.has_permission('boarding.manage',app.boarding_room_school_id(room_id))
  or app.has_role_code('direction',app.boarding_room_school_id(room_id))
  or app.has_role_code('founder',app.boarding_room_school_id(room_id))
  or app.is_super_admin()
);

drop policy if exists boarding_assignments_insert_secure on public.boarding_assignments;
drop policy if exists boarding_assignments_update_secure on public.boarding_assignments;
drop policy if exists boarding_assignments_delete_secure on public.boarding_assignments;
drop policy if exists boarding_assignments_select_secure on public.boarding_assignments;
create policy boarding_assignments_select_secure on public.boarding_assignments
for select using (
  app.has_permission('boarding.view',school_id)
  or app.has_permission('boarding.manage',school_id)
  or app.has_role_code('direction',school_id)
  or app.has_role_code('founder',school_id)
  or app.is_super_admin()
);

drop policy if exists boarding_movements_insert_secure on public.boarding_movements;
drop policy if exists boarding_movements_update_secure on public.boarding_movements;
drop policy if exists boarding_movements_delete_secure on public.boarding_movements;
drop policy if exists boarding_movements_select_secure on public.boarding_movements;
create policy boarding_movements_select_secure on public.boarding_movements
for select using (
  app.has_permission('boarding.view',school_id)
  or app.has_permission('boarding.manage',school_id)
  or app.has_role_code('direction',school_id)
  or app.has_role_code('founder',school_id)
  or app.is_super_admin()
);

drop policy if exists boarding_attendance_insert_secure on public.boarding_attendance;
drop policy if exists boarding_attendance_update_secure on public.boarding_attendance;
drop policy if exists boarding_attendance_delete_secure on public.boarding_attendance;
drop policy if exists boarding_attendance_select_secure on public.boarding_attendance;
create policy boarding_attendance_select_secure on public.boarding_attendance
for select using (
  app.has_permission('boarding.view',school_id)
  or app.has_permission('boarding.manage',school_id)
  or app.has_role_code('direction',school_id)
  or app.has_role_code('founder',school_id)
  or app.is_super_admin()
);

revoke insert,update,delete on public.boarding_buildings,public.boarding_dormitories,public.boarding_rooms,public.boarding_beds,
  public.boarding_assignments,public.boarding_movements,public.boarding_attendance from authenticated;

grant select on public.boarding_buildings,public.boarding_dormitories,public.boarding_rooms,public.boarding_beds,
  public.boarding_assignments,public.boarding_movements,public.boarding_attendance to authenticated;

-- =========================================================
-- 07. RPC STRUCTURES
-- =========================================================
create or replace function public.create_boarding_building(
  p_school_id uuid,p_code text,p_name text,p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if not (app.is_super_admin() or app.has_permission('boarding.manage',p_school_id) or app.has_role_code('direction',p_school_id) or app.has_role_code('founder',p_school_id)) then
    raise exception 'BOARDING_FORBIDDEN';
  end if;
  insert into public.boarding_buildings(school_id,code,name,description)
  values(p_school_id,trim(p_code),trim(p_name),nullif(trim(p_description),''))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.create_boarding_dormitory(
  p_building_id uuid,p_name text,p_gender app.gender_type default null,p_supervisor_employee_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid; v_school uuid;
begin
  v_school := app.boarding_building_school_id(p_building_id);
  if v_school is null then raise exception 'BOARDING_BUILDING_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('boarding.manage',v_school) or app.has_role_code('direction',v_school) or app.has_role_code('founder',v_school)) then raise exception 'BOARDING_FORBIDDEN'; end if;
  if p_supervisor_employee_id is not null and not exists(select 1 from public.employees e where e.id=p_supervisor_employee_id and e.school_id=v_school and e.status='active') then raise exception 'BOARDING_SUPERVISOR_INVALID'; end if;
  insert into public.boarding_dormitories(building_id,name,gender,supervisor_employee_id)
  values(p_building_id,trim(p_name),p_gender,p_supervisor_employee_id)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.create_boarding_room(
  p_dormitory_id uuid,p_name text,p_capacity integer,p_floor text default null,p_status text default 'active'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid; v_school uuid;
begin
  v_school := app.boarding_dormitory_school_id(p_dormitory_id);
  if v_school is null then raise exception 'BOARDING_DORMITORY_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('boarding.manage',v_school) or app.has_role_code('direction',v_school) or app.has_role_code('founder',v_school)) then raise exception 'BOARDING_FORBIDDEN'; end if;
  if p_capacity is null or p_capacity<=0 then raise exception 'BOARDING_INVALID_CAPACITY'; end if;
  insert into public.boarding_rooms(dormitory_id,name,capacity,floor,status)
  values(p_dormitory_id,trim(p_name),p_capacity,nullif(trim(p_floor),''),p_status)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.create_boarding_bed(
  p_room_id uuid,p_bed_number text,p_status text default 'available'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid; v_school uuid;
begin
  v_school := app.boarding_room_school_id(p_room_id);
  if v_school is null then raise exception 'BOARDING_ROOM_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('boarding.manage',v_school) or app.has_role_code('direction',v_school) or app.has_role_code('founder',v_school)) then raise exception 'BOARDING_FORBIDDEN'; end if;
  insert into public.boarding_beds(room_id,bed_number,status)
  values(p_room_id,trim(p_bed_number),p_status)
  returning id into v_id;
  return v_id;
end;
$$;

-- =========================================================
-- 08. RPC AFFECTATIONS
-- =========================================================
create or replace function public.assign_boarding_bed(
  p_student_id uuid,p_bed_id uuid,p_start_date date,p_end_date date default null,p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_id uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null then raise exception 'BOARDING_STUDENT_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('boarding.manage',v_school) or app.has_role_code('direction',v_school) or app.has_role_code('founder',v_school)) then raise exception 'BOARDING_FORBIDDEN'; end if;
  insert into public.boarding_assignments(school_id,student_id,bed_id,start_date,end_date,status,assigned_by,notes)
  values(v_school,p_student_id,p_bed_id,p_start_date,p_end_date,'active',auth.uid(),nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.close_boarding_assignment(
  p_assignment_id uuid,p_end_date date,p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid; v_start date; v_status text;
begin
  select school_id,start_date,status into v_school,v_start,v_status
  from public.boarding_assignments where id=p_assignment_id for update;
  if v_school is null then raise exception 'BOARDING_ASSIGNMENT_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('boarding.manage',v_school) or app.has_role_code('direction',v_school) or app.has_role_code('founder',v_school)) then raise exception 'BOARDING_FORBIDDEN'; end if;
  if v_status<>'active' then raise exception 'BOARDING_ASSIGNMENT_NOT_ACTIVE'; end if;
  if p_end_date < v_start then raise exception 'BOARDING_INVALID_END_DATE'; end if;
  update public.boarding_assignments
  set status='completed',end_date=p_end_date,notes=coalesce(nullif(trim(p_notes),''),notes)
  where id=p_assignment_id;
end;
$$;

-- =========================================================
-- 09. RPC MOUVEMENTS / PRÉSENCES
-- =========================================================
create or replace function public.record_boarding_movement(
  p_student_id uuid,p_movement_type text,p_movement_at timestamptz default now(),
  p_authorization text default null,p_destination text default null,p_reason text default null,p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null then raise exception 'BOARDING_STUDENT_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('boarding.manage',v_school) or app.has_role_code('direction',v_school) or app.has_role_code('founder',v_school)) then raise exception 'BOARDING_FORBIDDEN'; end if;
  if p_movement_type not in ('entry','exit','return','temporary_leave') then raise exception 'BOARDING_INVALID_MOVEMENT_TYPE'; end if;
  insert into public.boarding_movements(school_id,student_id,movement_type,movement_at,"authorization",destination,reason,recorded_by,notes)
  values(v_school,p_student_id,p_movement_type,p_movement_at,nullif(trim(p_authorization),''),nullif(trim(p_destination),''),nullif(trim(p_reason),''),auth.uid(),nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.set_boarding_attendance(
  p_student_id uuid,p_attendance_date date,p_status app.attendance_status,p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null then raise exception 'BOARDING_STUDENT_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('boarding.manage',v_school) or app.has_role_code('direction',v_school) or app.has_role_code('founder',v_school)) then raise exception 'BOARDING_FORBIDDEN'; end if;
  insert into public.boarding_attendance(school_id,student_id,attendance_date,status,recorded_by,notes)
  values(v_school,p_student_id,p_attendance_date,p_status,auth.uid(),nullif(trim(p_notes),''))
  on conflict(student_id,attendance_date) do update
    set status=excluded.status,recorded_by=excluded.recorded_by,notes=excluded.notes
  returning id into v_id;
  return v_id;
end;
$$;

-- =========================================================
-- 10. RPC LECTURE TABLEAU DE BORD
-- =========================================================
create or replace function public.get_boarding_dashboard(p_school_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
  v_buildings bigint;
  v_dormitories bigint;
  v_rooms bigint;
  v_beds bigint;
  v_occupied bigint;
  v_available bigint;
  v_active_assignments bigint;
  v_today_attendance bigint;
begin
  if not (app.is_super_admin() or app.has_permission('boarding.view',p_school_id) or app.has_permission('boarding.manage',p_school_id) or app.has_role_code('direction',p_school_id) or app.has_role_code('founder',p_school_id)) then
    raise exception 'BOARDING_FORBIDDEN';
  end if;

  select count(*) into v_buildings from public.boarding_buildings where school_id=p_school_id;
  select count(*) into v_dormitories
    from public.boarding_dormitories d join public.boarding_buildings b on b.id=d.building_id where b.school_id=p_school_id;
  select count(*) into v_rooms
    from public.boarding_rooms r join public.boarding_dormitories d on d.id=r.dormitory_id join public.boarding_buildings b on b.id=d.building_id where b.school_id=p_school_id;
  select count(*) into v_beds
    from public.boarding_beds bed join public.boarding_rooms r on r.id=bed.room_id join public.boarding_dormitories d on d.id=r.dormitory_id join public.boarding_buildings b on b.id=d.building_id where b.school_id=p_school_id;
  select count(*) into v_occupied from public.boarding_beds bed join public.boarding_rooms r on r.id=bed.room_id join public.boarding_dormitories d on d.id=r.dormitory_id join public.boarding_buildings b on b.id=d.building_id where b.school_id=p_school_id and bed.status='occupied';
  select count(*) into v_available from public.boarding_beds bed join public.boarding_rooms r on r.id=bed.room_id join public.boarding_dormitories d on d.id=r.dormitory_id join public.boarding_buildings b on b.id=d.building_id where b.school_id=p_school_id and bed.status='available';
  select count(*) into v_active_assignments from public.boarding_assignments where school_id=p_school_id and status='active';
  select count(*) into v_today_attendance from public.boarding_attendance where school_id=p_school_id and attendance_date=current_date;

  result := jsonb_build_object(
    'buildings',v_buildings,'dormitories',v_dormitories,'rooms',v_rooms,'beds',v_beds,
    'occupied_beds',v_occupied,'available_beds',v_available,
    'active_assignments',v_active_assignments,'today_attendance',v_today_attendance
  );
  return result;
end;
$$;

create or replace function public.get_student_boarding(p_student_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public, app
as $$
select jsonb_build_object(
  'active_assignment',coalesce((
    select jsonb_build_object(
      'id',a.id,'start_date',a.start_date,'end_date',a.end_date,'status',a.status,'notes',a.notes,
      'bed_number',bed.bed_number,'room_name',r.name,'floor',r.floor,
      'dormitory_name',d.name,'building_name',b.name,'building_code',b.code
    )
    from public.boarding_assignments a
    join public.boarding_beds bed on bed.id=a.bed_id
    join public.boarding_rooms r on r.id=bed.room_id
    join public.boarding_dormitories d on d.id=r.dormitory_id
    join public.boarding_buildings b on b.id=d.building_id
    where a.student_id=p_student_id and a.status='active' and a.end_date is null
    order by a.start_date desc limit 1
  ),'{}'::jsonb),
  'movements',coalesce((
    select jsonb_agg(jsonb_build_object('id',m.id,'movement_type',m.movement_type,'movement_at',m.movement_at,'authorization',m."authorization",'destination',m.destination,'reason',m.reason,'notes',m.notes) order by m.movement_at desc)
    from public.boarding_movements m where m.student_id=p_student_id
  ),'[]'::jsonb),
  'attendance',coalesce((
    select jsonb_agg(jsonb_build_object('id',ba.id,'attendance_date',ba.attendance_date,'status',ba.status,'notes',ba.notes) order by ba.attendance_date desc)
    from public.boarding_attendance ba where ba.student_id=p_student_id
  ),'[]'::jsonb)
);
$$;

-- Sécurité des fonctions.
revoke all on function public.create_boarding_building(uuid,text,text,text) from public;
revoke all on function public.create_boarding_dormitory(uuid,text,app.gender_type,uuid) from public;
revoke all on function public.create_boarding_room(uuid,text,integer,text,text) from public;
revoke all on function public.create_boarding_bed(uuid,text,text) from public;
revoke all on function public.assign_boarding_bed(uuid,uuid,date,date,text) from public;
revoke all on function public.close_boarding_assignment(uuid,date,text) from public;
revoke all on function public.record_boarding_movement(uuid,text,timestamptz,text,text,text,text) from public;
revoke all on function public.set_boarding_attendance(uuid,date,app.attendance_status,text) from public;
revoke all on function public.get_boarding_dashboard(uuid) from public;
revoke all on function public.get_student_boarding(uuid) from public;

grant execute on function public.create_boarding_building(uuid,text,text,text) to authenticated;
grant execute on function public.create_boarding_dormitory(uuid,text,app.gender_type,uuid) to authenticated;
grant execute on function public.create_boarding_room(uuid,text,integer,text,text) to authenticated;
grant execute on function public.create_boarding_bed(uuid,text,text) to authenticated;
grant execute on function public.assign_boarding_bed(uuid,uuid,date,date,text) to authenticated;
grant execute on function public.close_boarding_assignment(uuid,date,text) to authenticated;
grant execute on function public.record_boarding_movement(uuid,text,timestamptz,text,text,text,text) to authenticated;
grant execute on function public.set_boarding_attendance(uuid,date,app.attendance_status,text) to authenticated;
grant execute on function public.get_boarding_dashboard(uuid) to authenticated;
grant execute on function public.get_student_boarding(uuid) to authenticated;

comment on table public.boarding_assignments is 'Affectation d’un élève interne à un lit. Les mutations métier passent par les RPC de l’étape 16.';
comment on table public.boarding_movements is 'Entrées, sorties temporaires et retours de l’internat. Les validations métier sont centralisées.';
comment on table public.boarding_attendance is 'Présence quotidienne des élèves internes.';
comment on function public.get_boarding_dashboard(uuid) is 'Tableau de bord sécurisé du module Internat.';
comment on function public.get_student_boarding(uuid) is 'Vue sécurisée du sous-dossier internat d’un élève.';

commit;
