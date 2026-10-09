-- SIGIA-AMINE
-- Migration 010: tahfiz_wushu
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Tahfiz, Islamic training and Wushu.

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

commit;
