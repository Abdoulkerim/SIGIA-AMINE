begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- SIGIA-AMINE — Migration 028
-- Étape 20 : Tahfiz / Arabe
-- Renforce les tables Tahfiz existantes et ajoute le sous-module Arabe.
-- Les programmes, niveaux, échelles de notation et contenus précis restent paramétrables
-- car le cahier des charges ne fournit pas de référentiel pédagogique officiel détaillé.

-- =========================================================
-- 1. RBAC spécialisé
-- =========================================================
insert into public.permissions(code,name,module,action,description) values
('tahfiz.view','Consulter Tahfiz','tahfiz','view','Consulter les profils, progressions et résultats Tahfiz autorisés'),
('arabic.view','Consulter Arabe','arabic','view','Consulter les profils, progressions et résultats Arabe autorisés')
on conflict (code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r cross join public.permissions p
where r.code='tahfiz_manager' and p.code in ('tahfiz.view','tahfiz.manage')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r cross join public.permissions p
where r.code='arabic_manager' and p.code in ('arabic.view','arabic.manage')
on conflict do nothing;

-- Direction/founder/super_admin sont déjà couverts par les helpers RBAC existants.

-- =========================================================
-- 2. Tahfiz — durcissement des tables existantes
-- =========================================================
alter table public.tahfiz_levels
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.student_tahfiz
  add column if not exists status text not null default 'active',
  add column if not exists updated_at timestamptz not null default now();

alter table public.tahfiz_sessions
  add column if not exists attendance_status app.attendance_status not null default 'present',
  add column if not exists is_published boolean not null default false,
  add column if not exists created_at timestamptz not null default now();

alter table public.tahfiz_sessions
  add constraint tahfiz_sessions_verse_range_ck
  check ((from_verse is null and to_verse is null) or (from_verse is not null and to_verse is not null and from_verse >= 1 and to_verse >= from_verse));

alter table public.tahfiz_sessions
  add constraint tahfiz_sessions_score_nonnegative_ck
  check (score is null or score >= 0);

alter table public.student_tahfiz
  add constraint student_tahfiz_status_ck
  check (status in ('active','paused','completed','inactive'));

create unique index if not exists uq_tahfiz_levels_school_code_ci
  on public.tahfiz_levels(school_id, lower(code));
create index if not exists idx_tahfiz_levels_school_active
  on public.tahfiz_levels(school_id,is_active,sequence_no);
create index if not exists idx_student_tahfiz_school_level
  on public.student_tahfiz(school_id,tahfiz_level_id,status);
create index if not exists idx_tahfiz_sessions_student_date
  on public.tahfiz_sessions(student_id,session_date desc);
create index if not exists idx_tahfiz_sessions_school_date
  on public.tahfiz_sessions(school_id,session_date desc);

-- Historique des changements de progression Tahfiz.
create table if not exists public.tahfiz_progress_history(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_tahfiz_id uuid not null references public.student_tahfiz(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  progress numeric(6,2) not null check(progress between 0 and 100),
  source_session_id uuid references public.tahfiz_sessions(id) on delete set null,
  note text,
  recorded_by uuid references public.users(id) on delete set null,
  recorded_at timestamptz not null default now()
);
create index if not exists idx_tahfiz_progress_history_student
  on public.tahfiz_progress_history(student_id,recorded_at desc);

-- =========================================================
-- 3. Arabe — sous-module spécialisé paramétrable
-- =========================================================
create table if not exists public.arabic_levels(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  sequence_no integer not null default 0 check(sequence_no >= 0),
  is_active boolean not null default true,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,code)
);

create unique index if not exists uq_arabic_levels_school_code_ci
  on public.arabic_levels(school_id,lower(code));
create index if not exists idx_arabic_levels_school_active
  on public.arabic_levels(school_id,is_active,sequence_no);

create table if not exists public.student_arabic(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade unique,
  arabic_level_id uuid references public.arabic_levels(id) on delete set null,
  assigned_teacher_id uuid references public.employees(id) on delete set null,
  start_date date,
  current_progress numeric(6,2) not null default 0 check(current_progress between 0 and 100),
  status text not null default 'active' check(status in ('active','paused','completed','inactive')),
  notes text,
  updated_at timestamptz not null default now()
);
create index if not exists idx_student_arabic_school_level
  on public.student_arabic(school_id,arabic_level_id,status);

create table if not exists public.arabic_sessions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  session_date date not null,
  activity_type text not null check(length(btrim(activity_type)) between 1 and 100),
  topic text,
  score numeric(8,2) check(score is null or score >= 0),
  observation text,
  teacher_id uuid references public.employees(id) on delete set null,
  attendance_status app.attendance_status not null default 'present',
  progress_after numeric(6,2) check(progress_after is null or progress_after between 0 and 100),
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_arabic_sessions_student_date
  on public.arabic_sessions(student_id,session_date desc);
create index if not exists idx_arabic_sessions_school_date
  on public.arabic_sessions(school_id,session_date desc);

create table if not exists public.arabic_evaluations(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  period_id uuid references public.academic_periods(id) on delete set null,
  evaluation_date date not null,
  title text not null,
  skill_area text,
  score numeric(8,2) check(score is null or score >= 0),
  observation text,
  evaluator_id uuid references public.employees(id) on delete set null,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_arabic_evaluations_student_date
  on public.arabic_evaluations(student_id,evaluation_date desc);
create index if not exists idx_arabic_evaluations_school_date
  on public.arabic_evaluations(school_id,evaluation_date desc);

create table if not exists public.arabic_progress_history(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_arabic_id uuid not null references public.student_arabic(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  progress numeric(6,2) not null check(progress between 0 and 100),
  source_session_id uuid references public.arabic_sessions(id) on delete set null,
  note text,
  recorded_by uuid references public.users(id) on delete set null,
  recorded_at timestamptz not null default now()
);
create index if not exists idx_arabic_progress_history_student
  on public.arabic_progress_history(student_id,recorded_at desc);

-- =========================================================
-- 4. Cohérence métier et timestamps
-- =========================================================
create or replace function app.validate_tahfiz_profile()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if not exists(select 1 from public.students s where s.id=new.student_id and s.school_id=new.school_id) then
    raise exception 'student_tahfiz: élève hors établissement';
  end if;
  if new.tahfiz_level_id is not null and not exists(select 1 from public.tahfiz_levels l where l.id=new.tahfiz_level_id and l.school_id=new.school_id) then
    raise exception 'student_tahfiz: niveau Tahfiz hors établissement';
  end if;
  if new.assigned_teacher_id is not null and not exists(select 1 from public.employees e where e.id=new.assigned_teacher_id and e.school_id=new.school_id and e.status='active') then
    raise exception 'student_tahfiz: enseignant/responsable invalide';
  end if;
  return new;
end $$;

create or replace function app.validate_tahfiz_session()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_school uuid; v_verses smallint;
begin
  select s.school_id into v_school from public.students s where s.id=new.student_id;
  if v_school is null or v_school <> new.school_id then
    raise exception 'tahfiz_session: élève hors établissement';
  end if;
  if not exists(select 1 from public.student_tahfiz st where st.student_id=new.student_id and st.school_id=new.school_id and st.status in ('active','paused','completed')) then
    raise exception 'tahfiz_session: le profil Tahfiz de l''élève est requis';
  end if;
  if new.teacher_id is not null and not exists(select 1 from public.employees e where e.id=new.teacher_id and e.school_id=new.school_id and e.status='active') then
    raise exception 'tahfiz_session: responsable invalide';
  end if;
  if new.surah_id is not null then
    select verse_count into v_verses from public.quran_surahs where id=new.surah_id;
    if new.from_verse is not null and new.to_verse is not null and v_verses is not null and (new.from_verse > v_verses or new.to_verse > v_verses) then
      raise exception 'tahfiz_session: plage de versets hors limite de la sourate';
    end if;
  elsif new.from_verse is not null or new.to_verse is not null then
    raise exception 'tahfiz_session: la sourate est requise pour une plage de versets';
  end if;
  return new;
end $$;

create or replace function app.validate_arabic_profile()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if not exists(select 1 from public.students s where s.id=new.student_id and s.school_id=new.school_id) then
    raise exception 'student_arabic: élève hors établissement';
  end if;
  if new.arabic_level_id is not null and not exists(select 1 from public.arabic_levels l where l.id=new.arabic_level_id and l.school_id=new.school_id) then
    raise exception 'student_arabic: niveau Arabe hors établissement';
  end if;
  if new.assigned_teacher_id is not null and not exists(select 1 from public.employees e where e.id=new.assigned_teacher_id and e.school_id=new.school_id and e.status='active') then
    raise exception 'student_arabic: responsable invalide';
  end if;
  return new;
end $$;

create or replace function app.validate_arabic_session()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if not exists(select 1 from public.students s where s.id=new.student_id and s.school_id=new.school_id) then
    raise exception 'arabic_session: élève hors établissement';
  end if;
  if not exists(select 1 from public.student_arabic sa where sa.student_id=new.student_id and sa.school_id=new.school_id and sa.status in ('active','paused','completed')) then
    raise exception 'arabic_session: le profil Arabe de l''élève est requis';
  end if;
  if new.teacher_id is not null and not exists(select 1 from public.employees e where e.id=new.teacher_id and e.school_id=new.school_id and e.status='active') then
    raise exception 'arabic_session: responsable invalide';
  end if;
  return new;
end $$;

create or replace function app.touch_training_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end $$;

drop trigger if exists trg_tahfiz_levels_updated_at on public.tahfiz_levels;
create trigger trg_tahfiz_levels_updated_at before update on public.tahfiz_levels for each row execute function app.touch_training_updated_at();
drop trigger if exists trg_student_tahfiz_updated_at on public.student_tahfiz;
create trigger trg_student_tahfiz_updated_at before update on public.student_tahfiz for each row execute function app.touch_training_updated_at();
drop trigger if exists trg_arabic_levels_updated_at on public.arabic_levels;
create trigger trg_arabic_levels_updated_at before update on public.arabic_levels for each row execute function app.touch_training_updated_at();
drop trigger if exists trg_tahfiz_profile_validate on public.student_tahfiz;
create trigger trg_tahfiz_profile_validate before insert or update on public.student_tahfiz for each row execute function app.validate_tahfiz_profile();
drop trigger if exists trg_tahfiz_session_validate on public.tahfiz_sessions;
create trigger trg_tahfiz_session_validate before insert or update on public.tahfiz_sessions for each row execute function app.validate_tahfiz_session();
drop trigger if exists trg_arabic_profile_validate on public.student_arabic;
create trigger trg_arabic_profile_validate before insert or update on public.student_arabic for each row execute function app.validate_arabic_profile();
drop trigger if exists trg_arabic_session_validate on public.arabic_sessions;
create trigger trg_arabic_session_validate before insert or update on public.arabic_sessions for each row execute function app.validate_arabic_session();

-- =========================================================
-- 5. RPCs sécurisées
-- =========================================================
create or replace function public.create_tahfiz_level(p_code text,p_name text,p_sequence_no integer default 0,p_description text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select u.school_id into v_school from public.users u where u.id=auth.uid();
  if v_school is null or not app.has_permission('tahfiz.manage',v_school) then raise exception 'Accès Tahfiz refusé'; end if;
  insert into public.tahfiz_levels(school_id,code,name,sequence_no,description) values(v_school,btrim(p_code),btrim(p_name),coalesce(p_sequence_no,0),nullif(btrim(p_description),'')) returning id into v_id;
  return v_id;
end $$;

create or replace function public.assign_student_tahfiz(p_student_id uuid,p_tahfiz_level_id uuid default null,p_teacher_id uuid default null,p_start_date date default null,p_progress numeric default 0,p_status text default 'active',p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid; v_old numeric;
begin
  select s.school_id into v_school from public.students s where s.id=p_student_id;
  if v_school is null or not app.has_permission('tahfiz.manage',v_school) then raise exception 'Accès Tahfiz refusé'; end if;
  if p_progress < 0 or p_progress > 100 then raise exception 'Progression Tahfiz invalide'; end if;
  insert into public.student_tahfiz(school_id,student_id,tahfiz_level_id,assigned_teacher_id,start_date,current_progress,status,notes)
  values(v_school,p_student_id,p_tahfiz_level_id,p_teacher_id,p_start_date,p_progress,p_status,nullif(btrim(p_notes),''))
  on conflict (student_id) do update set tahfiz_level_id=excluded.tahfiz_level_id,assigned_teacher_id=excluded.assigned_teacher_id,start_date=excluded.start_date,current_progress=excluded.current_progress,status=excluded.status,notes=excluded.notes,updated_at=now()
  returning id,current_progress into v_id,v_old;
  insert into public.tahfiz_progress_history(school_id,student_tahfiz_id,student_id,progress,note,recorded_by)
  values(v_school,v_id,p_student_id,p_progress,'Initialisation / mise à jour du profil',auth.uid());
  return v_id;
end $$;

create or replace function public.record_tahfiz_session(p_student_id uuid,p_session_date date,p_session_type text,p_surah_id smallint default null,p_from_verse smallint default null,p_to_verse smallint default null,p_score numeric default null,p_observation text default null,p_teacher_id uuid default null,p_attendance_status app.attendance_status default 'present',p_progress_after numeric default null,p_is_published boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid; v_profile uuid; v_old numeric;
begin
  select s.school_id into v_school from public.students s where s.id=p_student_id;
  if v_school is null or not app.has_permission('tahfiz.manage',v_school) then raise exception 'Accès Tahfiz refusé'; end if;
  select id,current_progress into v_profile,v_old from public.student_tahfiz where student_id=p_student_id and school_id=v_school;
  if v_profile is null then raise exception 'Profil Tahfiz introuvable'; end if;
  insert into public.tahfiz_sessions(school_id,student_id,session_date,session_type,surah_id,from_verse,to_verse,score,observation,teacher_id,attendance_status,is_published)
  values(v_school,p_student_id,p_session_date,p_session_type,p_surah_id,p_from_verse,p_to_verse,p_score,nullif(btrim(p_observation),''),p_teacher_id,p_attendance_status,p_is_published)
  returning id into v_id;
  if p_progress_after is not null then
    if p_progress_after < 0 or p_progress_after > 100 then raise exception 'Progression Tahfiz invalide'; end if;
    update public.student_tahfiz set current_progress=p_progress_after,updated_at=now() where id=v_profile;
    if v_old is distinct from p_progress_after then
      insert into public.tahfiz_progress_history(school_id,student_tahfiz_id,student_id,progress,source_session_id,note,recorded_by)
      values(v_school,v_profile,p_student_id,p_progress_after,v_id,'Progression après séance',auth.uid());
    end if;
  end if;
  return v_id;
end $$;

create or replace function public.set_tahfiz_session_published(p_session_id uuid,p_published boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_school uuid;
begin
  select school_id into v_school from public.tahfiz_sessions where id=p_session_id;
  if v_school is null or not app.has_permission('tahfiz.manage',v_school) then raise exception 'Accès Tahfiz refusé'; end if;
  update public.tahfiz_sessions set is_published=p_published where id=p_session_id;
end $$;

create or replace function public.create_arabic_level(p_code text,p_name text,p_sequence_no integer default 0,p_description text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select u.school_id into v_school from public.users u where u.id=auth.uid();
  if v_school is null or not app.has_permission('arabic.manage',v_school) then raise exception 'Accès Arabe refusé'; end if;
  insert into public.arabic_levels(school_id,code,name,sequence_no,description) values(v_school,btrim(p_code),btrim(p_name),coalesce(p_sequence_no,0),nullif(btrim(p_description),'')) returning id into v_id;
  return v_id;
end $$;

create or replace function public.assign_student_arabic(p_student_id uuid,p_arabic_level_id uuid default null,p_teacher_id uuid default null,p_start_date date default null,p_progress numeric default 0,p_status text default 'active',p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select s.school_id into v_school from public.students s where s.id=p_student_id;
  if v_school is null or not app.has_permission('arabic.manage',v_school) then raise exception 'Accès Arabe refusé'; end if;
  if p_progress < 0 or p_progress > 100 then raise exception 'Progression Arabe invalide'; end if;
  insert into public.student_arabic(school_id,student_id,arabic_level_id,assigned_teacher_id,start_date,current_progress,status,notes)
  values(v_school,p_student_id,p_arabic_level_id,p_teacher_id,p_start_date,p_progress,p_status,nullif(btrim(p_notes),''))
  on conflict (student_id) do update set arabic_level_id=excluded.arabic_level_id,assigned_teacher_id=excluded.assigned_teacher_id,start_date=excluded.start_date,current_progress=excluded.current_progress,status=excluded.status,notes=excluded.notes,updated_at=now()
  returning id into v_id;
  insert into public.arabic_progress_history(school_id,student_arabic_id,student_id,progress,note,recorded_by)
  values(v_school,v_id,p_student_id,p_progress,'Initialisation / mise à jour du profil',auth.uid());
  return v_id;
end $$;

create or replace function public.record_arabic_session(p_student_id uuid,p_session_date date,p_activity_type text,p_topic text default null,p_score numeric default null,p_observation text default null,p_teacher_id uuid default null,p_attendance_status app.attendance_status default 'present',p_progress_after numeric default null,p_is_published boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid; v_profile uuid; v_old numeric;
begin
  select s.school_id into v_school from public.students s where s.id=p_student_id;
  if v_school is null or not app.has_permission('arabic.manage',v_school) then raise exception 'Accès Arabe refusé'; end if;
  select id,current_progress into v_profile,v_old from public.student_arabic where student_id=p_student_id and school_id=v_school;
  if v_profile is null then raise exception 'Profil Arabe introuvable'; end if;
  insert into public.arabic_sessions(school_id,student_id,session_date,activity_type,topic,score,observation,teacher_id,attendance_status,progress_after,is_published)
  values(v_school,p_student_id,p_session_date,btrim(p_activity_type),nullif(btrim(p_topic),''),p_score,nullif(btrim(p_observation),''),p_teacher_id,p_attendance_status,p_progress_after,p_is_published)
  returning id into v_id;
  if p_progress_after is not null then
    if p_progress_after < 0 or p_progress_after > 100 then raise exception 'Progression Arabe invalide'; end if;
    update public.student_arabic set current_progress=p_progress_after,updated_at=now() where id=v_profile;
    if v_old is distinct from p_progress_after then
      insert into public.arabic_progress_history(school_id,student_arabic_id,student_id,progress,source_session_id,note,recorded_by)
      values(v_school,v_profile,p_student_id,p_progress_after,v_id,'Progression après séance',auth.uid());
    end if;
  end if;
  return v_id;
end $$;

create or replace function public.create_arabic_evaluation(p_student_id uuid,p_period_id uuid default null,p_evaluation_date date default current_date,p_title text default 'Évaluation',p_skill_area text default null,p_score numeric default null,p_observation text default null,p_evaluator_id uuid default null,p_is_published boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select s.school_id into v_school from public.students s where s.id=p_student_id;
  if v_school is null or not app.has_permission('arabic.manage',v_school) then raise exception 'Accès Arabe refusé'; end if;
  insert into public.arabic_evaluations(school_id,student_id,period_id,evaluation_date,title,skill_area,score,observation,evaluator_id,is_published,published_at)
  values(v_school,p_student_id,p_period_id,p_evaluation_date,btrim(p_title),nullif(btrim(p_skill_area),''),p_score,nullif(btrim(p_observation),''),p_evaluator_id,p_is_published,case when p_is_published then now() end)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.set_arabic_evaluation_published(p_evaluation_id uuid,p_published boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_school uuid;
begin
  select school_id into v_school from public.arabic_evaluations where id=p_evaluation_id;
  if v_school is null or not app.has_permission('arabic.manage',v_school) then raise exception 'Accès Arabe refusé'; end if;
  update public.arabic_evaluations set is_published=p_published,published_at=case when p_published then coalesce(published_at,now()) else null end where id=p_evaluation_id;
end $$;

create or replace function public.get_specialized_staff(p_module text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_permission text; v_result jsonb;
begin
  select u.school_id into v_school from public.users u where u.id=auth.uid();
  if v_school is null then raise exception 'Établissement introuvable'; end if;
  v_permission := case when p_module='tahfiz' then 'tahfiz.view' when p_module='arabic' then 'arabic.view' else null end;
  if v_permission is null or not (app.has_permission(v_permission,v_school) or app.has_permission(replace(v_permission,'.view','.manage'),v_school) or app.is_super_admin()) then
    raise exception 'Accès responsable spécialisé refusé';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'first_name',e.first_name,'last_name',e.last_name,'job_title',e.job_title) order by e.last_name,e.first_name),'[]'::jsonb)
    into v_result
    from public.employees e
   where e.school_id=v_school and e.status='active';
  return v_result;
end $$;

create or replace function public.get_specialized_periods()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_result jsonb;
begin
  select u.school_id into v_school from public.users u where u.id=auth.uid();
  if v_school is null or not (app.has_permission('arabic.view',v_school) or app.has_permission('arabic.manage',v_school) or app.is_super_admin()) then
    raise exception 'Accès périodes Arabe refusé';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',ap.id,'name',ap.name,'school_year_id',ap.school_year_id) order by ap.start_date,ap.sequence_no),'[]'::jsonb)
    into v_result
    from public.academic_periods ap
    join public.school_years sy on sy.id=ap.school_year_id
   where sy.school_id=v_school;
  return v_result;
end $$;

-- Toutes les fonctions sensibles ne doivent pas être exécutables anonymement.
revoke all on function public.create_tahfiz_level(text,text,integer,text) from public,anon;
revoke all on function public.assign_student_tahfiz(uuid,uuid,uuid,date,numeric,text,text) from public,anon;
revoke all on function public.record_tahfiz_session(uuid,date,text,smallint,smallint,smallint,numeric,text,uuid,app.attendance_status,numeric,boolean) from public,anon;
revoke all on function public.set_tahfiz_session_published(uuid,boolean) from public,anon;
revoke all on function public.create_arabic_level(text,text,integer,text) from public,anon;
revoke all on function public.assign_student_arabic(uuid,uuid,uuid,date,numeric,text,text) from public,anon;
revoke all on function public.record_arabic_session(uuid,date,text,text,numeric,text,uuid,app.attendance_status,numeric,boolean) from public,anon;
revoke all on function public.create_arabic_evaluation(uuid,uuid,date,text,text,numeric,text,uuid,boolean) from public,anon;
revoke all on function public.set_arabic_evaluation_published(uuid,boolean) from public,anon;
grant execute on function public.create_tahfiz_level(text,text,integer,text) to authenticated;
grant execute on function public.assign_student_tahfiz(uuid,uuid,uuid,date,numeric,text,text) to authenticated;
grant execute on function public.record_tahfiz_session(uuid,date,text,smallint,smallint,smallint,numeric,text,uuid,app.attendance_status,numeric,boolean) to authenticated;
grant execute on function public.set_tahfiz_session_published(uuid,boolean) to authenticated;
grant execute on function public.create_arabic_level(text,text,integer,text) to authenticated;
grant execute on function public.assign_student_arabic(uuid,uuid,uuid,date,numeric,text,text) to authenticated;

grant execute on function public.record_arabic_session(uuid,date,text,text,numeric,text,uuid,app.attendance_status,numeric,boolean) to authenticated;
grant execute on function public.create_arabic_evaluation(uuid,uuid,date,text,text,numeric,text,uuid,boolean) to authenticated;
grant execute on function public.set_arabic_evaluation_published(uuid,boolean) to authenticated;
revoke all on function public.get_specialized_staff(text) from public,anon;
revoke all on function public.get_specialized_periods() from public,anon;
grant execute on function public.get_specialized_staff(text) to authenticated;
grant execute on function public.get_specialized_periods() to authenticated;

-- =========================================================
-- 6. RLS / grants — profils et journaux spécialisés
-- =========================================================
-- Policies génériques de la migration 014 sont retirées pour ces tables et remplacées.
drop policy if exists tahfiz_levels_select_secure on public.tahfiz_levels;
drop policy if exists tahfiz_levels_insert_secure on public.tahfiz_levels;
drop policy if exists tahfiz_levels_update_secure on public.tahfiz_levels;
drop policy if exists tahfiz_levels_delete_secure on public.tahfiz_levels;
drop policy if exists student_tahfiz_select_secure on public.student_tahfiz;
drop policy if exists student_tahfiz_insert_secure on public.student_tahfiz;
drop policy if exists student_tahfiz_update_secure on public.student_tahfiz;
drop policy if exists student_tahfiz_delete_secure on public.student_tahfiz;
drop policy if exists tahfiz_sessions_select_secure on public.tahfiz_sessions;
drop policy if exists tahfiz_sessions_insert_secure on public.tahfiz_sessions;
drop policy if exists tahfiz_sessions_update_secure on public.tahfiz_sessions;
drop policy if exists tahfiz_sessions_delete_secure on public.tahfiz_sessions;
drop policy if exists islamic_training_select_secure on public.islamic_training;
drop policy if exists islamic_training_insert_secure on public.islamic_training;
drop policy if exists islamic_training_update_secure on public.islamic_training;
drop policy if exists islamic_training_delete_secure on public.islamic_training;

alter table public.arabic_levels enable row level security;
alter table public.student_arabic enable row level security;
alter table public.arabic_sessions enable row level security;
alter table public.arabic_evaluations enable row level security;
alter table public.arabic_progress_history enable row level security;
alter table public.tahfiz_progress_history enable row level security;

create policy tahfiz_levels_view on public.tahfiz_levels for select to authenticated using (app.has_permission('tahfiz.view',school_id) or app.has_permission('tahfiz.manage',school_id) or app.is_super_admin());
create policy tahfiz_levels_manage on public.tahfiz_levels for all to authenticated using (app.has_permission('tahfiz.manage',school_id) or app.is_super_admin()) with check (app.has_permission('tahfiz.manage',school_id) or app.is_super_admin());

create policy student_tahfiz_view on public.student_tahfiz for select to authenticated using (
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.is_teacher_for_student(student_id)
  or app.has_permission('tahfiz.view',school_id) or app.has_permission('tahfiz.manage',school_id) or app.is_super_admin()
);
create policy student_tahfiz_manage on public.student_tahfiz for all to authenticated using (app.has_permission('tahfiz.manage',school_id) or app.is_super_admin()) with check (app.has_permission('tahfiz.manage',school_id) or app.is_super_admin());

create policy tahfiz_sessions_view on public.tahfiz_sessions for select to authenticated using (
  app.has_permission('tahfiz.view',school_id) or app.has_permission('tahfiz.manage',school_id) or app.is_super_admin()
  or app.is_teacher_for_student(student_id)
  or ((app.is_self_student(student_id) or app.is_parent_of_student(student_id)) and is_published)
);
create policy tahfiz_sessions_manage on public.tahfiz_sessions for all to authenticated using (app.has_permission('tahfiz.manage',school_id) or app.is_super_admin()) with check (app.has_permission('tahfiz.manage',school_id) or app.is_super_admin());

create policy tahfiz_progress_history_view on public.tahfiz_progress_history for select to authenticated using (
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.is_teacher_for_student(student_id)
  or app.has_permission('tahfiz.view',school_id) or app.has_permission('tahfiz.manage',school_id) or app.is_super_admin()
);

create policy arabic_levels_view on public.arabic_levels for select to authenticated using (app.has_permission('arabic.view',school_id) or app.has_permission('arabic.manage',school_id) or app.is_super_admin());
create policy arabic_levels_manage on public.arabic_levels for all to authenticated using (app.has_permission('arabic.manage',school_id) or app.is_super_admin()) with check (app.has_permission('arabic.manage',school_id) or app.is_super_admin());

create policy student_arabic_view on public.student_arabic for select to authenticated using (
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.is_teacher_for_student(student_id)
  or app.has_permission('arabic.view',school_id) or app.has_permission('arabic.manage',school_id) or app.is_super_admin()
);
create policy student_arabic_manage on public.student_arabic for all to authenticated using (app.has_permission('arabic.manage',school_id) or app.is_super_admin()) with check (app.has_permission('arabic.manage',school_id) or app.is_super_admin());

create policy arabic_sessions_view on public.arabic_sessions for select to authenticated using (
  app.has_permission('arabic.view',school_id) or app.has_permission('arabic.manage',school_id) or app.is_super_admin()
  or app.is_teacher_for_student(student_id)
  or ((app.is_self_student(student_id) or app.is_parent_of_student(student_id)) and is_published)
);
create policy arabic_sessions_manage on public.arabic_sessions for all to authenticated using (app.has_permission('arabic.manage',school_id) or app.is_super_admin()) with check (app.has_permission('arabic.manage',school_id) or app.is_super_admin());

create policy arabic_evaluations_view on public.arabic_evaluations for select to authenticated using (
  app.has_permission('arabic.view',school_id) or app.has_permission('arabic.manage',school_id) or app.is_super_admin()
  or app.is_teacher_for_student(student_id)
  or ((app.is_self_student(student_id) or app.is_parent_of_student(student_id)) and is_published)
);
create policy arabic_evaluations_manage on public.arabic_evaluations for all to authenticated using (app.has_permission('arabic.manage',school_id) or app.is_super_admin()) with check (app.has_permission('arabic.manage',school_id) or app.is_super_admin());

create policy arabic_progress_history_view on public.arabic_progress_history for select to authenticated using (
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.is_teacher_for_student(student_id)
  or app.has_permission('arabic.view',school_id) or app.has_permission('arabic.manage',school_id) or app.is_super_admin()
);

-- Les tables de formation passent par les RPC pour les écritures sensibles.
revoke insert,update,delete on public.tahfiz_levels,public.student_tahfiz,public.tahfiz_sessions,public.tahfiz_progress_history from authenticated;
revoke insert,update,delete on public.arabic_levels,public.student_arabic,public.arabic_sessions,public.arabic_evaluations,public.arabic_progress_history from authenticated;
grant select on public.tahfiz_levels,public.student_tahfiz,public.tahfiz_sessions,public.tahfiz_progress_history to authenticated;
grant select on public.arabic_levels,public.student_arabic,public.arabic_sessions,public.arabic_evaluations,public.arabic_progress_history to authenticated;

-- islamic_training reste réservé au module Arabe/formation islamique, sans exposer des écritures directes.
revoke insert,update,delete on public.islamic_training from authenticated;
grant select on public.islamic_training to authenticated;

-- =========================================================
-- 7. Dossier élève — agrégat Tahfiz / Arabe
-- =========================================================
create or replace function public.get_student_tahfiz_arabic(p_student_id uuid)
returns jsonb language sql security invoker set search_path='' as $$
select jsonb_build_object(
  'tahfiz', (
    select jsonb_build_object(
      'profile', to_jsonb(st),
      'level', (select to_jsonb(tl) from public.tahfiz_levels tl where tl.id=st.tahfiz_level_id),
      'sessions', coalesce((select jsonb_agg(to_jsonb(ts) order by ts.session_date desc, ts.created_at desc) from public.tahfiz_sessions ts where ts.student_id=p_student_id and (ts.is_published or app.has_permission('tahfiz.view',ts.school_id) or app.has_permission('tahfiz.manage',ts.school_id) or app.is_super_admin()) limit 12),'[]'::jsonb),
      'progress_history', coalesce((select jsonb_agg(to_jsonb(ph) order by ph.recorded_at desc) from public.tahfiz_progress_history ph where ph.student_id=p_student_id limit 12),'[]'::jsonb)
    )
    from public.student_tahfiz st where st.student_id=p_student_id limit 1
  ),
  'arabic', (
    select jsonb_build_object(
      'profile', to_jsonb(sa),
      'level', (select to_jsonb(al) from public.arabic_levels al where al.id=sa.arabic_level_id),
      'sessions', coalesce((select jsonb_agg(to_jsonb(s) order by s.session_date desc, s.created_at desc) from public.arabic_sessions s where s.student_id=p_student_id and (s.is_published or app.has_permission('arabic.view',s.school_id) or app.has_permission('arabic.manage',s.school_id) or app.is_super_admin()) limit 12),'[]'::jsonb),
      'evaluations', coalesce((select jsonb_agg(to_jsonb(e) order by e.evaluation_date desc, e.created_at desc) from public.arabic_evaluations e where e.student_id=p_student_id and (e.is_published or app.has_permission('arabic.view',e.school_id) or app.has_permission('arabic.manage',e.school_id) or app.is_super_admin()) limit 12),'[]'::jsonb),
      'progress_history', coalesce((select jsonb_agg(to_jsonb(ph) order by ph.recorded_at desc) from public.arabic_progress_history ph where ph.student_id=p_student_id limit 12),'[]'::jsonb)
    )
    from public.student_arabic sa where sa.student_id=p_student_id limit 1
  )
)
$$;
revoke all on function public.get_student_tahfiz_arabic(uuid) from public,anon;
grant execute on function public.get_student_tahfiz_arabic(uuid) to authenticated;

commit;
