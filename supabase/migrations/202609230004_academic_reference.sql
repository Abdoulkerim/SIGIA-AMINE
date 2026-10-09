-- SIGIA-AMINE
-- Migration 004: academic_reference
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Levels, classes, subjects and programs.

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

commit;
