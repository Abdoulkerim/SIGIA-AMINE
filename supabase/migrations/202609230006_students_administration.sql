-- SIGIA-AMINE
-- Migration 006: students_administration
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Students, parents, family relations, admissions, enrollments and history.

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

commit;
