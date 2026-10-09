-- SIGIA-AMINE
-- Migration 001: extensions_types
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Extensions, app schema and enums.

create schema if not exists app;

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

commit;
