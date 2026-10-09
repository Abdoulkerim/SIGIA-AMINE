-- SIGIA-AMINE | Migration initiale Supabase / PostgreSQL
-- Version 1.0
-- Base fonctionnelle : cahier des charges "LOGICIEL DE GESTION AL AMINE"
-- Architecture : multi-site, PostgreSQL, Supabase Auth, RLS, audit, modules découplés.
-- IMPORTANT : exécuter dans un projet Supabase neuf ou après sauvegarde.
begin;

create extension if not exists pgcrypto;

create schema if not exists app;

-- =========================================================
-- 1. TYPES
-- =========================================================
do $$ begin create type app.user_status as enum ('active','inactive','suspended'); exception when duplicate_object then null; end $$;
do $$ begin create type app.gender_type as enum ('male','female','other'); exception when duplicate_object then null; end $$;
do $$ begin create type app.student_status as enum ('prospect','active','transferred','graduated','withdrawn','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type app.enrollment_status as enum ('pending','approved','rejected','enrolled','cancelled','completed'); exception when duplicate_object then null; end $$;
do $$ begin create type app.residence_type as enum ('internal','external','other'); exception when duplicate_object then null; end $$;
do $$ begin create type app.attendance_status as enum ('present','absent','late','excused'); exception when duplicate_object then null; end $$;
do $$ begin create type app.document_status as enum ('draft','active','archived','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type app.payment_status as enum ('pending','paid','partially_paid','cancelled','refunded'); exception when duplicate_object then null; end $$;
do $$ begin create type app.payment_method as enum ('cash','bank_transfer','mobile_money','card','cheque','other'); exception when duplicate_object then null; end $$;
do $$ begin create type app.transaction_type as enum ('income','expense','transfer','adjustment'); exception when duplicate_object then null; end $$;
do $$ begin create type app.approval_status as enum ('draft','submitted','approved','rejected','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type app.stock_movement_type as enum ('purchase','sale','issue','return','adjustment','loss','transfer','production_in','production_out'); exception when duplicate_object then null; end $$;
do $$ begin create type app.relationship_type as enum ('father','mother','guardian','tutor','other'); exception when duplicate_object then null; end $$;

-- =========================================================
-- 2. FONCTIONS DE SÉCURITÉ
-- =========================================================
create or replace function app.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create or replace function app.my_school_ids()
returns setof uuid
language sql stable security definer set search_path=public,app
as $$
  select ur.school_id from public.user_roles ur
  where ur.user_id=auth.uid() and ur.is_active=true and ur.school_id is not null
  union
  select u.school_id from public.users u
  where u.id=auth.uid() and u.school_id is not null
$$;

create or replace function app.is_super_admin()
returns boolean language sql stable security definer set search_path=public,app
as $$
  select exists(
    select 1 from public.user_roles ur
    join public.roles r on r.id=ur.role_id
    where ur.user_id=auth.uid() and ur.is_active=true and r.code='super_admin'
  )
$$;

create or replace function app.has_permission(p_code text,p_school_id uuid default null)
returns boolean language sql stable security definer set search_path=public,app
as $$
  select app.is_super_admin() or exists(
    select 1
    from public.user_roles ur
    join public.role_permissions rp on rp.role_id=ur.role_id
    join public.permissions p on p.id=rp.permission_id
    where ur.user_id=auth.uid()
      and ur.is_active=true
      and p.code=p_code
      and (p_school_id is null or ur.school_id=p_school_id)
  )
$$;

-- =========================================================
-- 3. ORGANISATION
-- =========================================================
create table if not exists public.schools(
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  short_name text,
  legal_name text,
  address text,
  city text,
  country text not null default 'Burkina Faso',
  phone text,
  email text,
  website text,
  logo_url text,
  timezone text not null default 'Africa/Ouagadougou',
  currency_code char(3) not null default 'XOF',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.school_settings(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null unique references public.schools(id) on delete cascade,
  default_language text not null default 'fr',
  grading_scale numeric(6,2) not null default 20,
  passing_score numeric(6,2) not null default 10,
  late_tolerance_minutes integer not null default 15 check(late_tolerance_minutes>=0),
  receipt_prefix text not null default 'REC',
  invoice_prefix text not null default 'FAC',
  student_prefix text not null default 'ELV',
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.school_years(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,name),
  check(end_date>=start_date)
);

create table if not exists public.academic_periods(
  id uuid primary key default gen_random_uuid(),
  school_year_id uuid not null references public.school_years(id) on delete cascade,
  name text not null,
  code text not null,
  start_date date not null,
  end_date date not null,
  sequence_no integer not null,
  is_closed boolean not null default false,
  unique(school_year_id,code),
  unique(school_year_id,sequence_no),
  check(end_date>=start_date)
);

-- =========================================================
-- 4. UTILISATEURS / RÔLES
-- =========================================================
create table if not exists public.users(
  id uuid primary key references auth.users(id) on delete cascade,
  school_id uuid references public.schools(id) on delete set null,
  first_name text not null,
  last_name text not null,
  email text,
  phone text,
  avatar_url text,
  status app.user_status not null default 'active',
  last_login timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.roles(
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  description text,
  is_system boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.permissions(
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  module text not null,
  action text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions(
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  primary key(role_id,permission_id)
);

create table if not exists public.user_roles(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  school_id uuid references public.schools(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(user_id,role_id,school_id)
);

-- =========================================================
-- 5. RÉFÉRENTIEL ACADÉMIQUE
-- =========================================================
create table if not exists public.levels(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  education_cycle text,
  sequence_no integer,
  is_active boolean not null default true,
  unique(school_id,code)
);

create table if not exists public.classes(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  level_id uuid references public.levels(id) on delete restrict,
  name text not null,
  code text not null,
  section text,
  room_name text,
  capacity integer check(capacity is null or capacity>0),
  homeroom_teacher_id uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,school_year_id,code)
);

create table if not exists public.subjects(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  domain text not null default 'general',
  coefficient numeric(8,2) not null default 1 check(coefficient>0),
  weekly_hours numeric(6,2),
  description text,
  is_active boolean not null default true,
  unique(school_id,code)
);

create table if not exists public.programs(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  level_id uuid references public.levels(id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  title text not null,
  objectives text,
  content jsonb not null default '{}'::jsonb,
  progress_percent numeric(5,2) not null default 0 check(progress_percent between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- 6. PERSONNEL / ENSEIGNANTS
-- =========================================================
create table if not exists public.employees(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  employee_number text not null,
  first_name text not null,
  last_name text not null,
  gender app.gender_type,
  date_of_birth date,
  place_of_birth text,
  phone text,
  email text,
  address text,
  job_title text,
  department text,
  qualification text,
  hire_date date,
  status text not null default 'active',
  emergency_contact jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,employee_number)
);

create table if not exists public.teacher_profiles(
  employee_id uuid primary key references public.employees(id) on delete cascade,
  speciality text,
  diploma text,
  pedagogical_role text,
  biography text
);

alter table public.classes
  add constraint classes_homeroom_teacher_fk
  foreign key(homeroom_teacher_id) references public.employees(id) on delete set null;

create table if not exists public.teacher_assignments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  teacher_id uuid not null references public.employees(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  weekly_hours numeric(6,2),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique(school_year_id,teacher_id,class_id,subject_id)
);

-- =========================================================
-- 7. ÉLÈVES / PARENTS / INSCRIPTIONS
-- =========================================================
create table if not exists public.students(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_number text not null,
  first_name text not null,
  last_name text not null,
  gender app.gender_type,
  date_of_birth date,
  place_of_birth text,
  nationality text,
  address text,
  phone text,
  email text,
  photo_url text,
  blood_group text,
  residence_type app.residence_type not null default 'external',
  status app.student_status not null default 'prospect',
  emergency_contact jsonb not null default '{}'::jsonb,
  medical_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,student_number)
);

create table if not exists public.parents(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  gender app.gender_type,
  profession text,
  phone text,
  email text,
  address text,
  preferred_contact_method text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_parents(
  student_id uuid not null references public.students(id) on delete cascade,
  parent_id uuid not null references public.parents(id) on delete cascade,
  relationship app.relationship_type not null,
  is_primary boolean not null default false,
  has_financial_responsibility boolean not null default false,
  receives_notifications boolean not null default true,
  primary key(student_id,parent_id)
);

create table if not exists public.authorized_pickup_persons(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  full_name text not null,
  relationship text,
  phone text,
  identity_document text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.admission_applications(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  application_number text not null,
  student_id uuid references public.students(id) on delete set null,
  applicant_name text not null,
  applicant_phone text,
  desired_level_id uuid references public.levels(id) on delete set null,
  desired_year_id uuid references public.school_years(id) on delete set null,
  desired_residence_type app.residence_type,
  status app.enrollment_status not null default 'pending',
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references public.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  unique(school_id,application_number)
);

create table if not exists public.enrollments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete restrict,
  residence_type app.residence_type not null default 'external',
  enrollment_date date not null default current_date,
  status app.enrollment_status not null default 'enrolled',
  is_reenrollment boolean not null default false,
  registration_fee numeric(14,2) not null default 0 check(registration_fee>=0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(student_id,school_year_id)
);

create table if not exists public.enrollment_history(
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  old_class_id uuid references public.classes(id) on delete set null,
  new_class_id uuid references public.classes(id) on delete set null,
  old_residence_type app.residence_type,
  new_residence_type app.residence_type,
  reason text,
  changed_by uuid references public.users(id) on delete set null,
  changed_at timestamptz not null default now()
);

-- =========================================================
-- 8. DOCUMENTS
-- =========================================================
create table if not exists public.document_types(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  module text,
  is_active boolean not null default true,
  unique(school_id,code)
);

create table if not exists public.documents(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  document_type_id uuid references public.document_types(id) on delete set null,
  student_id uuid references public.students(id) on delete cascade,
  parent_id uuid references public.parents(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  reference text,
  title text not null,
  file_path text,
  file_name text,
  mime_type text,
  file_size bigint,
  status app.document_status not null default 'active',
  issued_at date,
  expires_at date,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  archived_at timestamptz
);

-- =========================================================
-- 9. EMPLOI DU TEMPS / PÉDAGOGIE
-- =========================================================
create table if not exists public.timetable_slots(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  teacher_id uuid not null references public.employees(id) on delete restrict,
  room_name text,
  day_of_week integer not null check(day_of_week between 1 and 7),
  start_time time not null,
  end_time time not null,
  valid_from date,
  valid_to date,
  is_active boolean not null default true,
  check(end_time>start_time)
);

create table if not exists public.assessment_types(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  default_coefficient numeric(8,2) not null default 1 check(default_coefficient>0),
  unique(school_id,code)
);

create table if not exists public.assessments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  period_id uuid not null references public.academic_periods(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  teacher_id uuid references public.employees(id) on delete set null,
  assessment_type_id uuid references public.assessment_types(id) on delete set null,
  title text not null,
  assessment_date date not null,
  max_score numeric(8,2) not null default 20 check(max_score>0),
  coefficient numeric(8,2) not null default 1 check(coefficient>0),
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.grades(
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  score numeric(8,2) not null check(score>=0),
  normalized_score numeric(8,2),
  coefficient numeric(8,2) not null default 1 check(coefficient>0),
  observation text,
  entered_by uuid references public.users(id) on delete set null,
  entered_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(assessment_id,student_id)
);

create table if not exists public.grade_audit(
  id uuid primary key default gen_random_uuid(),
  grade_id uuid not null references public.grades(id) on delete cascade,
  old_score numeric(8,2),
  new_score numeric(8,2),
  changed_by uuid references public.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  reason text
);

create table if not exists public.report_cards(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  period_id uuid not null references public.academic_periods(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete restrict,
  general_average numeric(8,2),
  rank integer,
  attendance_summary jsonb not null default '{}'::jsonb,
  overall_observation text,
  decision text,
  status text not null default 'draft',
  generated_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(student_id,period_id)
);

create table if not exists public.report_card_items(
  id uuid primary key default gen_random_uuid(),
  report_card_id uuid not null references public.report_cards(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  average numeric(8,2),
  coefficient numeric(8,2) not null default 1,
  rank integer,
  teacher_comment text,
  unique(report_card_id,subject_id)
);

-- =========================================================
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
  authorization text,
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
-- 13. TAHFIZ / FORMATION ISLAMIQUE
-- =========================================================
create table if not exists public.tahfiz_levels(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  sequence_no integer,
  unique(school_id,code)
);

create table if not exists public.quran_surahs(
  id smallint primary key,
  name_ar text not null,
  name_fr text,
  surah_number smallint not null unique check(surah_number between 1 and 114),
  verse_count smallint
);

create table if not exists public.student_tahfiz(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade unique,
  tahfiz_level_id uuid references public.tahfiz_levels(id) on delete set null,
  assigned_teacher_id uuid references public.employees(id) on delete set null,
  start_date date,
  current_progress numeric(6,2) not null default 0 check(current_progress between 0 and 100),
  notes text
);

create table if not exists public.tahfiz_sessions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  session_date date not null,
  session_type text not null check(session_type in ('new_memorization','revision','recitation','evaluation')),
  surah_id smallint references public.quran_surahs(id) on delete set null,
  from_verse smallint,
  to_verse smallint,
  score numeric(8,2),
  observation text,
  teacher_id uuid references public.employees(id) on delete set null
);

create table if not exists public.islamic_training(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  period_id uuid references public.academic_periods(id) on delete set null,
  domain text not null,
  topic text not null,
  score numeric(8,2),
  observation text,
  teacher_id uuid references public.employees(id) on delete set null
);

-- =========================================================
-- 14. WUSHU
-- =========================================================
create table if not exists public.wushu_groups(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  level text,
  coach_employee_id uuid references public.employees(id) on delete set null,
  schedule jsonb not null default '{}'::jsonb
);

create table if not exists public.student_wushu(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade unique,
  group_id uuid references public.wushu_groups(id) on delete set null,
  current_grade text,
  start_date date,
  status text not null default 'active'
);

create table if not exists public.wushu_sessions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  group_id uuid references public.wushu_groups(id) on delete set null,
  session_date date not null,
  topic text,
  coach_employee_id uuid references public.employees(id) on delete set null,
  notes text
);

create table if not exists public.wushu_attendance(
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.wushu_sessions(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status app.attendance_status not null,
  unique(session_id,student_id)
);

create table if not exists public.wushu_evaluations(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  evaluation_date date not null,
  evaluation_type text not null,
  score numeric(8,2),
  grade_awarded text,
  observation text,
  evaluator_id uuid references public.employees(id) on delete set null
);

create table if not exists public.wushu_competitions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  competition_date date not null,
  location text,
  notes text
);

create table if not exists public.wushu_competition_results(
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.wushu_competitions(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  category text,
  result text,
  rank integer
);

-- =========================================================
-- 15. FINANCE / COMPTABILITÉ
-- =========================================================
create table if not exists public.fee_types(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  category text not null,
  description text,
  is_active boolean not null default true,
  unique(school_id,code)
);

create table if not exists public.fee_schedules(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  level_id uuid references public.levels(id) on delete set null,
  residence_type app.residence_type,
  fee_type_id uuid not null references public.fee_types(id) on delete restrict,
  amount numeric(14,2) not null check(amount>=0),
  due_date date,
  installment_no integer not null default 1,
  unique(school_year_id,level_id,residence_type,fee_type_id,installment_no)
);

create table if not exists public.student_charges(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  fee_type_id uuid not null references public.fee_types(id) on delete restrict,
  description text,
  amount_due numeric(14,2) not null check(amount_due>=0),
  due_date date,
  status app.payment_status not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists public.invoices(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  invoice_number text not null,
  student_id uuid references public.students(id) on delete set null,
  parent_id uuid references public.parents(id) on delete set null,
  issue_date date not null default current_date,
  due_date date,
  subtotal numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  status app.payment_status not null default 'pending',
  notes text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,invoice_number)
);

create table if not exists public.invoice_items(
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  fee_type_id uuid references public.fee_types(id) on delete set null,
  description text not null,
  quantity numeric(12,2) not null default 1 check(quantity>0),
  unit_amount numeric(14,2) not null check(unit_amount>=0),
  discount numeric(14,2) not null default 0 check(discount>=0),
  line_total numeric(14,2) generated always as ((quantity*unit_amount)-discount) stored
);

create table if not exists public.payments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  payment_number text not null,
  payer_parent_id uuid references public.parents(id) on delete set null,
  student_id uuid references public.students(id) on delete set null,
  amount numeric(14,2) not null check(amount>0),
  payment_date timestamptz not null default now(),
  method app.payment_method not null,
  reference text,
  status app.payment_status not null default 'paid',
  received_by uuid references public.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  unique(school_id,payment_number)
);

create table if not exists public.payment_allocations(
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  student_charge_id uuid references public.student_charges(id) on delete set null,
  amount numeric(14,2) not null check(amount>0)
);

create table if not exists public.receipts(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  payment_id uuid not null unique references public.payments(id) on delete cascade,
  receipt_number text not null,
  issued_at timestamptz not null default now(),
  file_path text,
  unique(school_id,receipt_number)
);

create table if not exists public.expense_categories(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  unique(school_id,code)
);

create table if not exists public.suppliers(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  contact_name text,
  phone text,
  email text,
  address text,
  tax_id text,
  unique(school_id,code)
);

create table if not exists public.expenses(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  expense_number text not null,
  category_id uuid references public.expense_categories(id) on delete set null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  amount numeric(14,2) not null check(amount>=0),
  expense_date date not null default current_date,
  description text not null,
  payment_method app.payment_method,
  approval_status app.approval_status not null default 'draft',
  approved_by uuid references public.users(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(school_id,expense_number)
);

create table if not exists public.cash_accounts(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  account_type text not null default 'cash',
  opening_balance numeric(14,2) not null default 0,
  is_active boolean not null default true,
  unique(school_id,code)
);

create table if not exists public.cash_transactions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts(id) on delete restrict,
  transaction_type app.transaction_type not null,
  amount numeric(14,2) not null check(amount>=0),
  transaction_date timestamptz not null default now(),
  reference_type text,
  reference_id uuid,
  description text not null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.cash_closings(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts(id) on delete restrict,
  closing_date date not null,
  expected_balance numeric(14,2) not null,
  actual_balance numeric(14,2) not null,
  difference numeric(14,2) generated always as (actual_balance-expected_balance) stored,
  closed_by uuid references public.users(id) on delete set null,
  notes text,
  unique(cash_account_id,closing_date)
);

create table if not exists public.collection_reminders(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid references public.students(id) on delete cascade,
  parent_id uuid references public.parents(id) on delete set null,
  amount_due numeric(14,2) not null,
  reminder_date date not null default current_date,
  channel text,
  message text,
  status text not null default 'pending',
  sent_at timestamptz,
  created_by uuid references public.users(id) on delete set null
);

-- =========================================================
-- 16. STOCKS / ACHATS
-- =========================================================
create table if not exists public.stock_categories(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  unique(school_id,code)
);

create table if not exists public.stock_locations(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  location_type text,
  unique(school_id,name)
);

create table if not exists public.products(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  sku text not null,
  name text not null,
  category_id uuid references public.stock_categories(id) on delete set null,
  unit text not null,
  minimum_stock numeric(14,3) not null default 0,
  maximum_stock numeric(14,3),
  unit_cost numeric(14,2) not null default 0,
  is_active boolean not null default true,
  unique(school_id,sku)
);

create table if not exists public.stock_balances(
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  location_id uuid not null references public.stock_locations(id) on delete cascade,
  quantity numeric(14,3) not null default 0,
  updated_at timestamptz not null default now(),
  unique(product_id,location_id)
);

create table if not exists public.stock_movements(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  location_id uuid not null references public.stock_locations(id) on delete restrict,
  movement_type app.stock_movement_type not null,
  quantity numeric(14,3) not null check(quantity>0),
  unit_cost numeric(14,2),
  reference_type text,
  reference_id uuid,
  movement_date timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  notes text
);

create table if not exists public.purchase_orders(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  order_number text not null,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  order_date date not null default current_date,
  expected_date date,
  status app.approval_status not null default 'draft',
  subtotal numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  created_by uuid references public.users(id) on delete set null,
  unique(school_id,order_number)
);

create table if not exists public.purchase_items(
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  unit_cost numeric(14,2) not null check(unit_cost>=0),
  received_quantity numeric(14,3) not null default 0,
  line_total numeric(14,2) generated always as (quantity*unit_cost) stored
);

create table if not exists public.stock_inventories(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  location_id uuid not null references public.stock_locations(id) on delete restrict,
  inventory_date date not null,
  status text not null default 'draft',
  performed_by uuid references public.users(id) on delete set null,
  notes text,
  unique(location_id,inventory_date)
);

create table if not exists public.stock_inventory_items(
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.stock_inventories(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  system_quantity numeric(14,3) not null,
  counted_quantity numeric(14,3) not null,
  difference numeric(14,3) generated always as (counted_quantity-system_quantity) stored,
  unique(inventory_id,product_id)
);

-- =========================================================
-- 17. AGRICULTURE / ÉLEVAGE / AGR
-- =========================================================
create table if not exists public.economic_activities(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  activity_type text not null,
  responsible_employee_id uuid references public.employees(id) on delete set null,
  location text,
  status text not null default 'active',
  unique(school_id,code)
);

create table if not exists public.agriculture_campaigns(
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  crop text not null,
  start_date date,
  end_date date,
  area numeric(14,3),
  area_unit text,
  expected_yield numeric(14,3),
  actual_yield numeric(14,3),
  notes text
);

create table if not exists public.agriculture_expenses(
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.agriculture_campaigns(id) on delete cascade,
  expense_date date not null default current_date,
  category text not null,
  amount numeric(14,2) not null check(amount>=0),
  description text
);

create table if not exists public.livestock(
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  animal_type text not null,
  tag_number text,
  acquisition_date date,
  acquisition_cost numeric(14,2) default 0,
  status text not null default 'active',
  sex text,
  birth_date date,
  notes text,
  unique(activity_id,tag_number)
);

create table if not exists public.livestock_events(
  id uuid primary key default gen_random_uuid(),
  livestock_id uuid not null references public.livestock(id) on delete cascade,
  event_date date not null default current_date,
  event_type text not null,
  quantity numeric(14,3),
  amount numeric(14,2),
  description text
);

create table if not exists public.productions(
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  production_date date not null default current_date,
  product_name text not null,
  quantity numeric(14,3) not null check(quantity>=0),
  unit text not null,
  unit_cost numeric(14,2) default 0,
  notes text
);

create table if not exists public.sales(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  activity_id uuid references public.economic_activities(id) on delete set null,
  sale_number text not null,
  sale_date date not null default current_date,
  customer_name text,
  amount numeric(14,2) not null check(amount>=0),
  payment_method app.payment_method,
  description text,
  unique(school_id,sale_number)
);

-- =========================================================
-- 18. RESSOURCES HUMAINES
-- =========================================================
create table if not exists public.employee_contracts(
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  contract_type text not null,
  start_date date not null,
  end_date date,
  salary numeric(14,2),
  status text not null default 'active',
  document_id uuid references public.documents(id) on delete set null,
  check(end_date is null or end_date>=start_date)
);

create table if not exists public.employee_attendance(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  attendance_date date not null,
  status app.attendance_status not null,
  check_in time,
  check_out time,
  notes text,
  unique(employee_id,attendance_date)
);

create table if not exists public.employee_leaves(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  leave_type text not null,
  start_date date not null,
  end_date date not null,
  reason text,
  status app.approval_status not null default 'draft',
  approved_by uuid references public.users(id) on delete set null,
  check(end_date>=start_date)
);

create table if not exists public.payroll_periods(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  period_label text not null,
  start_date date not null,
  end_date date not null,
  status text not null default 'draft',
  unique(school_id,period_label)
);

create table if not exists public.payroll_items(
  id uuid primary key default gen_random_uuid(),
  payroll_period_id uuid not null references public.payroll_periods(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  base_salary numeric(14,2) not null default 0,
  allowances numeric(14,2) not null default 0,
  deductions numeric(14,2) not null default 0,
  net_salary numeric(14,2) generated always as ((base_salary+allowances)-deductions) stored,
  payment_status app.payment_status not null default 'pending',
  unique(payroll_period_id,employee_id)
);

-- =========================================================
-- 19. COMMUNICATION / IA / AUDIT
-- =========================================================
create table if not exists public.announcements(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  content text not null,
  audience jsonb not null default '[]'::jsonb,
  published_at timestamptz,
  expires_at timestamptz,
  created_by uuid references public.users(id) on delete set null,
  status text not null default 'draft',
  created_at timestamptz not null default now()
);

create table if not exists public.notifications(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  recipient_user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  notification_type text,
  related_table text,
  related_id uuid,
  read_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_preferences(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  whatsapp_enabled boolean not null default false,
  push_enabled boolean not null default true,
  preferences jsonb not null default '{}'::jsonb
);

create table if not exists public.ai_conversations(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  title text,
  scope jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_messages(
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check(role in ('system','user','assistant','tool')),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_alerts(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  alert_type text not null,
  severity integer not null default 1 check(severity between 1 and 5),
  title text not null,
  description text not null,
  related_table text,
  related_id uuid,
  status text not null default 'open',
  generated_at timestamptz not null default now(),
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz
);

create table if not exists public.audit_logs(
  id bigint generated always as identity primary key,
  school_id uuid references public.schools(id) on delete set null,
  actor_user_id uuid references public.users(id) on delete set null,
  action text not null,
  table_name text,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

-- =========================================================
-- 20. INDEXES
-- =========================================================
create index if not exists idx_users_school on public.users(school_id);
create index if not exists idx_user_roles_user_school on public.user_roles(user_id,school_id);
create index if not exists idx_school_year_current on public.school_years(school_id,is_current);
create index if not exists idx_students_school_name on public.students(school_id,last_name,first_name);
create index if not exists idx_students_status on public.students(school_id,status);
create index if not exists idx_enrollments_student_year on public.enrollments(student_id,school_year_id);
create index if not exists idx_enrollments_class on public.enrollments(class_id);
create index if not exists idx_student_parents_parent on public.student_parents(parent_id);
create index if not exists idx_employees_school_name on public.employees(school_id,last_name,first_name);
create index if not exists idx_teacher_assignments_teacher on public.teacher_assignments(teacher_id);
create index if not exists idx_teacher_assignments_class on public.teacher_assignments(class_id);
create index if not exists idx_assessments_class_period on public.assessments(class_id,period_id);
create index if not exists idx_grades_student on public.grades(student_id);
create index if not exists idx_report_cards_student_period on public.report_cards(student_id,period_id);
create index if not exists idx_attendance_date on public.attendance_sessions(school_id,session_date);
create index if not exists idx_attendance_student on public.attendance_records(student_id);
create index if not exists idx_discipline_student_date on public.discipline_events(student_id,event_date);
create index if not exists idx_boarding_student on public.boarding_assignments(student_id);
create index if not exists idx_payments_student_date on public.payments(student_id,payment_date);
create index if not exists idx_invoices_student_status on public.invoices(student_id,status);
create index if not exists idx_cash_account_date on public.cash_transactions(cash_account_id,transaction_date);
create index if not exists idx_stock_product_location on public.stock_movements(product_id,location_id,movement_date);
create index if not exists idx_notifications_user on public.notifications(recipient_user_id,read_at);
create index if not exists idx_audit_school_date on public.audit_logs(school_id,created_at desc);

-- =========================================================
-- 21. TRIGGERS MÉTIER
-- =========================================================
drop trigger if exists trg_schools_updated_at on public.schools;
create trigger trg_schools_updated_at before update on public.schools for each row execute function app.set_updated_at();
drop trigger if exists trg_settings_updated_at on public.school_settings;
create trigger trg_settings_updated_at before update on public.school_settings for each row execute function app.set_updated_at();
drop trigger if exists trg_years_updated_at on public.school_years;
create trigger trg_years_updated_at before update on public.school_years for each row execute function app.set_updated_at();
drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users for each row execute function app.set_updated_at();
drop trigger if exists trg_classes_updated_at on public.classes;
create trigger trg_classes_updated_at before update on public.classes for each row execute function app.set_updated_at();
drop trigger if exists trg_programs_updated_at on public.programs;
create trigger trg_programs_updated_at before update on public.programs for each row execute function app.set_updated_at();
drop trigger if exists trg_employees_updated_at on public.employees;
create trigger trg_employees_updated_at before update on public.employees for each row execute function app.set_updated_at();
drop trigger if exists trg_students_updated_at on public.students;
create trigger trg_students_updated_at before update on public.students for each row execute function app.set_updated_at();
drop trigger if exists trg_parents_updated_at on public.parents;
create trigger trg_parents_updated_at before update on public.parents for each row execute function app.set_updated_at();
drop trigger if exists trg_enrollments_updated_at on public.enrollments;
create trigger trg_enrollments_updated_at before update on public.enrollments for each row execute function app.set_updated_at();
drop trigger if exists trg_assessments_updated_at on public.assessments;
create trigger trg_assessments_updated_at before update on public.assessments for each row execute function app.set_updated_at();
drop trigger if exists trg_grades_updated_at on public.grades;
create trigger trg_grades_updated_at before update on public.grades for each row execute function app.set_updated_at();
drop trigger if exists trg_report_cards_updated_at on public.report_cards;
create trigger trg_report_cards_updated_at before update on public.report_cards for each row execute function app.set_updated_at();
drop trigger if exists trg_invoices_updated_at on public.invoices;
create trigger trg_invoices_updated_at before update on public.invoices for each row execute function app.set_updated_at();

create or replace function app.ensure_single_current_year()
returns trigger language plpgsql as $$
begin
  if new.is_current then
    update public.school_years set is_current=false
    where school_id=new.school_id and id<>new.id;
  end if;
  return new;
end $$;

drop trigger if exists trg_single_current_year on public.school_years;
create trigger trg_single_current_year before insert or update on public.school_years
for each row execute function app.ensure_single_current_year();

create or replace function app.validate_grade()
returns trigger language plpgsql as $$
declare v_max numeric;
begin
  select max_score into v_max from public.assessments where id=new.assessment_id;
  if new.score>v_max then raise exception 'La note % dépasse le barème %',new.score,v_max; end if;
  if v_max is null or v_max <= 0 then
    raise exception 'Barème invalide pour l''évaluation %', new.assessment_id;
  end if;
  new.normalized_score=round((new.score/v_max)*20,2);
  return new;
end $$;

drop trigger if exists trg_validate_grade on public.grades;
create trigger trg_validate_grade before insert or update on public.grades
for each row execute function app.validate_grade();

create or replace function app.audit_grade_change()
returns trigger language plpgsql as $$
begin
  if tg_op='UPDATE' and old.score is distinct from new.score then
    insert into public.grade_audit(grade_id,old_score,new_score,changed_by,reason)
    values(new.id,old.score,new.score,auth.uid(),'Modification de note');
  end if;
  return new;
end $$;

drop trigger if exists trg_audit_grade_change on public.grades;
create trigger trg_audit_grade_change after update on public.grades
for each row execute function app.audit_grade_change();

-- =========================================================
-- 22. FONCTIONS DE CALCUL
-- =========================================================
create or replace function app.student_balance(p_student_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select coalesce((select sum(amount_due) from public.student_charges where student_id=p_student_id),0)
       - coalesce((select sum(pa.amount) from public.payment_allocations pa
                   join public.student_charges sc on sc.id=pa.student_charge_id
                   where sc.student_id=p_student_id),0)
$$;

create or replace function app.invoice_balance(p_invoice_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select coalesce((select total from public.invoices where id=p_invoice_id),0)
       - coalesce((select sum(amount) from public.payment_allocations where invoice_id=p_invoice_id),0)
$$;

create or replace function app.subject_average(p_student_id uuid,p_subject_id uuid,p_period_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select round(sum(g.normalized_score*g.coefficient)/nullif(sum(g.coefficient),0),2)
  from public.grades g
  join public.assessments a on a.id=g.assessment_id
  where g.student_id=p_student_id and a.subject_id=p_subject_id
    and a.period_id=p_period_id and a.is_published=true
$$;

create or replace function app.stock_quantity(p_product_id uuid,p_location_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select coalesce(sum(case
    when movement_type in ('purchase','return','adjustment','production_in') then quantity
    when movement_type in ('sale','issue','loss','transfer','production_out') then -quantity
    else 0 end),0)
  from public.stock_movements
  where product_id=p_product_id and location_id=p_location_id
$$;

-- =========================================================
-- 23. RLS
-- =========================================================
alter table public.schools enable row level security;
alter table public.school_settings enable row level security;
alter table public.school_years enable row level security;
alter table public.academic_periods enable row level security;
alter table public.users enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.levels enable row level security;
alter table public.classes enable row level security;
alter table public.subjects enable row level security;
alter table public.programs enable row level security;
alter table public.employees enable row level security;
alter table public.teacher_profiles enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.students enable row level security;
alter table public.parents enable row level security;
alter table public.student_parents enable row level security;
alter table public.authorized_pickup_persons enable row level security;
alter table public.admission_applications enable row level security;
alter table public.enrollments enable row level security;
alter table public.enrollment_history enable row level security;
alter table public.document_types enable row level security;
alter table public.documents enable row level security;
alter table public.timetable_slots enable row level security;
alter table public.assessment_types enable row level security;
alter table public.assessments enable row level security;
alter table public.grades enable row level security;
alter table public.grade_audit enable row level security;
alter table public.report_cards enable row level security;
alter table public.report_card_items enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.absence_justifications enable row level security;
alter table public.discipline_categories enable row level security;
alter table public.discipline_events enable row level security;
alter table public.student_followups enable row level security;
alter table public.student_rewards enable row level security;
alter table public.boarding_buildings enable row level security;
alter table public.boarding_dormitories enable row level security;
alter table public.boarding_rooms enable row level security;
alter table public.boarding_beds enable row level security;
alter table public.boarding_assignments enable row level security;
alter table public.boarding_movements enable row level security;
alter table public.boarding_attendance enable row level security;
alter table public.meal_types enable row level security;
alter table public.menus enable row level security;
alter table public.menu_items enable row level security;
alter table public.meal_service_records enable row level security;
alter table public.meal_attendance enable row level security;
alter table public.tahfiz_levels enable row level security;
alter table public.quran_surahs enable row level security;
alter table public.student_tahfiz enable row level security;
alter table public.tahfiz_sessions enable row level security;
alter table public.islamic_training enable row level security;
alter table public.wushu_groups enable row level security;
alter table public.student_wushu enable row level security;
alter table public.wushu_sessions enable row level security;
alter table public.wushu_attendance enable row level security;
alter table public.wushu_evaluations enable row level security;
alter table public.wushu_competitions enable row level security;
alter table public.wushu_competition_results enable row level security;
alter table public.fee_types enable row level security;
alter table public.fee_schedules enable row level security;
alter table public.student_charges enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.receipts enable row level security;
alter table public.expense_categories enable row level security;
alter table public.suppliers enable row level security;
alter table public.expenses enable row level security;
alter table public.cash_accounts enable row level security;
alter table public.cash_transactions enable row level security;
alter table public.cash_closings enable row level security;
alter table public.collection_reminders enable row level security;
alter table public.stock_categories enable row level security;
alter table public.stock_locations enable row level security;
alter table public.products enable row level security;
alter table public.stock_balances enable row level security;
alter table public.stock_movements enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_items enable row level security;
alter table public.stock_inventories enable row level security;
alter table public.stock_inventory_items enable row level security;
alter table public.economic_activities enable row level security;
alter table public.agriculture_campaigns enable row level security;
alter table public.agriculture_expenses enable row level security;
alter table public.livestock enable row level security;
alter table public.livestock_events enable row level security;
alter table public.productions enable row level security;
alter table public.sales enable row level security;
alter table public.employee_contracts enable row level security;
alter table public.employee_attendance enable row level security;
alter table public.employee_leaves enable row level security;
alter table public.payroll_periods enable row level security;
alter table public.payroll_items enable row level security;
alter table public.announcements enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_alerts enable row level security;
alter table public.audit_logs enable row level security;

-- Policies tenant : toutes les tables possédant school_id.
do $$
declare t text;
begin
  foreach t in array array[
    'school_settings','school_years','levels','classes','subjects','programs','employees',
    'teacher_assignments','students','parents','authorized_pickup_persons','admission_applications',
    'enrollments','document_types','documents','timetable_slots','assessment_types','assessments',
    'grades','report_cards','attendance_sessions','absence_justifications','discipline_categories',
    'discipline_events','student_followups','student_rewards','boarding_buildings','boarding_assignments',
    'boarding_movements','boarding_attendance','meal_types','menus','meal_service_records','meal_attendance',
    'tahfiz_levels','student_tahfiz','tahfiz_sessions','islamic_training','wushu_groups','student_wushu',
    'wushu_sessions','wushu_evaluations','wushu_competitions','fee_types','fee_schedules','student_charges',
    'invoices','payments','receipts','expense_categories','suppliers','expenses','cash_accounts',
    'cash_transactions','cash_closings','collection_reminders','stock_categories','stock_locations',
    'products','stock_movements','purchase_orders','stock_inventories','economic_activities','sales',
    'employee_attendance','employee_leaves','payroll_periods','announcements','notifications',
    'ai_conversations','ai_alerts'
  ] loop
    execute format('create policy %I on public.%I for select using (school_id in (select app.my_school_ids()) or app.is_super_admin())',t||'_select',t);
    execute format('create policy %I on public.%I for insert with check (school_id in (select app.my_school_ids()) or app.is_super_admin())',t||'_insert',t);
    execute format('create policy %I on public.%I for update using (school_id in (select app.my_school_ids()) or app.is_super_admin()) with check (school_id in (select app.my_school_ids()) or app.is_super_admin())',t||'_update',t);
    execute format('create policy %I on public.%I for delete using (school_id in (select app.my_school_ids()) or app.is_super_admin())',t||'_delete',t);
  end loop;
end $$;

create policy schools_select on public.schools
for select using (id in (select app.my_school_ids()) or app.is_super_admin());

create policy schools_manage on public.schools
for all using (app.is_super_admin()) with check(app.is_super_admin());

create policy users_select on public.users
for select using (id=auth.uid() or school_id in (select app.my_school_ids()) or app.is_super_admin());

create policy users_update on public.users
for update using (id=auth.uid() or app.has_permission('users.manage',school_id) or app.is_super_admin())
with check(id=auth.uid() or app.has_permission('users.manage',school_id) or app.is_super_admin());

create policy user_roles_select on public.user_roles
for select using(user_id=auth.uid() or school_id in(select app.my_school_ids()) or app.is_super_admin());

create policy user_roles_manage on public.user_roles
for all using(app.has_permission('users.roles.manage',school_id) or app.is_super_admin())
with check(app.has_permission('users.roles.manage',school_id) or app.is_super_admin());

create policy roles_select on public.roles for select using(auth.uid() is not null);
create policy permissions_select on public.permissions for select using(auth.uid() is not null);
create policy role_permissions_select on public.role_permissions for select using(auth.uid() is not null);
create policy quran_surahs_select on public.quran_surahs for select using(auth.uid() is not null);

-- Tables sans school_id direct : accès via leurs parents.
create policy teacher_profiles_all on public.teacher_profiles
for all using(
  employee_id in(select id from public.employees where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
)
with check(
  employee_id in(select id from public.employees where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
);

create policy academic_periods_all on public.academic_periods
for all using(
  school_year_id in(select id from public.school_years where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
)
with check(
  school_year_id in(select id from public.school_years where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
);

create policy student_parents_all on public.student_parents
for all using(
  student_id in(select id from public.students where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
)
with check(
  student_id in(select id from public.students where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
);

create policy enrollment_history_all on public.enrollment_history
for all using(
  student_id in(select id from public.students where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
)
with check(
  student_id in(select id from public.students where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
);

create policy report_card_items_all on public.report_card_items
for all using(
  report_card_id in(select id from public.report_cards where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
)
with check(
  report_card_id in(select id from public.report_cards where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
);

create policy attendance_records_all on public.attendance_records
for all using(
  session_id in(select id from public.attendance_sessions where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
)
with check(
  session_id in(select id from public.attendance_sessions where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
);

create policy boarding_dormitories_all on public.boarding_dormitories
for all using(
  building_id in(select id from public.boarding_buildings where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
)
with check(
  building_id in(select id from public.boarding_buildings where school_id in(select app.my_school_ids()))
  or app.is_super_admin()
);

create policy boarding_rooms_all on public.boarding_rooms
for all using(
  dormitory_id in(
    select bd.id from public.boarding_dormitories bd
    join public.boarding_buildings bb on bb.id=bd.building_id
    where bb.school_id in(select app.my_school_ids())
  ) or app.is_super_admin()
)
with check(
  dormitory_id in(
    select bd.id from public.boarding_dormitories bd
    join public.boarding_buildings bb on bb.id=bd.building_id
    where bb.school_id in(select app.my_school_ids())
  ) or app.is_super_admin()
);

create policy boarding_beds_all on public.boarding_beds
for all using(
  room_id in(
    select br.id from public.boarding_rooms br
    join public.boarding_dormitories bd on bd.id=br.dormitory_id
    join public.boarding_buildings bb on bb.id=bd.building_id
    where bb.school_id in(select app.my_school_ids())
  ) or app.is_super_admin()
)
with check(
  room_id in(
    select br.id from public.boarding_rooms br
    join public.boarding_dormitories bd on bd.id=br.dormitory_id
    join public.boarding_buildings bb on bb.id=bd.building_id
    where bb.school_id in(select app.my_school_ids())
  ) or app.is_super_admin()
);

create policy menu_items_all on public.menu_items
for all using(menu_id in(select id from public.menus where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(menu_id in(select id from public.menus where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy payment_allocations_all on public.payment_allocations
for all using(payment_id in(select id from public.payments where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(payment_id in(select id from public.payments where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy invoice_items_all on public.invoice_items
for all using(invoice_id in(select id from public.invoices where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(invoice_id in(select id from public.invoices where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy purchase_items_all on public.purchase_items
for all using(purchase_order_id in(select id from public.purchase_orders where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(purchase_order_id in(select id from public.purchase_orders where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy stock_balances_all on public.stock_balances
for all using(product_id in(select id from public.products where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(product_id in(select id from public.products where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy stock_inventory_items_all on public.stock_inventory_items
for all using(inventory_id in(select id from public.stock_inventories where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(inventory_id in(select id from public.stock_inventories where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy agriculture_campaigns_all on public.agriculture_campaigns
for all using(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy agriculture_expenses_all on public.agriculture_expenses
for all using(campaign_id in(
  select ac.id from public.agriculture_campaigns ac
  join public.economic_activities ea on ea.id=ac.activity_id
  where ea.school_id in(select app.my_school_ids())
) or app.is_super_admin())
with check(campaign_id in(
  select ac.id from public.agriculture_campaigns ac
  join public.economic_activities ea on ea.id=ac.activity_id
  where ea.school_id in(select app.my_school_ids())
) or app.is_super_admin());

create policy livestock_all on public.livestock
for all using(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy livestock_events_all on public.livestock_events
for all using(livestock_id in(
  select l.id from public.livestock l join public.economic_activities ea on ea.id=l.activity_id
  where ea.school_id in(select app.my_school_ids())
) or app.is_super_admin())
with check(livestock_id in(
  select l.id from public.livestock l join public.economic_activities ea on ea.id=l.activity_id
  where ea.school_id in(select app.my_school_ids())
) or app.is_super_admin());

create policy productions_all on public.productions
for all using(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy employee_contracts_all on public.employee_contracts
for all using(employee_id in(select id from public.employees where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(employee_id in(select id from public.employees where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy payroll_items_all on public.payroll_items
for all using(payroll_period_id in(select id from public.payroll_periods where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(payroll_period_id in(select id from public.payroll_periods where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy wushu_attendance_all on public.wushu_attendance
for all using(session_id in(select id from public.wushu_sessions where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(session_id in(select id from public.wushu_sessions where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy wushu_competition_results_all on public.wushu_competition_results
for all using(competition_id in(select id from public.wushu_competitions where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(competition_id in(select id from public.wushu_competitions where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy ai_messages_all on public.ai_messages
for all using(conversation_id in(select id from public.ai_conversations where school_id in(select app.my_school_ids())) or app.is_super_admin())
with check(conversation_id in(select id from public.ai_conversations where school_id in(select app.my_school_ids())) or app.is_super_admin());

create policy notification_preferences_self on public.notification_preferences
for all using(user_id=auth.uid() or app.is_super_admin())
with check(user_id=auth.uid() or app.is_super_admin());

-- =========================================================
-- 24. RÔLES INITIAUX
-- =========================================================
insert into public.roles(code,name,description) values
('super_admin','Administrateur système','Administration technique globale'),
('founder','Coordonnateur / Fondateur','Pilotage global'),
('direction','Direction','Pilotage général'),
('admin','Administration / Secrétariat','Dossiers, inscriptions, documents'),
('academic_director','Direction des études','Pédagogie et résultats'),
('teacher','Enseignant','Classes, présences, notes'),
('accountant','Comptable / Finance','Facturation, paiements, dépenses'),
('boarding_manager','Responsable internat','Internat et restauration'),
('supervisor','Surveillant / Encadrement','Présences et discipline'),
('tahfiz_manager','Responsable Tahfiz','Suivi Tahfiz'),
('arabic_manager','Responsable Arabe','Formation arabe'),
('wushu_manager','Responsable Wushu','Wushu'),
('catering_manager','Responsable restauration','Menus et repas'),
('agriculture_manager','Responsable agriculture','Production agricole'),
('livestock_manager','Responsable élevage','Cheptel et production'),
('hr_manager','Responsable personnel','Ressources humaines'),
('stock_manager','Responsable stocks','Stocks et inventaires'),
('parent','Parent / Tuteur','Espace famille'),
('student','Élève','Espace personnel'),
('it_admin','Administrateur informatique','Comptes, sécurité, configuration')
on conflict(code) do nothing;

insert into public.permissions(code,name,module,action,description) values
('users.manage','Gérer utilisateurs','users','manage','Créer/modifier/désactiver les comptes'),
('users.roles.manage','Gérer rôles','users','roles','Attribuer les rôles'),
('students.view','Consulter élèves','students','view','Consulter les dossiers autorisés'),
('students.manage','Gérer élèves','students','manage','Créer/modifier les dossiers'),
('parents.view','Consulter parents','parents','view','Consulter les parents'),
('parents.manage','Gérer parents','parents','manage','Créer/modifier les parents'),
('enrollments.manage','Gérer inscriptions','enrollments','manage','Admissions et inscriptions'),
('classes.manage','Gérer classes','academic','manage','Classes et affectations'),
('subjects.manage','Gérer matières','academic','manage','Matières et coefficients'),
('teachers.manage','Gérer enseignants','academic','manage','Affectations pédagogiques'),
('timetable.manage','Gérer emploi du temps','academic','manage','Créneaux et conflits'),
('assessments.manage','Gérer évaluations','grades','manage','Créer les évaluations'),
('grades.enter','Saisir notes','grades','enter','Saisie/modification des notes'),
('grades.publish','Publier notes','grades','publish','Publication des notes'),
('report_cards.generate','Générer bulletins','grades','report_cards','Générer les bulletins'),
('attendance.manage','Gérer présence','attendance','manage','Appel et assiduité'),
('discipline.manage','Gérer discipline','discipline','manage','Incidents et suivi éducatif'),
('finance.view','Consulter finance','finance','view','Consultation financière'),
('finance.manage','Gérer finance','finance','manage','Facturation et paiements'),
('expenses.manage','Gérer dépenses','finance','expenses','Dépenses et justificatifs'),
('cash.manage','Gérer caisse','finance','cash','Caisse et clôtures'),
('boarding.manage','Gérer internat','boarding','manage','Chambres, lits, mouvements'),
('catering.manage','Gérer restauration','catering','manage','Menus et repas'),
('tahfiz.manage','Gérer Tahfiz','tahfiz','manage','Suivi Tahfiz'),
('arabic.manage','Gérer arabe','arabic','manage','Formation arabe'),
('wushu.manage','Gérer Wushu','wushu','manage','Wushu'),
('hr.manage','Gérer personnel','hr','manage','Personnel et congés'),
('stock.manage','Gérer stocks','stock','manage','Stocks et inventaires'),
('purchases.manage','Gérer achats','purchases','manage','Fournisseurs et commandes'),
('agriculture.manage','Gérer agriculture','agriculture','manage','Production agricole'),
('livestock.manage','Gérer élevage','livestock','manage','Cheptel'),
('communication.manage','Gérer communication','communication','manage','Annonces'),
('reports.view','Consulter rapports','reports','view','Statistiques et tableaux de bord'),
('ai.use','Utiliser IA','ai','use','Assistant et analyses'),
('audit.view','Consulter audit','security','audit','Journal des opérations'),
('settings.manage','Gérer paramètres','settings','manage','Paramétrage')
on conflict(code) do nothing;

-- Super-admin et fondateur : toutes les permissions.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code in('super_admin','founder') on conflict do nothing;

-- Matrice métier initiale.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','students.manage','parents.view','parents.manage','enrollments.manage','classes.manage','subjects.manage','communication.manage','reports.view')
where r.code='admin' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','classes.manage','subjects.manage','teachers.manage','timetable.manage','assessments.manage','grades.enter','grades.publish','report_cards.generate','attendance.manage','reports.view')
where r.code='academic_director' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','assessments.manage','grades.enter','attendance.manage','reports.view')
where r.code='teacher' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('finance.view','finance.manage','expenses.manage','cash.manage','reports.view')
where r.code='accountant' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','boarding.manage','catering.manage','attendance.manage','discipline.manage','reports.view')
where r.code='boarding_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','attendance.manage','discipline.manage')
where r.code='supervisor' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','tahfiz.manage','reports.view')
where r.code='tahfiz_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','arabic.manage','reports.view')
where r.code='arabic_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','wushu.manage','reports.view')
where r.code='wushu_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('catering.manage','stock.manage','purchases.manage','reports.view')
where r.code='catering_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('agriculture.manage','stock.manage','finance.view','reports.view')
where r.code='agriculture_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('livestock.manage','stock.manage','finance.view','reports.view')
where r.code='livestock_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('hr.manage','reports.view')
where r.code='hr_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('stock.manage','purchases.manage','reports.view')
where r.code='stock_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('users.manage','users.roles.manage','settings.manage','audit.view')
where r.code='it_admin' on conflict do nothing;

-- =========================================================
-- 25. VUES DE PILOTAGE
-- =========================================================
create or replace view public.v_class_effectives as
select c.id class_id,c.school_id,c.school_year_id,c.name class_name,
count(e.student_id) filter(where e.status='enrolled') active_students
from public.classes c
left join public.enrollments e on e.class_id=c.id
group by c.id,c.school_id,c.school_year_id,c.name;

create or replace view public.v_student_financial_summary as
select
  s.id student_id,
  s.school_id,
  s.student_number,
  s.first_name,
  s.last_name,
  coalesce((select sum(sc.amount_due)
            from public.student_charges sc
            where sc.student_id=s.id),0) total_due,
  coalesce((select sum(pa.amount)
            from public.payment_allocations pa
            join public.student_charges sc on sc.id=pa.student_charge_id
            join public.payments p on p.id=pa.payment_id
            where sc.student_id=s.id and p.status='paid'),0) total_paid,
  coalesce((select sum(sc.amount_due)
            from public.student_charges sc
            where sc.student_id=s.id),0)
  -
  coalesce((select sum(pa.amount)
            from public.payment_allocations pa
            join public.student_charges sc on sc.id=pa.student_charge_id
            join public.payments p on p.id=pa.payment_id
            where sc.student_id=s.id and p.status='paid'),0) balance
from public.students s;

comment on table public.students is 'Dossier numérique central de l’élève.';
comment on table public.enrollments is 'Scolarité annuelle : classe, régime, statut et historique.';
comment on table public.grades is 'Notes brutes et notes normalisées; les modifications doivent être auditées.';
comment on table public.payments is 'Encaissements financiers.';
comment on table public.audit_logs is 'Traçabilité des opérations sensibles.';
comment on table public.ai_alerts is 'Alertes issues des règles métier et/ou de l’IA; validation humaine obligatoire.';

commit;

-- FIN SIGIA-AMINE V1.0
