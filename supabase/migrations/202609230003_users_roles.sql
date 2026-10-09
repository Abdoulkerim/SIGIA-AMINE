-- SIGIA-AMINE
-- Migration 003: users_roles
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Auth-linked users, RBAC tables. Seeds are deliberately deferred to migration 013.

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

commit;
