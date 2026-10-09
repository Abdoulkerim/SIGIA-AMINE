begin;
select plan(1);

-- Contrat Étape 20 — Tahfiz / Arabe
DO $$
begin
  if to_regclass('public.student_tahfiz') is null then raise exception 'student_tahfiz manquant'; end if;
  if to_regclass('public.tahfiz_sessions') is null then raise exception 'tahfiz_sessions manquant'; end if;
  if to_regclass('public.tahfiz_progress_history') is null then raise exception 'tahfiz_progress_history manquant'; end if;
  if to_regclass('public.arabic_levels') is null then raise exception 'arabic_levels manquant'; end if;
  if to_regclass('public.student_arabic') is null then raise exception 'student_arabic manquant'; end if;
  if to_regclass('public.arabic_sessions') is null then raise exception 'arabic_sessions manquant'; end if;
  if to_regclass('public.arabic_evaluations') is null then raise exception 'arabic_evaluations manquant'; end if;
  if to_regclass('public.arabic_progress_history') is null then raise exception 'arabic_progress_history manquant'; end if;
  if to_regprocedure('public.create_tahfiz_level(text,text,integer,text)') is null then raise exception 'RPC create_tahfiz_level manquante'; end if;
  if to_regprocedure('public.assign_student_tahfiz(uuid,uuid,uuid,date,numeric,text,text)') is null then raise exception 'RPC assign_student_tahfiz manquante'; end if;
  if to_regprocedure('public.record_tahfiz_session(uuid,date,text,smallint,smallint,smallint,numeric,text,uuid,app.attendance_status,numeric,boolean)') is null then raise exception 'RPC record_tahfiz_session manquante'; end if;
  if to_regprocedure('public.create_arabic_level(text,text,integer,text)') is null then raise exception 'RPC create_arabic_level manquante'; end if;
  if to_regprocedure('public.assign_student_arabic(uuid,uuid,uuid,date,numeric,text,text)') is null then raise exception 'RPC assign_student_arabic manquante'; end if;
  if to_regprocedure('public.record_arabic_session(uuid,date,text,text,numeric,text,uuid,app.attendance_status,numeric,boolean)') is null then raise exception 'RPC record_arabic_session manquante'; end if;
  if to_regprocedure('public.create_arabic_evaluation(uuid,uuid,date,text,text,numeric,text,uuid,boolean)') is null then raise exception 'RPC create_arabic_evaluation manquante'; end if;
  if to_regprocedure('public.get_student_tahfiz_arabic(uuid)') is null then raise exception 'RPC get_student_tahfiz_arabic manquante'; end if;
  if to_regprocedure('public.get_specialized_staff(text)') is null then raise exception 'RPC get_specialized_staff manquante'; end if;
  if to_regprocedure('public.get_specialized_periods()') is null then raise exception 'RPC get_specialized_periods manquante'; end if;
end $$;

DO $$
begin
  if not exists(select 1 from public.permissions where code='tahfiz.view') then raise exception 'permission tahfiz.view manquante'; end if;
  if not exists(select 1 from public.permissions where code='arabic.view') then raise exception 'permission arabic.view manquante'; end if;
  if not exists(select 1 from public.permissions where code='tahfiz.manage') then raise exception 'permission tahfiz.manage manquante'; end if;
  if not exists(select 1 from public.permissions where code='arabic.manage') then raise exception 'permission arabic.manage manquante'; end if;
end $$;

DO $$
begin
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='student_tahfiz' and policyname='student_tahfiz_view') then raise exception 'RLS student_tahfiz_view manquante'; end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='arabic_evaluations' and policyname='arabic_evaluations_view') then raise exception 'RLS arabic_evaluations_view manquante'; end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='tahfiz_sessions' and policyname='tahfiz_sessions_manage') then raise exception 'RLS tahfiz_sessions_manage manquante'; end if;
end $$;

select pass('Tahfiz / Arabe schema contract');
select * from finish();
rollback;
