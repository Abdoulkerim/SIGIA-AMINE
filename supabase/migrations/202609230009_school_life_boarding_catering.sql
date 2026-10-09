-- SIGIA-AMINE
-- Migration 009: school_life_boarding_catering
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Attendance, discipline, boarding and catering.

-- 10. VIE SCOLAIRE
-- =========================================================
create table if not exists public.attendance_sessions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  class_id uuid references public.classes(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  session_date date not null,
  start_time time,
  end_time time,
  activity_type text not null default 'class',
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_records(
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.attendance_sessions(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status app.attendance_status not null,
  arrival_time time,
  departure_time time,
  reason text,
  recorded_by uuid references public.users(id) on delete set null,
  recorded_at timestamptz not null default now(),
  unique(session_id,student_id)
);

create table if not exists public.absence_justifications(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  attendance_record_id uuid references public.attendance_records(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  reason text not null,
  document_id uuid references public.documents(id) on delete set null,
  status text not null default 'pending',
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  check(end_date>=start_date)
);

create table if not exists public.discipline_categories(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  severity integer not null default 1 check(severity between 1 and 5),
  unique(school_id,code)
);

create table if not exists public.discipline_events(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  category_id uuid references public.discipline_categories(id) on delete set null,
  event_date date not null default current_date,
  event_time time,
  event_type text not null,
  description text not null,
  action_taken text,
  responsible_employee_id uuid references public.employees(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.student_followups(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  followup_date date not null default current_date,
  category text not null,
  observation text not null,
  action_plan text,
  next_review_date date,
  responsible_employee_id uuid references public.employees(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.student_rewards(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  reward_date date not null default current_date,
  title text not null,
  description text,
  given_by uuid references public.users(id) on delete set null
);

-- =========================================================

-- 11. INTERNAT
-- =========================================================
create table if not exists public.boarding_buildings(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  unique(school_id,code)
);

create table if not exists public.boarding_dormitories(
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.boarding_buildings(id) on delete cascade,
  name text not null,
  gender app.gender_type,
  supervisor_employee_id uuid references public.employees(id) on delete set null
);

create table if not exists public.boarding_rooms(
  id uuid primary key default gen_random_uuid(),
  dormitory_id uuid not null references public.boarding_dormitories(id) on delete cascade,
  name text not null,
  capacity integer not null check(capacity>0),
  floor text,
  status text not null default 'active'
);

create table if not exists public.boarding_beds(
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.boarding_rooms(id) on delete cascade,
  bed_number text not null,
  status text not null default 'available',
  unique(room_id,bed_number)
);

create table if not exists public.boarding_assignments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  bed_id uuid not null references public.boarding_beds(id) on delete restrict,
  start_date date not null,
  end_date date,
  status text not null default 'active',
  assigned_by uuid references public.users(id) on delete set null,
  notes text,
  check(end_date is null or end_date>=start_date)
);

create table if not exists public.boarding_movements(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  movement_type text not null check(movement_type in ('entry','exit','return','temporary_leave')),
  movement_at timestamptz not null default now(),
  "authorization" text,
  destination text,
  reason text,
  recorded_by uuid references public.users(id) on delete set null,
  notes text
);

create table if not exists public.boarding_attendance(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  attendance_date date not null,
  status app.attendance_status not null,
  recorded_by uuid references public.users(id) on delete set null,
  notes text,
  unique(student_id,attendance_date)
);

-- =========================================================

-- 12. RESTAURATION
-- =========================================================
create table if not exists public.meal_types(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  unique(school_id,code)
);

create table if not exists public.menus(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  menu_date date not null,
  notes text,
  created_by uuid references public.users(id) on delete set null,
  unique(school_id,menu_date)
);

create table if not exists public.menu_items(
  id uuid primary key default gen_random_uuid(),
  menu_id uuid not null references public.menus(id) on delete cascade,
  meal_type_id uuid not null references public.meal_types(id) on delete restrict,
  description text not null,
  estimated_cost numeric(14,2) not null default 0
);

create table if not exists public.meal_service_records(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  served_quantity numeric(12,2) not null default 0,
  unit text,
  actual_cost numeric(14,2) not null default 0,
  notes text
);

create table if not exists public.meal_attendance(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  meal_type_id uuid not null references public.meal_types(id) on delete restrict,
  meal_date date not null,
  served boolean not null default true,
  quantity numeric(8,2) not null default 1,
  unique(student_id,meal_type_id,meal_date)
);

-- =========================================================

commit;
