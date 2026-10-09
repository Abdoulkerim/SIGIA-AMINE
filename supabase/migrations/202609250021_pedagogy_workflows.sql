-- SIGIA-AMINE
-- Migration 021: pédagogie opérationnelle
-- Étape 13 — Emploi du temps, évaluations, notes et bulletins
--
-- Principes :
-- 1. La chaîne pédagogique est : Classe -> Matière -> Enseignant -> Évaluation -> Note -> Moyenne -> Bulletin.
-- 2. Les contraintes critiques sont imposées côté PostgreSQL.
-- 3. Les enseignants restent limités à leurs affectations.
-- 4. Les élèves/parents ne voient les notes que lorsque l'évaluation est publiée.
-- 5. Aucun barème, type d'évaluation, rang ou décision officiel Al Amine n'est inventé ici.
--
-- Exactes règles officielles encore à fournir par Al Amine :
-- - types d'évaluations obligatoires ;
-- - coefficients officiels si différents des coefficients des matières/évaluations ;
-- - formule officielle de classement ;
-- - règles de décision/passages ;
-- - règles d'absence/neutralisation.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- A. QUALITÉ DES TABLES PÉDAGOGIQUES EXISTANTES
-- =========================================================
alter table public.assessment_types
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.assessment_types
  drop constraint if exists assessment_types_code_not_blank,
  drop constraint if exists assessment_types_name_not_blank,
  add constraint assessment_types_code_not_blank check (length(trim(code)) > 0),
  add constraint assessment_types_name_not_blank check (length(trim(name)) > 0);

create unique index if not exists uq_assessment_types_school_code_ci
  on public.assessment_types(school_id, lower(trim(code)));

create unique index if not exists uq_assessment_types_school_name_ci
  on public.assessment_types(school_id, lower(trim(name)));

create index if not exists idx_assessment_types_school_active
  on public.assessment_types(school_id, is_active, name);

create trigger trg_assessment_types_updated_at
before update on public.assessment_types
for each row execute function app.set_updated_at();

alter table public.assessments
  drop constraint if exists assessments_title_not_blank,
  add constraint assessments_title_not_blank check (length(trim(title)) > 0);

alter table public.report_cards
  drop constraint if exists report_cards_status_check,
  add constraint report_cards_status_check check (status in ('draft','published','archived'));

create index if not exists idx_timetable_slots_school_year_class_day
  on public.timetable_slots(school_id, school_year_id, class_id, day_of_week, start_time, end_time);
create index if not exists idx_timetable_slots_school_year_teacher_day
  on public.timetable_slots(school_id, school_year_id, teacher_id, day_of_week, start_time, end_time);
create index if not exists idx_timetable_slots_room_day
  on public.timetable_slots(school_id, school_year_id, lower(trim(room_name)), day_of_week, start_time, end_time)
  where room_name is not null and is_active = true;
create index if not exists idx_assessments_school_year_period_class_subject
  on public.assessments(school_id, school_year_id, period_id, class_id, subject_id, assessment_date);
create index if not exists idx_assessments_teacher
  on public.assessments(school_id, teacher_id, period_id, assessment_date);
create index if not exists idx_grades_assessment_student
  on public.grades(assessment_id, student_id);
create index if not exists idx_grades_student_assessment
  on public.grades(student_id, assessment_id);
create index if not exists idx_report_cards_school_period_class
  on public.report_cards(school_id, school_year_id, period_id, class_id, status);
create index if not exists idx_report_card_items_report_card_subject
  on public.report_card_items(report_card_id, subject_id);

-- =========================================================
-- B. PERMISSIONS FINES
-- =========================================================
insert into public.permissions(code, name, module, action, description)
values
  ('timetable.view', 'Consulter emploi du temps', 'academic', 'view', 'Consulter les créneaux pédagogiques autorisés'),
  ('assessments.view', 'Consulter évaluations', 'grades', 'view', 'Consulter les évaluations du périmètre autorisé'),
  ('grades.view', 'Consulter notes', 'grades', 'view', 'Consulter les notes du périmètre autorisé'),
  ('report_cards.view', 'Consulter bulletins', 'grades', 'view', 'Consulter les bulletins autorisés'),
  ('report_cards.publish', 'Publier bulletins', 'grades', 'publish', 'Publier les bulletins finalisés')
on conflict(code) do update
set name = excluded.name,
    module = excluded.module,
    action = excluded.action,
    description = excluded.description;

-- Direction / fondateur / admin système : accès complet pédagogique.
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code in ('super_admin','founder','direction','academic_director')
  and p.code in (
    'timetable.view','timetable.manage',
    'assessments.view','assessments.manage',
    'grades.view','grades.enter','grades.publish',
    'report_cards.view','report_cards.generate','report_cards.publish'
  )
on conflict do nothing;

-- Administration : lecture pédagogique opérationnelle.
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('timetable.view','assessments.view','grades.view','report_cards.view')
where r.code = 'admin'
on conflict do nothing;

-- Enseignant : consultation + gestion de ses évaluations et notes, sans publication finale.
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'timetable.view','assessments.view','assessments.manage',
  'grades.view','grades.enter','report_cards.view'
)
where r.code = 'teacher'
on conflict do nothing;

-- =========================================================
-- C. FONCTIONS DE PÉRIMÈTRE ENSEIGNANT
-- =========================================================
create or replace function app.is_teacher_for_assessment(p_assessment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.assessments a
    join public.employees e on e.id = a.teacher_id
    join public.teacher_assignments ta
      on ta.teacher_id = a.teacher_id
     and ta.school_year_id = a.school_year_id
     and ta.class_id = a.class_id
     and ta.subject_id = a.subject_id
    where a.id = p_assessment_id
      and e.user_id = (select auth.uid())
      and e.status = 'active'
  )
$$;

create or replace function app.is_teacher_for_timetable_slot(p_slot_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.timetable_slots t
    join public.employees e on e.id = t.teacher_id
    join public.teacher_assignments ta
      on ta.teacher_id = t.teacher_id
     and ta.school_year_id = t.school_year_id
     and ta.class_id = t.class_id
     and ta.subject_id = t.subject_id
    where t.id = p_slot_id
      and e.user_id = (select auth.uid())
      and e.status = 'active'
      and t.is_active = true
  )
$$;

create or replace function app.can_manage_assessment_for_class_subject(
  p_school_id uuid,
  p_school_year_id uuid,
  p_class_id uuid,
  p_subject_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    app.is_super_admin()
    or app.has_permission('assessments.manage', p_school_id)
    or exists(
      select 1
      from public.teacher_assignments ta
      join public.employees e on e.id = ta.teacher_id
      where ta.school_id = p_school_id
        and ta.school_year_id = p_school_year_id
        and ta.class_id = p_class_id
        and ta.subject_id = p_subject_id
        and e.user_id = (select auth.uid())
        and e.status = 'active'
    )
$$;

-- =========================================================
-- D. EMPLOI DU TEMPS : INTÉGRITÉ + CONFLITS
-- =========================================================
create or replace function app.validate_timetable_slot_021()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year public.school_years%rowtype;
  v_class public.classes%rowtype;
  v_teacher public.employees%rowtype;
  v_subject public.subjects%rowtype;
  v_slot_id uuid;
begin
  select * into v_year from public.school_years where id = new.school_year_id;
  if not found then raise exception 'INVALID_SCHOOL_YEAR'; end if;
  if v_year.school_id <> new.school_id then raise exception 'CROSS_SCHOOL: timetable.school_year_id'; end if;

  select * into v_class from public.classes where id = new.class_id;
  if not found then raise exception 'INVALID_CLASS'; end if;
  if v_class.school_id <> new.school_id or v_class.school_year_id <> new.school_year_id then
    raise exception 'INVALID_CLASS_YEAR';
  end if;
  if not v_class.is_active then raise exception 'CLASS_INACTIVE'; end if;
  if v_class.level_id is null then raise exception 'CLASS_LEVEL_REQUIRED'; end if;

  select * into v_subject from public.subjects where id = new.subject_id;
  if not found then raise exception 'INVALID_SUBJECT'; end if;
  if v_subject.school_id <> new.school_id then raise exception 'CROSS_SCHOOL: timetable.subject_id'; end if;
  if not v_subject.is_active then raise exception 'SUBJECT_INACTIVE'; end if;

  select * into v_teacher from public.employees where id = new.teacher_id;
  if not found then raise exception 'INVALID_TEACHER'; end if;
  if v_teacher.school_id <> new.school_id then raise exception 'CROSS_SCHOOL: timetable.teacher_id'; end if;
  if v_teacher.status <> 'active' then raise exception 'TEACHER_INACTIVE'; end if;
  if not exists (select 1 from public.teacher_profiles tp where tp.employee_id = v_teacher.id) then
    raise exception 'TEACHER_PROFILE_REQUIRED';
  end if;
  if not exists (
    select 1 from public.teacher_assignments ta
    where ta.school_id = new.school_id
      and ta.school_year_id = new.school_year_id
      and ta.teacher_id = new.teacher_id
      and ta.class_id = new.class_id
      and ta.subject_id = new.subject_id
  ) then
    raise exception 'TEACHER_NOT_ASSIGNED_TO_CLASS_SUBJECT';
  end if;

  if new.valid_from is not null and new.valid_to is not null and new.valid_to < new.valid_from then
    raise exception 'INVALID_VALIDITY_RANGE';
  end if;
  if coalesce(new.valid_from, v_year.start_date) < v_year.start_date
     or coalesce(new.valid_to, v_year.end_date) > v_year.end_date then
    raise exception 'TIMETABLE_OUTSIDE_SCHOOL_YEAR';
  end if;

  -- Conflit classe.
  if exists (
    select 1
    from public.timetable_slots t
    where t.school_id = new.school_id
      and t.school_year_id = new.school_year_id
      and t.class_id = new.class_id
      and t.day_of_week = new.day_of_week
      and t.is_active = true
      and t.id is distinct from new.id
      and t.start_time < new.end_time
      and new.start_time < t.end_time
      and coalesce(t.valid_from, v_year.start_date) <= coalesce(new.valid_to, v_year.end_date)
      and coalesce(new.valid_from, v_year.start_date) <= coalesce(t.valid_to, v_year.end_date)
  ) then
    select t.id into v_slot_id
    from public.timetable_slots t
    where t.school_id = new.school_id
      and t.school_year_id = new.school_year_id
      and t.class_id = new.class_id
      and t.day_of_week = new.day_of_week
      and t.is_active = true
      and t.id is distinct from new.id
      and t.start_time < new.end_time
      and new.start_time < t.end_time
      and coalesce(t.valid_from, v_year.start_date) <= coalesce(new.valid_to, v_year.end_date)
      and coalesce(new.valid_from, v_year.start_date) <= coalesce(t.valid_to, v_year.end_date)
    limit 1;
    raise exception 'TIMETABLE_CLASS_CONFLICT:%', v_slot_id;
  end if;

  -- Conflit enseignant.
  if exists (
    select 1
    from public.timetable_slots t
    where t.school_id = new.school_id
      and t.school_year_id = new.school_year_id
      and t.teacher_id = new.teacher_id
      and t.day_of_week = new.day_of_week
      and t.is_active = true
      and t.id is distinct from new.id
      and t.start_time < new.end_time
      and new.start_time < t.end_time
      and coalesce(t.valid_from, v_year.start_date) <= coalesce(new.valid_to, v_year.end_date)
      and coalesce(new.valid_from, v_year.start_date) <= coalesce(t.valid_to, v_year.end_date)
  ) then
    raise exception 'TIMETABLE_TEACHER_CONFLICT';
  end if;

  -- Conflit de salle si la salle est renseignée.
  if nullif(trim(new.room_name), '') is not null and exists (
    select 1
    from public.timetable_slots t
    where t.school_id = new.school_id
      and t.school_year_id = new.school_year_id
      and lower(trim(t.room_name)) = lower(trim(new.room_name))
      and t.day_of_week = new.day_of_week
      and t.is_active = true
      and t.id is distinct from new.id
      and t.start_time < new.end_time
      and new.start_time < t.end_time
      and coalesce(t.valid_from, v_year.start_date) <= coalesce(new.valid_to, v_year.end_date)
      and coalesce(new.valid_from, v_year.start_date) <= coalesce(t.valid_to, v_year.end_date)
  ) then
    raise exception 'TIMETABLE_ROOM_CONFLICT';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_021_validate_timetable_slot on public.timetable_slots;
create trigger trg_021_validate_timetable_slot
before insert or update on public.timetable_slots
for each row execute function app.validate_timetable_slot_021();

create or replace function public.create_timetable_slot(
  p_school_year_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_teacher_id uuid,
  p_day_of_week integer,
  p_start_time time,
  p_end_time time,
  p_room_name text default null,
  p_valid_from date default null,
  p_valid_to date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_id uuid;
begin
  select u.school_id into v_school_id from public.users u where u.id = (select auth.uid());
  if v_school_id is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if not app.is_super_admin() and not app.has_permission('timetable.manage', v_school_id) then
    raise exception 'PERMISSION_REQUIRED: timetable.manage';
  end if;
  insert into public.timetable_slots(
    school_id, school_year_id, class_id, subject_id, teacher_id,
    day_of_week, start_time, end_time, room_name, valid_from, valid_to
  ) values (
    v_school_id, p_school_year_id, p_class_id, p_subject_id, p_teacher_id,
    p_day_of_week, p_start_time, p_end_time, nullif(trim(p_room_name), ''), p_valid_from, p_valid_to
  ) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.update_timetable_slot(
  p_slot_id uuid,
  p_school_year_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_teacher_id uuid,
  p_day_of_week integer,
  p_start_time time,
  p_end_time time,
  p_room_name text default null,
  p_valid_from date default null,
  p_valid_to date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_id uuid;
begin
  select school_id into v_school_id from public.timetable_slots where id = p_slot_id;
  if v_school_id is null then raise exception 'TIMETABLE_SLOT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('timetable.manage', v_school_id) then
    raise exception 'PERMISSION_REQUIRED: timetable.manage';
  end if;
  update public.timetable_slots
  set school_year_id = p_school_year_id,
      class_id = p_class_id,
      subject_id = p_subject_id,
      teacher_id = p_teacher_id,
      day_of_week = p_day_of_week,
      start_time = p_start_time,
      end_time = p_end_time,
      room_name = nullif(trim(p_room_name), ''),
      valid_from = p_valid_from,
      valid_to = p_valid_to
  where id = p_slot_id
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.set_timetable_slot_active(p_slot_id uuid, p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school_id uuid;
begin
  select school_id into v_school_id from public.timetable_slots where id=p_slot_id;
  if v_school_id is null then raise exception 'TIMETABLE_SLOT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('timetable.manage', v_school_id) then
    raise exception 'PERMISSION_REQUIRED: timetable.manage';
  end if;
  update public.timetable_slots set is_active=p_is_active where id=p_slot_id;
end;
$$;

-- =========================================================
-- E. ÉVALUATIONS : INTÉGRITÉ
-- =========================================================
create or replace function app.validate_assessment_021()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year public.school_years%rowtype;
  v_period public.academic_periods%rowtype;
  v_class public.classes%rowtype;
  v_subject public.subjects%rowtype;
  v_type public.assessment_types%rowtype;
  v_teacher public.employees%rowtype;
begin
  select * into v_year from public.school_years where id=new.school_year_id;
  if not found then raise exception 'INVALID_SCHOOL_YEAR'; end if;
  if v_year.school_id <> new.school_id then raise exception 'CROSS_SCHOOL: assessments.school_year_id'; end if;

  select * into v_period from public.academic_periods where id=new.period_id;
  if not found then raise exception 'INVALID_PERIOD'; end if;
  if v_period.school_year_id <> new.school_year_id then raise exception 'PERIOD_YEAR_MISMATCH'; end if;
  if v_period.is_closed then raise exception 'PERIOD_CLOSED'; end if;
  if new.assessment_date < v_period.start_date or new.assessment_date > v_period.end_date then
    raise exception 'ASSESSMENT_DATE_OUTSIDE_PERIOD';
  end if;

  select * into v_class from public.classes where id=new.class_id;
  if not found then raise exception 'INVALID_CLASS'; end if;
  if v_class.school_id <> new.school_id or v_class.school_year_id <> new.school_year_id then
    raise exception 'INVALID_CLASS_YEAR';
  end if;
  if not v_class.is_active then raise exception 'CLASS_INACTIVE'; end if;
  if v_class.level_id is null then raise exception 'CLASS_LEVEL_REQUIRED'; end if;

  select * into v_subject from public.subjects where id=new.subject_id;
  if not found then raise exception 'INVALID_SUBJECT'; end if;
  if v_subject.school_id <> new.school_id or not v_subject.is_active then raise exception 'SUBJECT_INACTIVE'; end if;
  if not exists (
    select 1
    from public.subject_level_assignments sla
    where sla.school_id = new.school_id
      and sla.school_year_id = new.school_year_id
      and sla.level_id = v_class.level_id
      and sla.subject_id = new.subject_id
      and sla.is_active = true
  ) then
    raise exception 'SUBJECT_NOT_ASSIGNED_TO_CLASS_LEVEL';
  end if;

  if new.teacher_id is null then raise exception 'ASSESSMENT_TEACHER_REQUIRED'; end if;
  select * into v_teacher from public.employees where id=new.teacher_id;
  if not found then raise exception 'INVALID_TEACHER'; end if;
  if v_teacher.school_id <> new.school_id or v_teacher.status <> 'active' then raise exception 'TEACHER_INVALID_OR_INACTIVE'; end if;
  if not exists (select 1 from public.teacher_profiles tp where tp.employee_id=v_teacher.id) then raise exception 'TEACHER_PROFILE_REQUIRED'; end if;
  if not exists (
    select 1 from public.teacher_assignments ta
    where ta.school_id=new.school_id
      and ta.school_year_id=new.school_year_id
      and ta.teacher_id=new.teacher_id
      and ta.class_id=new.class_id
      and ta.subject_id=new.subject_id
  ) then
    raise exception 'TEACHER_NOT_ASSIGNED_TO_CLASS_SUBJECT';
  end if;

  if new.assessment_type_id is not null then
    select * into v_type from public.assessment_types where id=new.assessment_type_id;
    if not found then raise exception 'INVALID_ASSESSMENT_TYPE'; end if;
    if v_type.school_id <> new.school_id or not v_type.is_active then raise exception 'ASSESSMENT_TYPE_INACTIVE'; end if;
  end if;

  if new.max_score <= 0 then raise exception 'MAX_SCORE_INVALID'; end if;
  if new.coefficient <= 0 then raise exception 'ASSESSMENT_COEFFICIENT_INVALID'; end if;
  return new;
end;
$$;

drop trigger if exists trg_021_validate_assessment on public.assessments;
create trigger trg_021_validate_assessment
before insert or update on public.assessments
for each row execute function app.validate_assessment_021();

-- La publication est une opération distincte et contrôlée.
create or replace function public.set_assessment_published(p_assessment_id uuid, p_is_published boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ass public.assessments%rowtype;
  v_period_closed boolean;
begin
  select * into v_ass from public.assessments where id=p_assessment_id for update;
  if not found then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('grades.publish', v_ass.school_id) then
    raise exception 'PERMISSION_REQUIRED: grades.publish';
  end if;
  select is_closed into v_period_closed from public.academic_periods where id=v_ass.period_id;
  if v_period_closed then raise exception 'PERIOD_CLOSED'; end if;
  if p_is_published and not exists(select 1 from public.grades g where g.assessment_id=v_ass.id) then
    raise exception 'ASSESSMENT_HAS_NO_GRADES';
  end if;
  update public.assessments
  set is_published=p_is_published,
      published_at=case when p_is_published then coalesce(published_at, now()) else null end
  where id=p_assessment_id;
end;
$$;

create or replace function public.create_assessment_type(
  p_code text,
  p_name text,
  p_default_coefficient numeric default 1
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_id uuid;
begin
  select school_id into v_school_id from public.users where id=(select auth.uid());
  if v_school_id is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if not app.is_super_admin() and not app.has_permission('assessments.manage', v_school_id) then
    raise exception 'PERMISSION_REQUIRED: assessments.manage';
  end if;
  if p_default_coefficient <= 0 then raise exception 'ASSESSMENT_TYPE_COEFFICIENT_INVALID'; end if;
  insert into public.assessment_types(school_id,code,name,default_coefficient)
  values(v_school_id,trim(p_code),trim(p_name),p_default_coefficient)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.create_assessment(
  p_school_year_id uuid,
  p_period_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_teacher_id uuid,
  p_assessment_type_id uuid,
  p_title text,
  p_assessment_date date,
  p_max_score numeric,
  p_coefficient numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_id uuid;
  v_default_coefficient numeric;
begin
  select school_id into v_school_id from public.users where id=(select auth.uid());
  if v_school_id is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if not app.is_super_admin() and not app.can_manage_assessment_for_class_subject(v_school_id,p_school_year_id,p_class_id,p_subject_id) then
    raise exception 'PERMISSION_REQUIRED: assessments.manage';
  end if;
  v_default_coefficient := p_coefficient;
  if p_assessment_type_id is not null and p_coefficient is null then
    select default_coefficient into v_default_coefficient from public.assessment_types where id=p_assessment_type_id;
  end if;
  insert into public.assessments(
    school_id,school_year_id,period_id,class_id,subject_id,teacher_id,assessment_type_id,
    title,assessment_date,max_score,coefficient
  ) values (
    v_school_id,p_school_year_id,p_period_id,p_class_id,p_subject_id,p_teacher_id,p_assessment_type_id,
    trim(p_title),p_assessment_date,p_max_score,coalesce(v_default_coefficient,1)
  ) returning id into v_id;
  return v_id;
end;
$$;

-- =========================================================
-- F. NOTES : VALIDATION ET SAISIE ATOMIQUE
-- =========================================================
create or replace function app.validate_grade_021()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ass public.assessments%rowtype;
  v_period public.academic_periods%rowtype;
  v_student_school uuid;
  v_student_enrolled boolean;
begin
  select * into v_ass from public.assessments where id=new.assessment_id;
  if not found then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  if v_ass.is_published and (tg_op='INSERT' or new.score is distinct from old.score or new.observation is distinct from old.observation or new.coefficient is distinct from old.coefficient) then
    raise exception 'PUBLISHED_GRADE_LOCKED';
  end if;
  select is_closed into v_period.is_closed from public.academic_periods where id=v_ass.period_id;
  if v_period.is_closed then raise exception 'PERIOD_CLOSED'; end if;

  select school_id into v_student_school from public.students where id=new.student_id;
  if v_student_school is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  if v_student_school <> v_ass.school_id then raise exception 'GRADE_CROSS_SCHOOL'; end if;

  select exists(
    select 1 from public.enrollments e
    where e.student_id=new.student_id
      and e.school_year_id=v_ass.school_year_id
      and e.class_id=v_ass.class_id
      and e.status='enrolled'
  ) into v_student_enrolled;
  if not v_student_enrolled then raise exception 'STUDENT_NOT_ENROLLED_IN_ASSESSMENT_CLASS'; end if;
  if new.score < 0 or new.score > v_ass.max_score then raise exception 'GRADE_OUT_OF_RANGE'; end if;
  if new.coefficient <= 0 then raise exception 'GRADE_COEFFICIENT_INVALID'; end if;
  new.normalized_score := round((new.score / v_ass.max_score) * 20, 2);
  return new;
end;
$$;

drop trigger if exists trg_021_validate_grade on public.grades;
create trigger trg_021_validate_grade
before insert or update on public.grades
for each row execute function app.validate_grade_021();

create or replace function public.save_assessment_grades(
  p_assessment_id uuid,
  p_grades jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ass public.assessments%rowtype;
  v_period_closed boolean;
  v_school_id uuid;
  v_count integer := 0;
  v_student_id uuid;
  v_score numeric;
  v_observation text;
  v_item jsonb;
  v_duplicate uuid;
begin
  if jsonb_typeof(p_grades) <> 'array' or jsonb_array_length(p_grades)=0 then
    raise exception 'GRADES_PAYLOAD_EMPTY';
  end if;

  select * into v_ass from public.assessments where id=p_assessment_id for update;
  if not found then raise exception 'ASSESSMENT_NOT_FOUND'; end if;
  v_school_id := v_ass.school_id;
  if not app.is_super_admin() and not app.has_permission('grades.publish',v_school_id) and not app.is_teacher_for_assessment(p_assessment_id) then
    if not app.has_permission('grades.enter',v_school_id) then raise exception 'PERMISSION_REQUIRED: grades.enter'; end if;
    raise exception 'TEACHER_ASSESSMENT_SCOPE_REQUIRED';
  end if;
  if v_ass.is_published then raise exception 'PUBLISHED_ASSESSMENT_LOCKED'; end if;
  select is_closed into v_period_closed from public.academic_periods where id=v_ass.period_id;
  if v_period_closed then raise exception 'PERIOD_CLOSED'; end if;

  -- Rejeter les doublons dans le formulaire avant toute écriture.
  select x.student_id into v_duplicate
  from (
    select (e->>'student_id')::uuid as student_id
    from jsonb_array_elements(p_grades) e
    group by (e->>'student_id')::uuid
    having count(*) > 1
  ) x
  limit 1;
  if v_duplicate is not null then raise exception 'DUPLICATE_STUDENT_IN_PAYLOAD:%', v_duplicate; end if;

  for v_item in select * from jsonb_array_elements(p_grades) loop
    v_student_id := (v_item->>'student_id')::uuid;
    v_score := nullif(v_item->>'score','')::numeric;
    v_observation := nullif(trim(v_item->>'observation'),'');
    if v_score is null then raise exception 'GRADE_SCORE_REQUIRED:%', v_student_id; end if;
    if not exists(
      select 1 from public.enrollments e
      where e.student_id=v_student_id
        and e.school_year_id=v_ass.school_year_id
        and e.class_id=v_ass.class_id
        and e.status='enrolled'
    ) then
      raise exception 'STUDENT_NOT_ENROLLED_IN_ASSESSMENT_CLASS:%', v_student_id;
    end if;
    insert into public.grades(assessment_id,student_id,score,coefficient,observation,entered_by)
    values(p_assessment_id,v_student_id,v_score, v_ass.coefficient, v_observation,(select auth.uid()))
    on conflict(assessment_id,student_id) do update
      set score=excluded.score,
          coefficient=excluded.coefficient,
          observation=excluded.observation,
          entered_by=(select auth.uid());
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- =========================================================
-- G. BULLETINS
-- =========================================================
create or replace function app.validate_report_card_lock()
returns trigger
language plpgsql
as $$
begin
  if old.status='published'
     and to_jsonb(new) is distinct from to_jsonb(old)
     and not app.has_permission('grades.publish',new.school_id)
     and not app.has_permission('report_cards.publish',new.school_id)
     and not app.is_super_admin() then
    raise exception 'PUBLISHED_REPORT_CARD_LOCKED';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_report_card_lock on public.report_cards;
create trigger trg_validate_report_card_lock
before update on public.report_cards
for each row execute function app.validate_report_card_lock();

create or replace function public.generate_report_card_draft(
  p_student_id uuid,
  p_school_year_id uuid,
  p_period_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_school uuid;
  v_student_school uuid;
  v_period public.academic_periods%rowtype;
  v_enrollment public.enrollments%rowtype;
  v_class public.classes%rowtype;
  v_report_id uuid;
  v_average numeric;
  v_coefficient numeric;
  v_total numeric := 0;
  v_weight numeric := 0;
  v_item record;
begin
  select school_id into v_user_school from public.users where id=(select auth.uid());
  select school_id into v_student_school from public.students where id=p_student_id;
  if v_user_school is null or v_student_school is null then raise exception 'SCHOOL_CONTEXT_REQUIRED'; end if;
  if v_user_school <> v_student_school then raise exception 'CROSS_SCHOOL_STUDENT'; end if;
  if not app.is_super_admin() and not app.has_permission('report_cards.generate',v_user_school) then
    raise exception 'PERMISSION_REQUIRED: report_cards.generate';
  end if;

  select * into v_period from public.academic_periods where id=p_period_id;
  if not found or v_period.school_year_id <> p_school_year_id then raise exception 'PERIOD_YEAR_MISMATCH'; end if;
  if v_period.is_closed = false and not app.has_permission('report_cards.generate',v_user_school) then
    raise exception 'REPORT_CARD_GENERATION_NOT_AUTHORIZED';
  end if;

  select * into v_enrollment
  from public.enrollments e
  where e.student_id=p_student_id
    and e.school_year_id=p_school_year_id
    and e.status='enrolled'
  order by e.updated_at desc
  limit 1;
  if not found then raise exception 'STUDENT_NOT_ENROLLED'; end if;

  select * into v_class from public.classes where id=v_enrollment.class_id;
  if not found or v_class.level_id is null then raise exception 'CLASS_LEVEL_REQUIRED'; end if;

  if not exists(
    select 1
    from public.grades g
    join public.assessments a on a.id=g.assessment_id
    where g.student_id=p_student_id
      and a.school_year_id=p_school_year_id
      and a.period_id=p_period_id
      and a.class_id=v_enrollment.class_id
      and a.is_published=true
  ) then
    raise exception 'NO_PUBLISHED_GRADES';
  end if;

  select id into v_report_id
  from public.report_cards
  where student_id=p_student_id and period_id=p_period_id
  for update;

  if v_report_id is null then
    insert into public.report_cards(student_id,school_id,school_year_id,period_id,class_id,status,generated_at)
    values(p_student_id,v_user_school,p_school_year_id,p_period_id,v_enrollment.class_id,'draft',now())
    returning id into v_report_id;
  else
    if exists(select 1 from public.report_cards rc where rc.id=v_report_id and rc.status='published') then
      raise exception 'PUBLISHED_REPORT_CARD_EXISTS';
    end if;
    update public.report_cards
    set class_id=v_enrollment.class_id,
        school_year_id=p_school_year_id,
        status='draft',
        generated_at=now(),
        published_at=null,
        updated_at=now()
    where id=v_report_id;
    delete from public.report_card_items where report_card_id=v_report_id;
  end if;

  for v_item in
    select
      sla.subject_id,
      coalesce(sla.coefficient_override,s.coefficient) as effective_coefficient,
      s.name as subject_name
    from public.subject_level_assignments sla
    join public.subjects s on s.id=sla.subject_id
    where sla.school_id=v_user_school
      and sla.school_year_id=p_school_year_id
      and sla.level_id=v_class.level_id
      and sla.is_active=true
      and s.is_active=true
    order by s.name
  loop
    select round(
      sum(g.normalized_score * g.coefficient) / nullif(sum(g.coefficient),0),
      2
    ) into v_average
    from public.grades g
    join public.assessments a on a.id=g.assessment_id
    where g.student_id=p_student_id
      and a.school_year_id=p_school_year_id
      and a.period_id=p_period_id
      and a.class_id=v_enrollment.class_id
      and a.subject_id=v_item.subject_id
      and a.is_published=true;

    if v_average is not null then
      v_coefficient := v_item.effective_coefficient;
      insert into public.report_card_items(report_card_id,subject_id,average,coefficient)
      values(v_report_id,v_item.subject_id,v_average,v_coefficient);
      v_total := v_total + (v_average * v_coefficient);
      v_weight := v_weight + v_coefficient;
    end if;
  end loop;

  if v_weight <= 0 then raise exception 'NO_REPORT_CARD_ITEMS'; end if;
  update public.report_cards
  set general_average=round(v_total/v_weight,2),
      rank=null,
      decision=null,
      status='draft',
      generated_at=coalesce(generated_at,now()),
      published_at=null,
      updated_at=now()
  where id=v_report_id;

  return v_report_id;
end;
$$;

create or replace function public.publish_report_card(p_report_card_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report public.report_cards%rowtype;
  v_period_closed boolean;
begin
  select * into v_report from public.report_cards where id=p_report_card_id for update;
  if not found then raise exception 'REPORT_CARD_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('report_cards.publish',v_report.school_id) then
    raise exception 'PERMISSION_REQUIRED: report_cards.publish';
  end if;
  if v_report.status='published' then return; end if;
  if not exists(select 1 from public.report_card_items where report_card_id=v_report.id) then
    raise exception 'REPORT_CARD_HAS_NO_ITEMS';
  end if;
  select is_closed into v_period_closed from public.academic_periods where id=v_report.period_id;
  if not v_period_closed then
    raise exception 'PERIOD_MUST_BE_CLOSED_BEFORE_REPORT_CARD_PUBLISH';
  end if;
  update public.report_cards
  set status='published', published_at=now(), updated_at=now()
  where id=v_report.id;
end;
$$;

-- =========================================================
-- H. RLS PÉDAGOGIE (on remplace les policies génériques 014)
-- =========================================================
do $$
declare r record;
begin
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname='public'
      and tablename in ('timetable_slots','assessment_types','assessments','grades','grade_audit','report_cards','report_card_items')
  loop
    execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename);
  end loop;
end $$;

-- Emploi du temps : personnel autorisé, enseignant sur son créneau, élèves/parents sur leur classe.
create policy timetable_select_021 on public.timetable_slots
for select to authenticated
using (
  app.is_super_admin()
  or app.has_permission('timetable.view',school_id)
  or app.has_permission('timetable.manage',school_id)
  or app.is_teacher_for_timetable_slot(id)
  or exists(
    select 1 from public.enrollments e
    where e.school_year_id=timetable_slots.school_year_id
      and e.class_id=timetable_slots.class_id
      and e.status='enrolled'
      and (app.is_self_student(e.student_id) or app.is_parent_of_student(e.student_id))
  )
);
create policy timetable_insert_021 on public.timetable_slots
for insert to authenticated
with check (app.is_super_admin() or app.has_permission('timetable.manage',school_id));
create policy timetable_update_021 on public.timetable_slots
for update to authenticated
using (app.is_super_admin() or app.has_permission('timetable.manage',school_id))
with check (app.is_super_admin() or app.has_permission('timetable.manage',school_id));
create policy timetable_delete_021 on public.timetable_slots
for delete to authenticated
using (app.is_super_admin() or app.has_permission('timetable.manage',school_id));

-- Types d'évaluations : staff uniquement.
create policy assessment_types_select_021 on public.assessment_types
for select to authenticated
using (app.is_super_admin() or app.has_permission('assessments.view',school_id) or app.has_permission('assessments.manage',school_id));
create policy assessment_types_insert_021 on public.assessment_types
for insert to authenticated
with check (app.is_super_admin() or app.has_permission('assessments.manage',school_id));
create policy assessment_types_update_021 on public.assessment_types
for update to authenticated
using (app.is_super_admin() or app.has_permission('assessments.manage',school_id))
with check (app.is_super_admin() or app.has_permission('assessments.manage',school_id));
create policy assessment_types_delete_021 on public.assessment_types
for delete to authenticated
using (app.is_super_admin() or app.has_permission('assessments.manage',school_id));

-- Évaluations : enseignants sur leurs affectations, staff sur permissions, élèves/parents en lecture une fois publiées.
create policy assessments_select_021 on public.assessments
for select to authenticated
using (
  app.is_super_admin()
  or app.has_permission('assessments.view',school_id)
  or app.has_permission('assessments.manage',school_id)
  or app.is_teacher_for_assessment(id)
  or (
    is_published=true and exists(
      select 1 from public.enrollments e
      where e.school_year_id=assessments.school_year_id
        and e.class_id=assessments.class_id
        and e.status='enrolled'
        and (app.is_self_student(e.student_id) or app.is_parent_of_student(e.student_id))
    )
  )
);
create policy assessments_insert_021 on public.assessments
for insert to authenticated
with check (
  app.is_super_admin()
  or app.can_manage_assessment_for_class_subject(school_id,school_year_id,class_id,subject_id)
);
create policy assessments_update_021 on public.assessments
for update to authenticated
using (
  app.is_super_admin()
  or app.has_permission('assessments.manage',school_id)
  or app.is_teacher_for_assessment(id)
)
with check (
  app.is_super_admin()
  or app.has_permission('assessments.manage',school_id)
  or app.is_teacher_for_assessment(id)
);
create policy assessments_delete_021 on public.assessments
for delete to authenticated
using (app.is_super_admin() or app.has_permission('assessments.manage',school_id));

-- Notes : élèves/parents uniquement après publication, enseignant sur son élève, staff selon droits.
create policy grades_select_021 on public.grades
for select to authenticated
using (
  app.is_super_admin()
  or app.has_permission('grades.view', (select a.school_id from public.assessments a where a.id=grades.assessment_id))
  or app.has_permission('grades.enter', (select a.school_id from public.assessments a where a.id=grades.assessment_id))
  or app.has_permission('grades.publish', (select a.school_id from public.assessments a where a.id=grades.assessment_id))
  or app.is_teacher_for_student(student_id)
  or exists(
    select 1
    from public.assessments a
    where a.id=grades.assessment_id
      and a.is_published=true
      and (app.is_self_student(student_id) or app.is_parent_of_student(student_id))
  )
);
create policy grades_insert_021 on public.grades
for insert to authenticated
with check (
  exists(
    select 1 from public.assessments a
    where a.id=grades.assessment_id
      and (
        app.is_super_admin()
        or app.has_permission('grades.publish',a.school_id)
        or (app.has_permission('grades.enter',a.school_id) and app.is_teacher_for_assessment(a.id))
      )
  )
);
create policy grades_update_021 on public.grades
for update to authenticated
using (
  exists(
    select 1 from public.assessments a
    where a.id=grades.assessment_id
      and (
        app.is_super_admin()
        or app.has_permission('grades.publish',a.school_id)
        or (app.has_permission('grades.enter',a.school_id) and app.is_teacher_for_assessment(a.id))
      )
  )
)
with check (
  exists(
    select 1 from public.assessments a
    where a.id=grades.assessment_id
      and (
        app.is_super_admin()
        or app.has_permission('grades.publish',a.school_id)
        or (app.has_permission('grades.enter',a.school_id) and app.is_teacher_for_assessment(a.id))
      )
  )
);
create policy grades_delete_021 on public.grades
for delete to authenticated
using (
  exists(select 1 from public.assessments a where a.id=grades.assessment_id and (app.is_super_admin() or app.has_permission('grades.publish',a.school_id)))
);

-- Audit des notes : écriture par trigger uniquement.
create policy grade_audit_select_021 on public.grade_audit
for select to authenticated
using (
  exists(
    select 1 from public.grades g
    join public.assessments a on a.id=g.assessment_id
    where g.id=grade_audit.grade_id
      and (app.is_super_admin() or app.has_permission('audit.view',a.school_id) or app.has_permission('grades.publish',a.school_id))
  )
);

-- Bulletins : élèves/parents publiés, enseignants sur leurs élèves, staff selon permissions.
create policy report_cards_select_021 on public.report_cards
for select to authenticated
using (
  app.is_super_admin()
  or app.has_permission('report_cards.view',school_id)
  or app.has_permission('report_cards.generate',school_id)
  or app.has_permission('report_cards.publish',school_id)
  or app.is_teacher_for_student(student_id)
  or (status='published' and (app.is_self_student(student_id) or app.is_parent_of_student(student_id)))
);
create policy report_cards_insert_021 on public.report_cards
for insert to authenticated
with check (app.is_super_admin() or app.has_permission('report_cards.generate',school_id));
create policy report_cards_update_021 on public.report_cards
for update to authenticated
using (
  app.is_super_admin() or app.has_permission('report_cards.generate',school_id) or app.has_permission('report_cards.publish',school_id)
)
with check (
  app.is_super_admin() or app.has_permission('report_cards.generate',school_id) or app.has_permission('report_cards.publish',school_id)
);
create policy report_cards_delete_021 on public.report_cards
for delete to authenticated
using (app.is_super_admin() or app.has_permission('report_cards.generate',school_id));

create policy report_card_items_select_021 on public.report_card_items
for select to authenticated
using (
  exists(
    select 1 from public.report_cards r
    where r.id=report_card_items.report_card_id
      and (
        app.is_super_admin()
        or app.has_permission('report_cards.view',r.school_id)
        or app.has_permission('report_cards.generate',r.school_id)
        or app.has_permission('report_cards.publish',r.school_id)
        or app.is_teacher_for_student(r.student_id)
        or (r.status='published' and (app.is_self_student(r.student_id) or app.is_parent_of_student(r.student_id)))
      )
  )
);
create policy report_card_items_insert_021 on public.report_card_items
for insert to authenticated
with check (exists(select 1 from public.report_cards r where r.id=report_card_items.report_card_id and (app.is_super_admin() or app.has_permission('report_cards.generate',r.school_id))));
create policy report_card_items_update_021 on public.report_card_items
for update to authenticated
using (exists(select 1 from public.report_cards r where r.id=report_card_items.report_card_id and (app.is_super_admin() or app.has_permission('report_cards.generate',r.school_id))))
with check (exists(select 1 from public.report_cards r where r.id=report_card_items.report_card_id and (app.is_super_admin() or app.has_permission('report_cards.generate',r.school_id))));
create policy report_card_items_delete_021 on public.report_card_items
for delete to authenticated
using (exists(select 1 from public.report_cards r where r.id=report_card_items.report_card_id and (app.is_super_admin() or app.has_permission('report_cards.generate',r.school_id))));

-- =========================================================
-- I. GRANTS MINIMAUX
-- =========================================================
revoke all on public.timetable_slots from anon;
revoke all on public.assessment_types from anon;
revoke all on public.assessments from anon;
revoke all on public.grades from anon;
revoke all on public.grade_audit from anon;
revoke all on public.report_cards from anon;
revoke all on public.report_card_items from anon;

grant select, insert, update, delete on public.timetable_slots to authenticated;
grant select, insert, update, delete on public.assessment_types to authenticated;
grant select, insert, update, delete on public.assessments to authenticated;
grant select, insert, update, delete on public.grades to authenticated;
grant select on public.grade_audit to authenticated;
grant select, insert, update, delete on public.report_cards to authenticated;
grant select, insert, update, delete on public.report_card_items to authenticated;

revoke all on function public.create_timetable_slot(uuid,uuid,uuid,uuid,integer,time,time,text,date,date) from public, anon;
grant execute on function public.create_timetable_slot(uuid,uuid,uuid,uuid,integer,time,time,text,date,date) to authenticated;
revoke all on function public.update_timetable_slot(uuid,uuid,uuid,uuid,uuid,integer,time,time,text,date,date) from public, anon;
grant execute on function public.update_timetable_slot(uuid,uuid,uuid,uuid,uuid,integer,time,time,text,date,date) to authenticated;
revoke all on function public.set_timetable_slot_active(uuid,boolean) from public, anon;
grant execute on function public.set_timetable_slot_active(uuid,boolean) to authenticated;
revoke all on function public.create_assessment_type(text,text,numeric) from public, anon;
grant execute on function public.create_assessment_type(text,text,numeric) to authenticated;
revoke all on function public.create_assessment(uuid,uuid,uuid,uuid,uuid,uuid,text,date,numeric,numeric) from public, anon;
grant execute on function public.create_assessment(uuid,uuid,uuid,uuid,uuid,uuid,text,date,numeric,numeric) to authenticated;
revoke all on function public.set_assessment_published(uuid,boolean) from public, anon;
grant execute on function public.set_assessment_published(uuid,boolean) to authenticated;
revoke all on function public.save_assessment_grades(uuid,jsonb) from public, anon;
grant execute on function public.save_assessment_grades(uuid,jsonb) to authenticated;
revoke all on function public.generate_report_card_draft(uuid,uuid,uuid) from public, anon;
grant execute on function public.generate_report_card_draft(uuid,uuid,uuid) to authenticated;
revoke all on function public.publish_report_card(uuid) from public, anon;
grant execute on function public.publish_report_card(uuid) to authenticated;

-- SECURITY DEFINER : personne ne doit pouvoir appeler les helpers techniques directement.
revoke all on function app.is_teacher_for_assessment(uuid) from public, anon, authenticated;
revoke all on function app.is_teacher_for_timetable_slot(uuid) from public, anon, authenticated;
revoke all on function app.can_manage_assessment_for_class_subject(uuid,uuid,uuid,uuid) from public, anon, authenticated;

comment on table public.assessments is 'Étape 13: évaluations liées à une période, classe, matière et affectation enseignante.';
comment on table public.grades is 'Étape 13: notes individuelles; publication et verrouillage sont gérés côté PostgreSQL.';
comment on table public.report_cards is 'Étape 13: bulletin par élève et période; rank/decision restent null tant que les règles officielles Al Amine ne sont pas fournies.';

commit;
