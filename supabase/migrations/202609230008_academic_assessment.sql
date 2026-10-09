-- SIGIA-AMINE
-- Migration 008: academic_assessment
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Timetable, assessments, grades, grade audit and report cards.

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

commit;
