begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- SIGIA-AMINE — Migration 029
-- Étape 21 : Wushu
-- Renforce le socle Wushu existant sans inventer de barème officiel.
-- Les niveaux, grades, critères et échelles restent paramétrables.

-- =========================================================
-- 1. RBAC
-- =========================================================
insert into public.permissions(code,name,module,action,description) values
('wushu.view','Consulter Wushu','wushu','view','Consulter les profils, séances, évaluations et résultats Wushu autorisés'),
('wushu.publish','Publier Wushu','wushu','publish','Publier les évaluations et résultats Wushu')
on conflict (code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r cross join public.permissions p
where r.code='wushu_manager' and p.code in ('wushu.view','wushu.manage','wushu.publish')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r cross join public.permissions p
where r.code in ('direction','founder','super_admin') and p.code in ('wushu.view','wushu.manage','wushu.publish')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r cross join public.permissions p
where r.code='academic_director' and p.code in ('wushu.view')
on conflict do nothing;

-- =========================================================
-- 2. Durcissement des tables Wushu existantes
-- =========================================================
alter table public.wushu_groups
  add column if not exists code text,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.student_wushu
  add column if not exists current_progress numeric(6,2) not null default 0,
  add column if not exists notes text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.wushu_sessions
  add column if not exists session_type text not null default 'training',
  add column if not exists progress_after numeric(6,2),
  add column if not exists is_published boolean not null default false,
  add column if not exists created_at timestamptz not null default now();

alter table public.wushu_evaluations
  add column if not exists max_score numeric(8,2),
  add column if not exists skill_area text,
  add column if not exists is_published boolean not null default false,
  add column if not exists published_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.wushu_competitions
  add column if not exists status text not null default 'draft',
  add column if not exists is_published boolean not null default false,
  add column if not exists published_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.wushu_competition_results
  add column if not exists medal text,
  add column if not exists observation text,
  add column if not exists is_published boolean not null default false,
  add column if not exists created_at timestamptz not null default now();

alter table public.wushu_groups
  add constraint wushu_groups_code_ck check (code is null or length(btrim(code)) between 1 and 60);
alter table public.student_wushu
  add constraint student_wushu_progress_ck check (current_progress between 0 and 100);
alter table public.wushu_sessions
  add constraint wushu_sessions_type_ck check (session_type in ('training','technique','exam_preparation','competition_preparation','other'));
alter table public.wushu_sessions
  add constraint wushu_sessions_progress_ck check (progress_after is null or progress_after between 0 and 100);
alter table public.wushu_evaluations
  add constraint wushu_evaluations_score_ck check (score is null or score >= 0);
alter table public.wushu_evaluations
  add constraint wushu_evaluations_max_score_ck check (max_score is null or max_score > 0);
alter table public.wushu_evaluations
  add constraint wushu_evaluations_score_max_ck check (score is null or max_score is null or score <= max_score);
alter table public.wushu_competitions
  add constraint wushu_competitions_status_ck check (status in ('draft','published','closed'));
alter table public.wushu_competition_results
  add constraint wushu_results_rank_ck check (rank is null or rank >= 1);

create unique index if not exists uq_wushu_groups_school_code_ci
  on public.wushu_groups(school_id, lower(code))
  where code is not null;
create unique index if not exists uq_wushu_groups_school_name_ci
  on public.wushu_groups(school_id, lower(name));
create index if not exists idx_wushu_groups_school_active
  on public.wushu_groups(school_id,is_active,name);
create index if not exists idx_student_wushu_school_group
  on public.student_wushu(school_id,group_id,status);
create index if not exists idx_wushu_sessions_school_group_date
  on public.wushu_sessions(school_id,group_id,session_date desc);
create index if not exists idx_wushu_attendance_student_session
  on public.wushu_attendance(student_id,session_id);
create index if not exists idx_wushu_evaluations_student_date
  on public.wushu_evaluations(student_id,evaluation_date desc);
create index if not exists idx_wushu_evaluations_school_date
  on public.wushu_evaluations(school_id,evaluation_date desc);
create index if not exists idx_wushu_competitions_school_date
  on public.wushu_competitions(school_id,competition_date desc);
create index if not exists idx_wushu_results_student
  on public.wushu_competition_results(student_id,competition_id);
create unique index if not exists uq_wushu_competition_results_competition_student
  on public.wushu_competition_results(competition_id,student_id);

-- =========================================================
-- 3. Historique de progression / grades
-- =========================================================
create table if not exists public.wushu_progress_history(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_wushu_id uuid not null references public.student_wushu(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  progress numeric(6,2) not null check(progress between 0 and 100),
  grade text,
  source_session_id uuid references public.wushu_sessions(id) on delete set null,
  source_evaluation_id uuid references public.wushu_evaluations(id) on delete set null,
  note text,
  recorded_by uuid references public.users(id) on delete set null,
  recorded_at timestamptz not null default now()
);
create index if not exists idx_wushu_progress_history_student
  on public.wushu_progress_history(student_id,recorded_at desc);

-- =========================================================
-- 4. Triggers de cohérence
-- =========================================================
create or replace function app.validate_wushu_profile()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if not exists(select 1 from public.students s where s.id=new.student_id and s.school_id=new.school_id) then
    raise exception 'student_wushu: élève hors établissement';
  end if;
  if new.group_id is not null and not exists(select 1 from public.wushu_groups g where g.id=new.group_id and g.school_id=new.school_id) then
    raise exception 'student_wushu: groupe Wushu hors établissement';
  end if;
  if new.status = 'active' and new.group_id is null then
    raise exception 'student_wushu: un profil actif doit être affecté à un groupe';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_wushu_profile on public.student_wushu;
create trigger trg_validate_wushu_profile
before insert or update on public.student_wushu
for each row execute function app.validate_wushu_profile();

create or replace function app.validate_wushu_group()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.coach_employee_id is not null and not exists(
    select 1 from public.employees e
    where e.id=new.coach_employee_id and e.school_id=new.school_id and e.status='active'
  ) then
    raise exception 'wushu_groups: coach invalide ou hors établissement';
  end if;
  if length(btrim(new.name)) = 0 then
    raise exception 'wushu_groups: nom obligatoire';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_wushu_group on public.wushu_groups;
create trigger trg_validate_wushu_group
before insert or update on public.wushu_groups
for each row execute function app.validate_wushu_group();

create or replace function app.validate_wushu_session()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.group_id is null then
    raise exception 'wushu_sessions: groupe obligatoire';
  end if;
  if not exists(select 1 from public.wushu_groups g where g.id=new.group_id and g.school_id=new.school_id and g.is_active) then
    raise exception 'wushu_sessions: groupe invalide ou inactif';
  end if;
  if new.coach_employee_id is not null and not exists(
    select 1 from public.employees e
    where e.id=new.coach_employee_id and e.school_id=new.school_id and e.status='active'
  ) then
    raise exception 'wushu_sessions: coach invalide';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_wushu_session on public.wushu_sessions;
create trigger trg_validate_wushu_session
before insert or update on public.wushu_sessions
for each row execute function app.validate_wushu_session();

create or replace function app.validate_wushu_attendance()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_school uuid; v_group uuid; v_status text; v_start date;
begin
  select ws.school_id, ws.group_id into v_school, v_group from public.wushu_sessions ws where ws.id=new.session_id;
  if v_school is null or not exists(select 1 from public.students s where s.id=new.student_id and s.school_id=v_school) then
    raise exception 'wushu_attendance: étudiant hors établissement';
  end if;
  select sw.status, sw.start_date into v_status, v_start
  from public.student_wushu sw where sw.student_id=new.student_id and sw.school_id=v_school;
  if v_status is null or v_status not in ('active','completed') then
    raise exception 'wushu_attendance: élève non inscrit au Wushu';
  end if;
  if not exists(select 1 from public.student_wushu sw where sw.student_id=new.student_id and sw.school_id=v_school and sw.group_id=v_group) then
    raise exception 'wushu_attendance: élève non affecté à ce groupe';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_wushu_attendance on public.wushu_attendance;
create trigger trg_validate_wushu_attendance
before insert or update on public.wushu_attendance
for each row execute function app.validate_wushu_attendance();

create or replace function app.validate_wushu_evaluation()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if not exists(select 1 from public.students s where s.id=new.student_id and s.school_id=new.school_id) then
    raise exception 'wushu_evaluations: élève hors établissement';
  end if;
  if not exists(select 1 from public.student_wushu sw where sw.student_id=new.student_id and sw.school_id=new.school_id) then
    raise exception 'wushu_evaluations: élève non inscrit au Wushu';
  end if;
  if new.evaluator_id is not null and not exists(select 1 from public.employees e where e.id=new.evaluator_id and e.school_id=new.school_id and e.status='active') then
    raise exception 'wushu_evaluations: évaluateur invalide';
  end if;
  if new.is_published and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_wushu_evaluation on public.wushu_evaluations;
create trigger trg_validate_wushu_evaluation
before insert or update on public.wushu_evaluations
for each row execute function app.validate_wushu_evaluation();

create or replace function app.validate_wushu_competition()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if length(btrim(new.name)) = 0 then raise exception 'wushu_competitions: nom obligatoire'; end if;
  if new.is_published and new.published_at is null then new.published_at := now(); end if;
  return new;
end $$;

drop trigger if exists trg_validate_wushu_competition on public.wushu_competitions;
create trigger trg_validate_wushu_competition
before insert or update on public.wushu_competitions
for each row execute function app.validate_wushu_competition();

create or replace function app.validate_wushu_result()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_school uuid;
begin
  select c.school_id into v_school from public.wushu_competitions c where c.id=new.competition_id;
  if v_school is null or not exists(select 1 from public.students s where s.id=new.student_id and s.school_id=v_school) then
    raise exception 'wushu_competition_results: élève hors établissement';
  end if;
  if not exists(select 1 from public.student_wushu sw where sw.student_id=new.student_id and sw.school_id=v_school) then
    raise exception 'wushu_competition_results: élève non inscrit au Wushu';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_wushu_result on public.wushu_competition_results;
create trigger trg_validate_wushu_result
before insert or update on public.wushu_competition_results
for each row execute function app.validate_wushu_result();

create or replace function app.wushu_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at := now(); return new; end $$;

drop trigger if exists trg_wushu_groups_updated_at on public.wushu_groups;
create trigger trg_wushu_groups_updated_at before update on public.wushu_groups for each row execute function app.wushu_updated_at();
drop trigger if exists trg_student_wushu_updated_at on public.student_wushu;
create trigger trg_student_wushu_updated_at before update on public.student_wushu for each row execute function app.wushu_updated_at();
drop trigger if exists trg_wushu_eval_updated_at on public.wushu_evaluations;
create trigger trg_wushu_eval_updated_at before update on public.wushu_evaluations for each row execute function app.wushu_updated_at();
drop trigger if exists trg_wushu_comp_updated_at on public.wushu_competitions;
create trigger trg_wushu_comp_updated_at before update on public.wushu_competitions for each row execute function app.wushu_updated_at();

-- =========================================================
-- 5. Historique automatique de progression
-- =========================================================
create or replace function app.record_wushu_progress_from_profile()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.current_progress is distinct from old.current_progress or new.current_grade is distinct from old.current_grade then
    insert into public.wushu_progress_history(
      school_id,student_wushu_id,student_id,progress,grade,note,recorded_by
    ) values (
      new.school_id,new.id,new.student_id,new.current_progress,new.current_grade,'Mise à jour du profil Wushu',auth.uid()
    );
  end if;
  return new;
end;


$$;

drop trigger if exists trg_record_wushu_progress on public.student_wushu;
create trigger trg_record_wushu_progress
after update of current_progress,current_grade on public.student_wushu
for each row execute function app.record_wushu_progress_from_profile();

-- =========================================================
-- 6. RPC métier sécurisées
-- =========================================================
create or replace function public.create_wushu_group(
  p_code text, p_name text, p_level text default null, p_coach_employee_id uuid default null, p_schedule jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.users where id=auth.uid();
  if v_school is null then raise exception 'Utilisateur sans établissement'; end if;
  if not (app.has_permission('wushu.manage',v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  insert into public.wushu_groups(school_id,code,name,level,coach_employee_id,schedule)
  values(v_school,nullif(btrim(p_code),''),btrim(p_name),nullif(btrim(p_level),''),p_coach_employee_id,coalesce(p_schedule,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.assign_student_wushu(
  p_student_id uuid, p_group_id uuid, p_current_grade text default null, p_start_date date default null,
  p_status text default 'active', p_progress numeric default 0, p_notes text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null then raise exception 'Élève introuvable'; end if;
  if not (app.has_permission('wushu.manage',v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  if not exists(select 1 from public.wushu_groups where id=p_group_id and school_id=v_school and is_active) then raise exception 'Groupe Wushu invalide'; end if;
  insert into public.student_wushu(school_id,student_id,group_id,current_grade,start_date,status,current_progress,notes)
  values(v_school,p_student_id,p_group_id,nullif(btrim(p_current_grade),''),p_start_date,p_status,p_progress,p_notes)
  on conflict(student_id) do update set group_id=excluded.group_id,current_grade=excluded.current_grade,start_date=excluded.start_date,status=excluded.status,current_progress=excluded.current_progress,notes=excluded.notes,updated_at=now()
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.create_wushu_session(
  p_group_id uuid, p_session_date date, p_session_type text, p_topic text default null,
  p_coach_employee_id uuid default null, p_notes text default null, p_progress_after numeric default null,
  p_is_published boolean default false
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.wushu_groups where id=p_group_id;
  if v_school is null then raise exception 'Groupe Wushu introuvable'; end if;
  if not (app.has_permission('wushu.manage',v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  insert into public.wushu_sessions(school_id,group_id,session_date,session_type,topic,coach_employee_id,notes,progress_after,is_published)
  values(v_school,p_group_id,p_session_date,p_session_type,nullif(btrim(p_topic),''),p_coach_employee_id,p_notes,p_progress_after,p_is_published)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.record_wushu_attendance(
  p_session_id uuid, p_student_id uuid, p_status app.attendance_status
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.wushu_sessions where id=p_session_id;
  if v_school is null then raise exception 'Séance Wushu introuvable'; end if;
  if not (app.has_permission('wushu.manage',v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  insert into public.wushu_attendance(session_id,student_id,status) values(p_session_id,p_student_id,p_status)
  on conflict(session_id,student_id) do update set status=excluded.status
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.create_wushu_evaluation(
  p_student_id uuid, p_evaluation_date date, p_evaluation_type text, p_score numeric default null,
  p_max_score numeric default null, p_grade_awarded text default null, p_skill_area text default null,
  p_observation text default null, p_evaluator_id uuid default null, p_is_published boolean default false
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null then raise exception 'Élève introuvable'; end if;
  if not (app.has_permission('wushu.manage',v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  insert into public.wushu_evaluations(school_id,student_id,evaluation_date,evaluation_type,score,max_score,grade_awarded,skill_area,observation,evaluator_id,is_published,published_at)
  values(v_school,p_student_id,p_evaluation_date,btrim(p_evaluation_type),p_score,p_max_score,nullif(btrim(p_grade_awarded),''),nullif(btrim(p_skill_area),''),p_observation,p_evaluator_id,p_is_published,case when p_is_published then now() else null end)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.set_wushu_evaluation_published(p_evaluation_id uuid,p_published boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_school uuid;
begin
  select school_id into v_school from public.wushu_evaluations where id=p_evaluation_id;
  if v_school is null then raise exception 'Évaluation introuvable'; end if;
  if not (app.has_permission('wushu.publish',v_school) or app.is_super_admin()) then raise exception 'Permission de publication Wushu insuffisante'; end if;
  if p_published then
    update public.wushu_evaluations set is_published=true,published_at=now() where id=p_evaluation_id;
  else
    update public.wushu_evaluations set is_published=false,published_at=null where id=p_evaluation_id;
  end if;
end $$;

create or replace function public.create_wushu_competition(
  p_name text, p_competition_date date, p_location text default null, p_notes text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.users where id=auth.uid();
  if v_school is null then raise exception 'Utilisateur sans établissement'; end if;
  if not (app.has_permission('wushu.manage',v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  insert into public.wushu_competitions(school_id,name,competition_date,location,notes)
  values(v_school,btrim(p_name),p_competition_date,nullif(btrim(p_location),''),p_notes)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.record_wushu_competition_result(
  p_competition_id uuid,p_student_id uuid,p_category text default null,p_result text default null,
  p_rank integer default null,p_medal text default null,p_observation text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.wushu_competitions where id=p_competition_id;
  if v_school is null then raise exception 'Compétition introuvable'; end if;
  if not (app.has_permission('wushu.manage',v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  insert into public.wushu_competition_results(competition_id,student_id,category,result,rank,medal,observation)
  values(p_competition_id,p_student_id,nullif(btrim(p_category),''),nullif(btrim(p_result),''),p_rank,nullif(btrim(p_medal),''),p_observation)
  on conflict (competition_id,student_id) do update set category=excluded.category,result=excluded.result,rank=excluded.rank,medal=excluded.medal,observation=excluded.observation
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.publish_wushu_competition(p_competition_id uuid,p_published boolean default true)
returns void language plpgsql security definer set search_path='' as $$
declare v_school uuid;
begin
  select school_id into v_school from public.wushu_competitions where id=p_competition_id;
  if v_school is null then raise exception 'Compétition introuvable'; end if;
  if not (app.has_permission('wushu.publish',v_school) or app.is_super_admin()) then raise exception 'Permission de publication Wushu insuffisante'; end if;
  if p_published then
    update public.wushu_competitions set status='published',is_published=true,published_at=now() where id=p_competition_id;
    update public.wushu_competition_results set is_published=true where competition_id=p_competition_id;
  else
    update public.wushu_competitions set status='draft',is_published=false,published_at=null where id=p_competition_id;
    update public.wushu_competition_results set is_published=false where competition_id=p_competition_id;
  end if;
end $$;

-- =========================================================
-- 7. Lecture sécurisée pour le dossier élève / dashboard
-- =========================================================
create or replace function public.get_student_wushu(p_student_id uuid)
returns jsonb language sql security invoker set search_path=''
as $$
select jsonb_build_object(
  'profile', (
    select jsonb_build_object('id',sw.id,'student_id',sw.student_id,'group_id',sw.group_id,'group_name',wg.name,'group_level',wg.level,'current_grade',sw.current_grade,'current_progress',sw.current_progress,'start_date',sw.start_date,'status',sw.status,'notes',sw.notes)
    from public.student_wushu sw
    left join public.wushu_groups wg on wg.id=sw.group_id
    where sw.student_id=p_student_id
    limit 1
  ),
  'sessions', coalesce((select jsonb_agg(jsonb_build_object('id',ws.id,'session_date',ws.session_date,'session_type',ws.session_type,'topic',ws.topic,'progress_after',ws.progress_after,'is_published',ws.is_published) order by ws.session_date desc) from public.wushu_sessions ws join public.wushu_attendance wa on wa.session_id=ws.id where wa.student_id=p_student_id and (ws.is_published or app.is_self_student(p_student_id) or app.is_parent_of_student(p_student_id) or app.has_permission('wushu.view',ws.school_id) or app.has_permission('wushu.manage',ws.school_id) or app.is_super_admin()) limit 30),'[]'::jsonb),
  'evaluations', coalesce((select jsonb_agg(jsonb_build_object('id',we.id,'evaluation_date',we.evaluation_date,'evaluation_type',we.evaluation_type,'score',we.score,'max_score',we.max_score,'grade_awarded',we.grade_awarded,'skill_area',we.skill_area,'observation',we.observation,'is_published',we.is_published) order by we.evaluation_date desc) from public.wushu_evaluations we where we.student_id=p_student_id and (we.is_published or app.is_self_student(p_student_id) or app.is_parent_of_student(p_student_id) or app.has_permission('wushu.view',we.school_id) or app.has_permission('wushu.manage',we.school_id) or app.is_super_admin()) limit 30),'[]'::jsonb),
  'competitions', coalesce((select jsonb_agg(jsonb_build_object('competition_id',c.id,'name',c.name,'competition_date',c.competition_date,'location',c.location,'category',r.category,'result',r.result,'rank',r.rank,'medal',r.medal,'observation',r.observation) order by c.competition_date desc) from public.wushu_competition_results r join public.wushu_competitions c on c.id=r.competition_id where r.student_id=p_student_id and (c.is_published or app.is_self_student(p_student_id) or app.is_parent_of_student(p_student_id) or app.has_permission('wushu.view',c.school_id) or app.has_permission('wushu.manage',c.school_id) or app.is_super_admin()) limit 30),'[]'::jsonb)
)
where exists(select 1 from public.students s where s.id=p_student_id);
$$;

create or replace function public.get_wushu_dashboard()
returns jsonb language sql security invoker set search_path='' as $$
select jsonb_build_object(
  'groups', (select count(*) from public.wushu_groups g where g.is_active and (app.has_permission('wushu.view',g.school_id) or app.has_permission('wushu.manage',g.school_id) or app.has_role_code('direction',g.school_id) or app.has_role_code('founder',g.school_id) or app.is_super_admin())),
  'students', (select count(*) from public.student_wushu sw where sw.status='active' and (app.has_permission('wushu.view',sw.school_id) or app.has_permission('wushu.manage',sw.school_id) or app.has_role_code('direction',sw.school_id) or app.has_role_code('founder',sw.school_id) or app.is_super_admin())),
  'sessions', (select count(*) from public.wushu_sessions ws where ws.session_date >= current_date - 30 and (app.has_permission('wushu.view',ws.school_id) or app.has_permission('wushu.manage',ws.school_id) or app.has_role_code('direction',ws.school_id) or app.has_role_code('founder',ws.school_id) or app.is_super_admin())),
  'evaluations', (select count(*) from public.wushu_evaluations we where we.evaluation_date >= current_date - 90 and (app.has_permission('wushu.view',we.school_id) or app.has_permission('wushu.manage',we.school_id) or app.has_role_code('direction',we.school_id) or app.has_role_code('founder',we.school_id) or app.is_super_admin())),
  'competitions', (select count(*) from public.wushu_competitions c where c.competition_date >= current_date - 365 and (app.has_permission('wushu.view',c.school_id) or app.has_permission('wushu.manage',c.school_id) or app.has_role_code('direction',c.school_id) or app.has_role_code('founder',c.school_id) or app.is_super_admin()))
);
$$;

-- =========================================================
-- 8. RLS spécialisé : on remplace les policies génériques Wushu
-- =========================================================

drop policy if exists wushu_groups_select_secure on public.wushu_groups;
drop policy if exists wushu_groups_insert_secure on public.wushu_groups;
drop policy if exists wushu_groups_update_secure on public.wushu_groups;
drop policy if exists wushu_groups_delete_secure on public.wushu_groups;
create policy wushu_groups_select_step21 on public.wushu_groups for select to authenticated using(
  app.has_permission('wushu.view',school_id) or app.has_permission('wushu.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or
  exists(select 1 from public.student_wushu sw where sw.group_id=wushu_groups.id and (app.is_self_student(sw.student_id) or app.is_parent_of_student(sw.student_id))) or app.is_super_admin()
);

-- Pas de mutations directes : les RPC assurent les contrôles métier.
drop policy if exists student_wushu_select_secure on public.student_wushu;
drop policy if exists student_wushu_insert_secure on public.student_wushu;
drop policy if exists student_wushu_update_secure on public.student_wushu;
drop policy if exists student_wushu_delete_secure on public.student_wushu;
create policy student_wushu_select_step21 on public.student_wushu for select to authenticated using(
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.has_permission('wushu.view',school_id) or app.has_permission('wushu.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);

drop policy if exists wushu_sessions_select_secure on public.wushu_sessions;
drop policy if exists wushu_sessions_insert_secure on public.wushu_sessions;
drop policy if exists wushu_sessions_update_secure on public.wushu_sessions;
drop policy if exists wushu_sessions_delete_secure on public.wushu_sessions;
create policy wushu_sessions_select_step21 on public.wushu_sessions for select to authenticated using(
  app.has_permission('wushu.view',school_id) or app.has_permission('wushu.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or
  exists(select 1 from public.student_wushu sw join public.wushu_attendance wa on wa.student_id=sw.student_id where wa.session_id=wushu_sessions.id and (app.is_self_student(sw.student_id) or app.is_parent_of_student(sw.student_id))) or app.is_super_admin()
);

drop policy if exists wushu_attendance_secure on public.wushu_attendance;
drop policy if exists wushu_attendance_manage on public.wushu_attendance;
create policy wushu_attendance_select_step21 on public.wushu_attendance for select to authenticated using(
  exists(select 1 from public.wushu_sessions ws where ws.id=session_id and (app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.has_permission('wushu.view',ws.school_id) or app.has_permission('wushu.manage',ws.school_id) or app.has_role_code('direction',ws.school_id) or app.has_role_code('founder',ws.school_id) or app.is_super_admin()))
);

drop policy if exists wushu_evaluations_select_secure on public.wushu_evaluations;
drop policy if exists wushu_evaluations_insert_secure on public.wushu_evaluations;
drop policy if exists wushu_evaluations_update_secure on public.wushu_evaluations;
drop policy if exists wushu_evaluations_delete_secure on public.wushu_evaluations;
create policy wushu_evaluations_select_step21 on public.wushu_evaluations for select to authenticated using(
  is_published or app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.has_permission('wushu.view',school_id) or app.has_permission('wushu.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);

drop policy if exists wushu_competitions_select_secure on public.wushu_competitions;
drop policy if exists wushu_competitions_insert_secure on public.wushu_competitions;
drop policy if exists wushu_competitions_update_secure on public.wushu_competitions;
drop policy if exists wushu_competitions_delete_secure on public.wushu_competitions;
create policy wushu_competitions_select_step21 on public.wushu_competitions for select to authenticated using(
  is_published or app.has_permission('wushu.view',school_id) or app.has_permission('wushu.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or exists(select 1 from public.wushu_competition_results r where r.competition_id=wushu_competitions.id and (app.is_self_student(r.student_id) or app.is_parent_of_student(r.student_id))) or app.is_super_admin()
);

drop policy if exists wushu_results_secure on public.wushu_competition_results;
drop policy if exists wushu_results_manage on public.wushu_competition_results;
create policy wushu_results_select_step21 on public.wushu_competition_results for select to authenticated using(
  exists(select 1 from public.wushu_competitions c where c.id=competition_id and (is_published or c.is_published or app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.has_permission('wushu.view',c.school_id) or app.has_permission('wushu.manage',c.school_id) or app.has_role_code('direction',c.school_id) or app.has_role_code('founder',c.school_id) or app.is_super_admin()))
);

-- Quran-like read-only metadata is not relevant; Wushu is explicitly read-only via authenticated except RPCs.
revoke insert, update, delete on public.wushu_groups, public.student_wushu, public.wushu_sessions, public.wushu_attendance, public.wushu_evaluations, public.wushu_competitions, public.wushu_competition_results, public.wushu_progress_history from authenticated;
grant select on public.wushu_groups, public.student_wushu, public.wushu_sessions, public.wushu_attendance, public.wushu_evaluations, public.wushu_competitions, public.wushu_competition_results, public.wushu_progress_history to authenticated;
revoke all on function public.create_wushu_group(text,text,text,uuid,jsonb) from public;
revoke all on function public.assign_student_wushu(uuid,uuid,text,date,text,numeric,text) from public;
revoke all on function public.create_wushu_session(uuid,date,text,text,uuid,text,numeric,boolean) from public;
revoke all on function public.record_wushu_attendance(uuid,uuid,app.attendance_status) from public;
revoke all on function public.create_wushu_evaluation(uuid,date,text,numeric,numeric,text,text,text,uuid,boolean) from public;
revoke all on function public.set_wushu_evaluation_published(uuid,boolean) from public;
revoke all on function public.create_wushu_competition(text,date,text,text) from public;
revoke all on function public.record_wushu_competition_result(uuid,uuid,text,text,integer,text,text) from public;
revoke all on function public.publish_wushu_competition(uuid,boolean) from public;
revoke all on function public.get_student_wushu(uuid) from public;
revoke all on function public.get_wushu_dashboard() from public;
grant execute on function public.create_wushu_group(text,text,text,uuid,jsonb) to authenticated;
grant execute on function public.assign_student_wushu(uuid,uuid,text,date,text,numeric,text) to authenticated;
grant execute on function public.create_wushu_session(uuid,date,text,text,uuid,text,numeric,boolean) to authenticated;
grant execute on function public.record_wushu_attendance(uuid,uuid,app.attendance_status) to authenticated;
grant execute on function public.create_wushu_evaluation(uuid,date,text,numeric,numeric,text,text,text,uuid,boolean) to authenticated;
grant execute on function public.set_wushu_evaluation_published(uuid,boolean) to authenticated;
grant execute on function public.create_wushu_competition(text,date,text,text) to authenticated;
grant execute on function public.record_wushu_competition_result(uuid,uuid,text,text,integer,text,text) to authenticated;
grant execute on function public.publish_wushu_competition(uuid,boolean) to authenticated;
grant execute on function public.get_student_wushu(uuid) to authenticated;
grant execute on function public.get_wushu_dashboard() to authenticated;

commit;
