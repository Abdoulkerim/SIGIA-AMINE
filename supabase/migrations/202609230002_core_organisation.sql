-- SIGIA-AMINE
-- Migration 002: core_organisation
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Schools, school settings, school years and academic periods.

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

commit;
