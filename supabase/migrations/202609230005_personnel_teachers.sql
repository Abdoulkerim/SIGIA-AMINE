-- SIGIA-AMINE
-- Migration 005: personnel_teachers
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Employees, teacher profiles, assignments and homeroom relation.

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

commit;
