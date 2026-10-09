-- SIGIA-AMINE
-- Migration 007: documents
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Document registry. Binary files are stored in private Supabase Storage, hardened in 014.

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

commit;
