-- SIGIA-AMINE — Étape 14 : Vie scolaire
-- Source fonctionnelle : cahier des charges Al Amine, section 8 — vie scolaire.
-- Périmètre : présence, absence, retard, justificatifs, discipline, suivi éducatif, récompenses.
-- Hors périmètre : internat, restauration, RH, Tahfiz, Wushu.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

/* =========================================================
   1. Contraintes et métadonnées complémentaires
   ========================================================= */

alter table public.attendance_sessions
  add column if not exists updated_at timestamptz not null default now();

alter table public.attendance_records
  add column if not exists updated_at timestamptz not null default now();

alter table public.absence_justifications
  add column if not exists updated_at timestamptz not null default now();

alter table public.discipline_categories
  add column if not exists is_active boolean not null default true;

alter table public.discipline_categories
  add column if not exists updated_at timestamptz not null default now();

alter table public.discipline_events
  add column if not exists updated_at timestamptz not null default now();

alter table public.student_followups
  add column if not exists status text not null default 'open';

alter table public.student_followups
  add column if not exists updated_at timestamptz not null default now();

alter table public.student_rewards
  add column if not exists category text;

alter table public.student_rewards
  add column if not exists updated_at timestamptz not null default now();

alter table public.absence_justifications
  drop constraint if exists absence_justifications_status_check;
alter table public.absence_justifications
  add constraint absence_justifications_status_check
  check(status in ('pending','approved','rejected','cancelled'));

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_time_range_check;
alter table public.attendance_sessions
  add constraint attendance_sessions_time_range_check
  check(start_time is null or end_time is null or end_time > start_time);

alter table public.student_followups
  drop constraint if exists student_followups_status_check;
alter table public.student_followups
  add constraint student_followups_status_check
  check(status in ('open','in_progress','closed','cancelled'));

create unique index if not exists uq_discipline_category_code_ci
  on public.discipline_categories(school_id, lower(code));

create unique index if not exists uq_discipline_category_name_ci
  on public.discipline_categories(school_id, lower(name));

create index if not exists idx_attendance_sessions_school_year_class_date
  on public.attendance_sessions(school_id, school_year_id, class_id, session_date desc);

create index if not exists idx_attendance_records_student_status
  on public.attendance_records(student_id, status, recorded_at desc);

create index if not exists idx_absence_justifications_school_student_status
  on public.absence_justifications(school_id, student_id, status, start_date desc);

create index if not exists idx_discipline_events_school_student_date
  on public.discipline_events(school_id, student_id, event_date desc, event_time desc);

create index if not exists idx_student_followups_school_student_date
  on public.student_followups(school_id, student_id, followup_date desc);

create index if not exists idx_student_rewards_school_student_date
  on public.student_rewards(school_id, student_id, reward_date desc);

/* =========================================================
   2. updated_at helper triggers
   ========================================================= */

create or replace function app.touch_school_life_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_attendance_sessions_updated_at on public.attendance_sessions;
create trigger trg_attendance_sessions_updated_at
before update on public.attendance_sessions
for each row execute function app.touch_school_life_updated_at();

drop trigger if exists trg_attendance_records_updated_at on public.attendance_records;
create trigger trg_attendance_records_updated_at
before update on public.attendance_records
for each row execute function app.touch_school_life_updated_at();

drop trigger if exists trg_absence_justifications_updated_at on public.absence_justifications;
create trigger trg_absence_justifications_updated_at
before update on public.absence_justifications
for each row execute function app.touch_school_life_updated_at();

drop trigger if exists trg_discipline_categories_updated_at on public.discipline_categories;
create trigger trg_discipline_categories_updated_at
before update on public.discipline_categories
for each row execute function app.touch_school_life_updated_at();

drop trigger if exists trg_discipline_events_updated_at on public.discipline_events;
create trigger trg_discipline_events_updated_at
before update on public.discipline_events
for each row execute function app.touch_school_life_updated_at();

drop trigger if exists trg_student_followups_updated_at on public.student_followups;
create trigger trg_student_followups_updated_at
before update on public.student_followups
for each row execute function app.touch_school_life_updated_at();

drop trigger if exists trg_student_rewards_updated_at on public.student_rewards;
create trigger trg_student_rewards_updated_at
before update on public.student_rewards
for each row execute function app.touch_school_life_updated_at();

/* =========================================================
   3. Secure scope helpers
   ========================================================= */

create or replace function app.employee_belongs_to_school(p_employee_id uuid, p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.employees e
    where e.id = p_employee_id
      and e.school_id = p_school_id
  );
$$;

create or replace function app.student_enrolled_in_class_on_date(
  p_student_id uuid,
  p_class_id uuid,
  p_school_year_id uuid,
  p_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.enrollments e
    where e.student_id = p_student_id
      and e.class_id = p_class_id
      and e.school_year_id = p_school_year_id
      and e.status = 'enrolled'
      and e.enrollment_date <= p_date
  );
$$;

create or replace function app.can_view_school_life_student(p_student_id uuid, p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth.uid() is not null
    and (
      app.is_super_admin()
      or app.is_self_student(p_student_id)
      or app.is_parent_of_student(p_student_id)
      or app.is_teacher_for_student(p_student_id)
      or app.has_permission('attendance.view', p_school_id)
      or app.has_permission('attendance.manage', p_school_id)
      or app.has_permission('discipline.view', p_school_id)
      or app.has_permission('discipline.manage', p_school_id)
      or app.has_permission('followups.view', p_school_id)
      or app.has_permission('followups.manage', p_school_id)
      or app.has_permission('rewards.view', p_school_id)
      or app.has_permission('rewards.manage', p_school_id)
    );
$$;

create or replace function app.validate_attendance_session()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_year_id uuid;
begin
  select c.school_id, c.school_year_id
    into v_school_id, v_year_id
    from public.classes c
   where c.id = new.class_id;

  if new.class_id is not null then
    if v_school_id is null or v_school_id <> new.school_id then
      raise exception 'CROSS_SCHOOL_ATTENDANCE_CLASS';
    end if;
    if v_year_id is not null and v_year_id <> new.school_year_id then
      raise exception 'ATTENDANCE_CLASS_YEAR_MISMATCH';
    end if;
  end if;

  if new.employee_id is not null
     and not app.employee_belongs_to_school(new.employee_id, new.school_id) then
    raise exception 'CROSS_SCHOOL_ATTENDANCE_EMPLOYEE';
  end if;

  if new.subject_id is not null then
    if not exists(
      select 1 from public.subjects s
      where s.id = new.subject_id and s.school_id = new.school_id and s.is_active
    ) then
      raise exception 'INVALID_ATTENDANCE_SUBJECT';
    end if;
  end if;

  if new.class_id is not null and new.subject_id is not null and new.employee_id is not null then
    if not exists(
      select 1
      from public.teacher_assignments ta
      join public.teacher_profiles tp on tp.employee_id = ta.teacher_id
      join public.employees e on e.id = ta.teacher_id
      where ta.school_id = new.school_id
        and ta.school_year_id = new.school_year_id
        and ta.class_id = new.class_id
        and ta.subject_id = new.subject_id
        and ta.teacher_id = new.employee_id
        and e.status = 'active'
    ) then
      raise exception 'ATTENDANCE_EMPLOYEE_NOT_ASSIGNED_TO_SUBJECT';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_attendance_session on public.attendance_sessions;
create trigger trg_validate_attendance_session
before insert or update on public.attendance_sessions
for each row execute function app.validate_attendance_session();

create or replace function app.validate_attendance_record()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.attendance_sessions;
  student_school uuid;
begin
  select * into s from public.attendance_sessions where id = new.session_id;
  if s.id is null then
    raise exception 'ATTENDANCE_SESSION_NOT_FOUND';
  end if;

  select school_id into student_school from public.students where id = new.student_id;
  if student_school is null or student_school <> s.school_id then
    raise exception 'CROSS_SCHOOL_ATTENDANCE_STUDENT';
  end if;

  if s.class_id is not null and not app.student_enrolled_in_class_on_date(
    new.student_id, s.class_id, s.school_year_id, s.session_date
  ) then
    raise exception 'STUDENT_NOT_ENROLLED_FOR_ATTENDANCE_SESSION';
  end if;

  if new.status = 'late' and new.arrival_time is null then
    raise exception 'LATE_STATUS_REQUIRES_ARRIVAL_TIME';
  end if;

  if new.status = 'present' and new.arrival_time is null and s.start_time is not null then
    new.arrival_time := s.start_time;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_attendance_record on public.attendance_records;
create trigger trg_validate_attendance_record
before insert or update on public.attendance_records
for each row execute function app.validate_attendance_record();

create or replace function app.validate_absence_justification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  student_school uuid;
begin
  if new.end_date < new.start_date then
    raise exception 'INVALID_JUSTIFICATION_DATE_RANGE';
  end if;
  select school_id into student_school from public.students where id=new.student_id;
  if student_school is null or student_school <> new.school_id then
    raise exception 'CROSS_SCHOOL_ABSENCE_JUSTIFICATION';
  end if;
  if new.attendance_record_id is not null then
    if not exists(
      select 1
      from public.attendance_records ar
      join public.attendance_sessions s on s.id=ar.session_id
      where ar.id=new.attendance_record_id
        and ar.student_id=new.student_id
        and s.school_id=new.school_id
        and ar.status in ('absent','late','excused')
    ) then
      raise exception 'JUSTIFICATION_RECORD_MISMATCH';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_absence_justification on public.absence_justifications;
create trigger trg_validate_absence_justification
before insert or update on public.absence_justifications
for each row execute function app.validate_absence_justification();

create or replace function app.validate_discipline_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  student_school uuid;
  category_school uuid;
  employee_school uuid;
begin
  select school_id into student_school from public.students where id=new.student_id;
  if student_school is null or student_school <> new.school_id then
    raise exception 'CROSS_SCHOOL_DISCIPLINE_STUDENT';
  end if;

  if new.category_id is not null then
    select school_id into category_school from public.discipline_categories where id=new.category_id;
    if category_school is null or category_school <> new.school_id then
      raise exception 'CROSS_SCHOOL_DISCIPLINE_CATEGORY';
    end if;
  end if;

  if new.responsible_employee_id is not null then
    select school_id into employee_school from public.employees where id=new.responsible_employee_id;
    if employee_school is null or employee_school <> new.school_id then
      raise exception 'CROSS_SCHOOL_DISCIPLINE_EMPLOYEE';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_discipline_event on public.discipline_events;
create trigger trg_validate_discipline_event
before insert or update on public.discipline_events
for each row execute function app.validate_discipline_event();

create or replace function app.validate_student_followup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare student_school uuid; employee_school uuid;
begin
  select school_id into student_school from public.students where id=new.student_id;
  if student_school is null or student_school <> new.school_id then
    raise exception 'CROSS_SCHOOL_FOLLOWUP_STUDENT';
  end if;
  if new.next_review_date is not null and new.next_review_date < new.followup_date then
    raise exception 'FOLLOWUP_NEXT_REVIEW_BEFORE_FOLLOWUP_DATE';
  end if;
  if new.responsible_employee_id is not null then
    select school_id into employee_school from public.employees where id=new.responsible_employee_id;
    if employee_school is null or employee_school <> new.school_id then
      raise exception 'CROSS_SCHOOL_FOLLOWUP_EMPLOYEE';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_student_followup on public.student_followups;
create trigger trg_validate_student_followup
before insert or update on public.student_followups
for each row execute function app.validate_student_followup();

create or replace function app.validate_student_reward()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare student_school uuid; giver_school uuid;
begin
  select school_id into student_school from public.students where id=new.student_id;
  if student_school is null or student_school <> new.school_id then
    raise exception 'CROSS_SCHOOL_REWARD_STUDENT';
  end if;
  if new.given_by is not null then
    select school_id into giver_school from public.users where id=new.given_by;
    if giver_school is null or giver_school <> new.school_id then
      raise exception 'CROSS_SCHOOL_REWARD_GIVER';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_student_reward on public.student_rewards;
create trigger trg_validate_student_reward
before insert or update on public.student_rewards
for each row execute function app.validate_student_reward();

/* =========================================================
   4. Permissions
   ========================================================= */

insert into public.permissions(code,name,module,action,description) values
('attendance.view','Consulter présence','attendance','view','Consulter les appels et historiques d’assiduité'),
('absence_justifications.view','Consulter justificatifs','attendance','view','Consulter les justificatifs d’absence'),
('absence_justifications.review','Valider justificatifs','attendance','review','Valider ou rejeter les justificatifs'),
('discipline.view','Consulter discipline','discipline','view','Consulter incidents, récompenses et sanctions'),
('followups.view','Consulter suivi éducatif','discipline','view','Consulter les suivis éducatifs'),
('followups.manage','Gérer suivi éducatif','discipline','manage','Créer et suivre les actions éducatives'),
('rewards.view','Consulter récompenses','discipline','view','Consulter les récompenses'),
('rewards.manage','Gérer récompenses','discipline','manage','Attribuer et corriger les récompenses')
on conflict(code) do nothing;

-- Référentiel minimal : le rôle conserve les permissions métier déjà accordées.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('attendance.view','absence_justifications.view','absence_justifications.review','discipline.view','followups.view','followups.manage','rewards.view','rewards.manage')
where r.code in ('super_admin','founder','direction','academic_director') on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('attendance.view','discipline.view','followups.view','rewards.view')
where r.code='admin' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('attendance.view','discipline.view','followups.view','rewards.view')
where r.code='teacher' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('attendance.view','attendance.manage','absence_justifications.view','absence_justifications.review','discipline.view','discipline.manage','followups.view','followups.manage','rewards.view','rewards.manage')
where r.code='supervisor' on conflict do nothing;

/* =========================================================
   5. RLS
   ========================================================= */

alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.absence_justifications enable row level security;
alter table public.discipline_categories enable row level security;
alter table public.discipline_events enable row level security;
alter table public.student_followups enable row level security;
alter table public.student_rewards enable row level security;

drop policy if exists attendance_sessions_secure on public.attendance_sessions;
drop policy if exists attendance_sessions_manage on public.attendance_sessions;
 drop policy if exists attendance_sessions_select_secure on public.attendance_sessions;
 drop policy if exists attendance_sessions_insert_secure on public.attendance_sessions;
 drop policy if exists attendance_sessions_update_secure on public.attendance_sessions;
 drop policy if exists attendance_sessions_delete_secure on public.attendance_sessions;
drop policy if exists attendance_records_secure on public.attendance_records;
drop policy if exists attendance_records_manage on public.attendance_records;
drop policy if exists absence_justifications_secure on public.absence_justifications;
drop policy if exists absence_justifications_manage on public.absence_justifications;
 drop policy if exists absence_justifications_select_secure on public.absence_justifications;
 drop policy if exists absence_justifications_insert_secure on public.absence_justifications;
 drop policy if exists absence_justifications_update_secure on public.absence_justifications;
 drop policy if exists absence_justifications_delete_secure on public.absence_justifications;
drop policy if exists discipline_categories_secure on public.discipline_categories;
drop policy if exists discipline_categories_manage on public.discipline_categories;
drop policy if exists discipline_events_secure on public.discipline_events;
drop policy if exists discipline_events_manage on public.discipline_events;
 drop policy if exists discipline_events_select_secure on public.discipline_events;
 drop policy if exists discipline_events_insert_secure on public.discipline_events;
 drop policy if exists discipline_events_update_secure on public.discipline_events;
 drop policy if exists discipline_events_delete_secure on public.discipline_events;
drop policy if exists student_followups_secure on public.student_followups;
drop policy if exists student_followups_manage on public.student_followups;
 drop policy if exists student_followups_select_secure on public.student_followups;
 drop policy if exists student_followups_insert_secure on public.student_followups;
 drop policy if exists student_followups_update_secure on public.student_followups;
 drop policy if exists student_followups_delete_secure on public.student_followups;
drop policy if exists student_rewards_secure on public.student_rewards;
drop policy if exists student_rewards_manage on public.student_rewards;
 drop policy if exists student_rewards_select_secure on public.student_rewards;
 drop policy if exists student_rewards_insert_secure on public.student_rewards;
 drop policy if exists student_rewards_update_secure on public.student_rewards;
 drop policy if exists student_rewards_delete_secure on public.student_rewards;

create policy attendance_sessions_select_step14
on public.attendance_sessions for select
using (
  app.is_super_admin()
  or app.has_permission('attendance.view',school_id)
  or app.has_permission('attendance.manage',school_id)
  or (
    class_id is not null and (
      exists(select 1 from public.enrollments e where e.class_id=attendance_sessions.class_id and e.school_year_id=attendance_sessions.school_year_id and e.student_id in (select s.id from public.students s where s.user_id=auth.uid()) and e.status='enrolled')
      or exists(select 1 from public.student_parents sp join public.parents p on p.id=sp.parent_id join public.enrollments e on e.student_id=sp.student_id where p.user_id=auth.uid() and e.class_id=attendance_sessions.class_id and e.school_year_id=attendance_sessions.school_year_id and e.status='enrolled')
      or app.is_teacher_for_class(class_id,school_year_id)
    )
  )
);

create policy attendance_sessions_insert_step14
on public.attendance_sessions for insert
with check (app.is_super_admin() or app.has_permission('attendance.manage',school_id));

create policy attendance_sessions_update_step14
on public.attendance_sessions for update
using (app.is_super_admin() or app.has_permission('attendance.manage',school_id))
with check (app.is_super_admin() or app.has_permission('attendance.manage',school_id));

create policy attendance_sessions_delete_step14
on public.attendance_sessions for delete
using (app.is_super_admin() or app.has_permission('attendance.manage',school_id));

create policy attendance_records_select_step14
on public.attendance_records for select
using (
  app.is_super_admin()
  or app.has_permission('attendance.view',(select s.school_id from public.attendance_sessions s where s.id=session_id))
  or app.has_permission('attendance.manage',(select s.school_id from public.attendance_sessions s where s.id=session_id))
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
  or app.is_teacher_for_student(student_id)
);

create policy attendance_records_insert_step14
on public.attendance_records for insert
with check (
  app.is_super_admin()
  or app.has_permission('attendance.manage',(select s.school_id from public.attendance_sessions s where s.id=session_id))
  or app.is_teacher_for_student(student_id)
);

create policy attendance_records_update_step14
on public.attendance_records for update
using (
  app.is_super_admin()
  or app.has_permission('attendance.manage',(select s.school_id from public.attendance_sessions s where s.id=session_id))
  or app.is_teacher_for_student(student_id)
)
with check (
  app.is_super_admin()
  or app.has_permission('attendance.manage',(select s.school_id from public.attendance_sessions s where s.id=session_id))
  or app.is_teacher_for_student(student_id)
);

create policy attendance_records_delete_step14
on public.attendance_records for delete
using (app.is_super_admin() or app.has_permission('attendance.manage',(select s.school_id from public.attendance_sessions s where s.id=session_id)));

create policy absence_justifications_select_step14
on public.absence_justifications for select
using (
  app.is_super_admin()
  or app.has_permission('absence_justifications.view',school_id)
  or app.has_permission('absence_justifications.review',school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
  or app.is_teacher_for_student(student_id)
);

create policy absence_justifications_insert_step14
on public.absence_justifications for insert
with check (
  app.is_super_admin()
  or app.has_permission('absence_justifications.review',school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
);

create policy absence_justifications_update_step14
on public.absence_justifications for update
using (
  app.is_super_admin()
  or app.has_permission('absence_justifications.review',school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
)
with check (
  app.is_super_admin()
  or app.has_permission('absence_justifications.review',school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
);

create policy absence_justifications_delete_step14
on public.absence_justifications for delete
using (app.is_super_admin() or app.has_permission('absence_justifications.review',school_id));

create policy discipline_categories_select_step14
on public.discipline_categories for select
using (
  app.is_super_admin()
  or app.has_permission('discipline.view',school_id)
  or app.has_permission('discipline.manage',school_id)
);

create policy discipline_categories_manage_step14
on public.discipline_categories for all
using (app.is_super_admin() or app.has_permission('discipline.manage',school_id))
with check (app.is_super_admin() or app.has_permission('discipline.manage',school_id));

create policy discipline_events_select_step14
on public.discipline_events for select
using (
  app.is_super_admin()
  or app.has_permission('discipline.view',school_id)
  or app.has_permission('discipline.manage',school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
  or app.is_teacher_for_student(student_id)
);

create policy discipline_events_insert_step14
on public.discipline_events for insert
with check (
  app.is_super_admin()
  or app.has_permission('discipline.manage',school_id)
  or app.is_teacher_for_student(student_id)
);

create policy discipline_events_update_step14
on public.discipline_events for update
using (app.is_super_admin() or app.has_permission('discipline.manage',school_id))
with check (app.is_super_admin() or app.has_permission('discipline.manage',school_id));

create policy discipline_events_delete_step14
on public.discipline_events for delete
using (app.is_super_admin() or app.has_permission('discipline.manage',school_id));

create policy student_followups_select_step14
on public.student_followups for select
using (
  app.is_super_admin()
  or app.has_permission('followups.view',school_id)
  or app.has_permission('followups.manage',school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
  or app.is_teacher_for_student(student_id)
);

create policy student_followups_insert_step14
on public.student_followups for insert
with check (app.is_super_admin() or app.has_permission('followups.manage',school_id));

create policy student_followups_update_step14
on public.student_followups for update
using (app.is_super_admin() or app.has_permission('followups.manage',school_id))
with check (app.is_super_admin() or app.has_permission('followups.manage',school_id));

create policy student_followups_delete_step14
on public.student_followups for delete
using (app.is_super_admin() or app.has_permission('followups.manage',school_id));

create policy student_rewards_select_step14
on public.student_rewards for select
using (
  app.is_super_admin()
  or app.has_permission('rewards.view',school_id)
  or app.has_permission('rewards.manage',school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
  or app.is_teacher_for_student(student_id)
);

create policy student_rewards_insert_step14
on public.student_rewards for insert
with check (app.is_super_admin() or app.has_permission('rewards.manage',school_id));

create policy student_rewards_update_step14
on public.student_rewards for update
using (app.is_super_admin() or app.has_permission('rewards.manage',school_id))
with check (app.is_super_admin() or app.has_permission('rewards.manage',school_id));

create policy student_rewards_delete_step14
on public.student_rewards for delete
using (app.is_super_admin() or app.has_permission('rewards.manage',school_id));

/* =========================================================
   6. Explicit grants
   ========================================================= */

revoke all on public.attendance_sessions, public.attendance_records, public.absence_justifications,
  public.discipline_categories, public.discipline_events, public.student_followups, public.student_rewards
from anon;

grant select on public.attendance_sessions, public.attendance_records, public.absence_justifications,
  public.discipline_categories, public.discipline_events, public.student_followups, public.student_rewards
to authenticated;

grant insert, update, delete on public.attendance_sessions, public.attendance_records,
  public.absence_justifications, public.discipline_categories, public.discipline_events,
  public.student_followups, public.student_rewards to authenticated;

/* =========================================================
   7. Transactional RPCs
   ========================================================= */

create or replace function public.create_attendance_session(
  p_school_year_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_employee_id uuid,
  p_session_date date,
  p_start_time time,
  p_end_time time,
  p_activity_type text,
  p_notes text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school_id uuid; v_id uuid;
begin
  select school_id into v_school_id from public.classes where id=p_class_id;
  if v_school_id is null then raise exception 'CLASS_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('attendance.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
  if not exists(select 1 from public.classes c where c.id=p_class_id and c.school_year_id=p_school_year_id and c.school_id=v_school_id) then raise exception 'CLASS_YEAR_MISMATCH'; end if;
  if p_start_time is not null and p_end_time is not null and p_end_time <= p_start_time then raise exception 'INVALID_TIME_RANGE'; end if;
  insert into public.attendance_sessions(school_id,school_year_id,class_id,subject_id,employee_id,session_date,start_time,end_time,activity_type,notes)
  values(v_school_id,p_school_year_id,p_class_id,p_subject_id,p_employee_id,p_session_date,p_start_time,p_end_time,coalesce(nullif(trim(p_activity_type),''),'class'),p_notes)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_attendance_session(uuid,uuid,uuid,uuid,date,time,time,text,text) from public, anon;
grant execute on function public.create_attendance_session(uuid,uuid,uuid,uuid,date,time,time,text,text) to authenticated;

create or replace function public.save_attendance_records(
  p_session_id uuid,
  p_records jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.attendance_sessions;
  item jsonb;
  v_student_id uuid;
  v_status app.attendance_status;
  v_count integer := 0;
begin
  select * into s from public.attendance_sessions where id=p_session_id for update;
  if s.id is null then raise exception 'ATTENDANCE_SESSION_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('attendance.manage',s.school_id)) then raise exception 'FORBIDDEN'; end if;
  if jsonb_typeof(p_records) <> 'array' then raise exception 'RECORDS_MUST_BE_ARRAY'; end if;

  for item in select * from jsonb_array_elements(p_records)
  loop
    v_student_id := (item->>'student_id')::uuid;
    v_status := (item->>'status')::app.attendance_status;

    if s.class_id is not null and not app.student_enrolled_in_class_on_date(v_student_id,s.class_id,s.school_year_id,s.session_date) then
      raise exception 'STUDENT_NOT_ENROLLED:%', v_student_id;
    end if;

    insert into public.attendance_records(session_id,student_id,status,arrival_time,departure_time,reason,recorded_by)
    values(
      s.id,
      v_student_id,
      v_status,
      nullif(item->>'arrival_time','')::time,
      nullif(item->>'departure_time','')::time,
      nullif(item->>'reason',''),
      auth.uid()
    )
    on conflict(session_id,student_id) do update set
      status=excluded.status,
      arrival_time=excluded.arrival_time,
      departure_time=excluded.departure_time,
      reason=excluded.reason,
      recorded_by=excluded.recorded_by,
      recorded_at=now();

    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.save_attendance_records(uuid,jsonb) from public, anon;
grant execute on function public.save_attendance_records(uuid,jsonb) to authenticated;

create or replace function public.review_absence_justification(
  p_justification_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school_id uuid;
begin
  select school_id into v_school_id from public.absence_justifications where id=p_justification_id for update;
  if v_school_id is null then raise exception 'JUSTIFICATION_NOT_FOUND'; end if;
  if p_status not in ('approved','rejected','cancelled') then raise exception 'INVALID_JUSTIFICATION_STATUS'; end if;
  if not (app.is_super_admin() or app.has_permission('absence_justifications.review',v_school_id)) then raise exception 'FORBIDDEN'; end if;
  update public.absence_justifications
     set status=p_status, reviewed_by=auth.uid(), reviewed_at=now(), updated_at=now()
   where id=p_justification_id;
end;
$$;

revoke all on function public.review_absence_justification(uuid,text) from public, anon;
grant execute on function public.review_absence_justification(uuid,text) to authenticated;

create or replace function public.create_discipline_event(
  p_student_id uuid,
  p_category_id uuid,
  p_event_date date,
  p_event_time time,
  p_event_type text,
  p_description text,
  p_action_taken text,
  p_responsible_employee_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school_id uuid; v_id uuid;
begin
  select school_id into v_school_id from public.students where id=p_student_id;
  if v_school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('discipline.manage',v_school_id) or app.is_teacher_for_student(p_student_id)) then raise exception 'FORBIDDEN'; end if;
  insert into public.discipline_events(school_id,student_id,category_id,event_date,event_time,event_type,description,action_taken,responsible_employee_id,created_by)
  values(v_school_id,p_student_id,p_category_id,coalesce(p_event_date,current_date),p_event_time,trim(p_event_type),trim(p_description),nullif(trim(p_action_taken),''),p_responsible_employee_id,auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_discipline_event(uuid,uuid,date,time,text,text,text,uuid) from public, anon;
grant execute on function public.create_discipline_event(uuid,uuid,date,time,text,text,text,uuid) to authenticated;

create or replace function public.create_student_followup(
  p_student_id uuid,
  p_followup_date date,
  p_category text,
  p_observation text,
  p_action_plan text,
  p_next_review_date date,
  p_responsible_employee_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school_id uuid; v_id uuid;
begin
  select school_id into v_school_id from public.students where id=p_student_id;
  if v_school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('followups.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
  insert into public.student_followups(school_id,student_id,followup_date,category,observation,action_plan,next_review_date,responsible_employee_id,created_by)
  values(v_school_id,p_student_id,coalesce(p_followup_date,current_date),trim(p_category),trim(p_observation),nullif(trim(p_action_plan),''),p_next_review_date,p_responsible_employee_id,auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_student_followup(uuid,date,text,text,text,date,uuid) from public, anon;
grant execute on function public.create_student_followup(uuid,date,text,text,text,date,uuid) to authenticated;

create or replace function public.create_student_reward(
  p_student_id uuid,
  p_reward_date date,
  p_title text,
  p_description text,
  p_category text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school_id uuid; v_id uuid;
begin
  select school_id into v_school_id from public.students where id=p_student_id;
  if v_school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  if not (app.is_super_admin() or app.has_permission('rewards.manage',v_school_id)) then raise exception 'FORBIDDEN'; end if;
  insert into public.student_rewards(school_id,student_id,reward_date,title,description,category,given_by)
  values(v_school_id,p_student_id,coalesce(p_reward_date,current_date),trim(p_title),nullif(trim(p_description),''),nullif(trim(p_category),''),auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_student_reward(uuid,date,text,text,text) from public, anon;
grant execute on function public.create_student_reward(uuid,date,text,text,text) to authenticated;

/* =========================================================
   8. Student dossier / reporting helper
   ========================================================= */

create or replace function public.get_student_school_life_summary(p_student_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
select jsonb_build_object(
  'attendance', coalesce((
    select jsonb_agg(to_jsonb(x) order by x.session_date desc, x.id desc)
    from (
      select s.id, s.session_date, s.start_time, s.end_time, s.activity_type,
             s.subject_id, sub.name as subject_name, ar.status, ar.arrival_time, ar.departure_time, ar.reason
      from public.attendance_records ar
      join public.attendance_sessions s on s.id=ar.session_id
      left join public.subjects sub on sub.id=s.subject_id
      where ar.student_id=p_student_id
      order by s.session_date desc, s.start_time desc nulls last
      limit 100
    ) x
  ), '[]'::jsonb),
  'justifications', coalesce((
    select jsonb_agg(to_jsonb(j) order by j.start_date desc)
    from (
      select id, start_date, end_date, reason, status, document_id, reviewed_at
      from public.absence_justifications
      where student_id=p_student_id
      order by start_date desc
      limit 50
    ) j
  ), '[]'::jsonb),
  'discipline', coalesce((
    select jsonb_agg(to_jsonb(d) order by d.event_date desc, d.id desc)
    from (
      select de.id, de.event_date, de.event_time, de.event_type, de.description, de.action_taken, dc.name as category_name, dc.severity
      from public.discipline_events de
      left join public.discipline_categories dc on dc.id=de.category_id
      where de.student_id=p_student_id
      order by de.event_date desc, de.event_time desc nulls last
      limit 100
    ) d
  ), '[]'::jsonb),
  'followups', coalesce((
    select jsonb_agg(to_jsonb(f) order by f.followup_date desc, f.id desc)
    from (
      select id, followup_date, category, observation, action_plan, next_review_date, status
      from public.student_followups
      where student_id=p_student_id
      order by followup_date desc
      limit 100
    ) f
  ), '[]'::jsonb),
  'rewards', coalesce((
    select jsonb_agg(to_jsonb(r) order by r.reward_date desc, r.id desc)
    from (
      select id, reward_date, title, description, category
      from public.student_rewards
      where student_id=p_student_id
      order by reward_date desc
      limit 100
    ) r
  ), '[]'::jsonb)
);
$$;

revoke all on function public.get_student_school_life_summary(uuid) from public, anon;
grant execute on function public.get_student_school_life_summary(uuid) to authenticated;

commit;
