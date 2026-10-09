-- SIGIA-AMINE — Migration 016: Inscriptions / Réinscriptions
-- Étape 8
--
-- Objectifs :
-- 1) distinguer le dossier d'inscription de la classe définitive ;
-- 2) permettre une inscription "pending" avant l'étape 9 (classes) ;
-- 3) relier une inscription à son admission source ;
-- 4) sécuriser les transitions et relations inter-écoles ;
-- 5) fournir des RPC atomiques pour créer un brouillon d'inscription et finaliser une inscription ;
-- 6) protéger les lectures par RLS selon le rôle et le périmètre.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- A. EXTENSION DU DOSSIER D'INSCRIPTION
-- =========================================================

alter table public.enrollments
  alter column class_id drop not null;

alter table public.enrollments
  add column if not exists registration_number text,
  add column if not exists requested_level_id uuid references public.levels(id) on delete restrict,
  add column if not exists source_admission_id uuid references public.admission_applications(id) on delete set null;

update public.enrollments
set registration_number = coalesce(
  registration_number,
  'INS-' || to_char(coalesce(enrollment_date, current_date), 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
)
where registration_number is null;

alter table public.enrollments
  alter column registration_number set not null;

alter table public.enrollments
  alter column registration_number set default (
    'INS-' || to_char(current_date, 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
  );

create unique index if not exists uq_enrollments_school_registration_number
  on public.enrollments(school_id, registration_number);

create unique index if not exists uq_enrollments_school_source_admission
  on public.enrollments(school_id, source_admission_id)
  where source_admission_id is not null;

create index if not exists idx_enrollments_school_status_year
  on public.enrollments(school_id, status, school_year_id, enrollment_date desc);

create index if not exists idx_enrollments_school_student
  on public.enrollments(school_id, student_id, enrollment_date desc);

create index if not exists idx_enrollments_school_level
  on public.enrollments(school_id, requested_level_id, status)
  where requested_level_id is not null;

create index if not exists idx_enrollments_school_source_admission
  on public.enrollments(school_id, source_admission_id)
  where source_admission_id is not null;

-- Une inscription en préparation peut ne pas encore avoir de classe.
-- Dès qu'elle est approuvée/enregistrée/terminée, une classe est obligatoire.
-- La classe doit aussi appartenir à la même année et au niveau demandé lorsqu'un niveau a été précisé.
create or replace function app.validate_enrollment_step8()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
declare
  student_school uuid;
  year_school uuid;
  class_school uuid;
  class_year uuid;
  class_level uuid;
  level_school uuid;
  admission_school uuid;
  admission_year uuid;
  admission_status app.enrollment_status;
begin
  select school_id into student_school from public.students where id = new.student_id;
  select school_id into year_school from public.school_years where id = new.school_year_id;

  if student_school is null or student_school <> new.school_id then
    raise exception 'ENROLLMENT_CROSS_SCHOOL_STUDENT';
  end if;

  if year_school is null or year_school <> new.school_id then
    raise exception 'ENROLLMENT_CROSS_SCHOOL_YEAR';
  end if;

  if new.requested_level_id is not null then
    select school_id into level_school from public.levels where id = new.requested_level_id;
    if level_school is null or level_school <> new.school_id then
      raise exception 'ENROLLMENT_CROSS_SCHOOL_LEVEL';
    end if;
  end if;

  if new.class_id is not null then
    select school_id, school_year_id, level_id
      into class_school, class_year, class_level
      from public.classes
     where id = new.class_id;

    if class_school is null or class_school <> new.school_id then
      raise exception 'ENROLLMENT_CROSS_SCHOOL_CLASS';
    end if;

    if class_year <> new.school_year_id then
      raise exception 'ENROLLMENT_CLASS_YEAR_MISMATCH';
    end if;

    if new.requested_level_id is not null and class_level is distinct from new.requested_level_id then
      raise exception 'ENROLLMENT_CLASS_LEVEL_MISMATCH';
    end if;
  end if;

  if new.source_admission_id is not null then
    select school_id, desired_year_id, status
      into admission_school, admission_year, admission_status
      from public.admission_applications
     where id = new.source_admission_id;

    if admission_school is null or admission_school <> new.school_id then
      raise exception 'ENROLLMENT_CROSS_SCHOOL_ADMISSION';
    end if;

    if admission_year is distinct from new.school_year_id then
      raise exception 'ENROLLMENT_ADMISSION_YEAR_MISMATCH';
    end if;

    if admission_status not in ('approved','enrolled') then
      raise exception 'ENROLLMENT_SOURCE_ADMISSION_NOT_APPROVED';
    end if;
  end if;

  if new.status in ('approved','enrolled','completed') and new.class_id is null then
    raise exception 'ENROLLMENT_CLASS_REQUIRED';
  end if;

  -- Une même personne ne peut avoir deux dossiers actifs pour la même année.
  if new.status in ('pending','approved','enrolled') then
    if exists (
      select 1
        from public.enrollments e
       where e.student_id = new.student_id
         and e.school_year_id = new.school_year_id
         and e.status in ('pending','approved','enrolled')
         and e.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) then
      raise exception 'DUPLICATE_ACTIVE_ENROLLMENT';
    end if;
  end if;

  -- Capacité vérifiée lorsqu'une classe est effectivement attribuée et que le dossier devient actif.
  if new.class_id is not null and new.status in ('approved','enrolled') then
    if (select capacity from public.classes where id = new.class_id) is not null
       and (
         select count(*)
           from public.enrollments e
          where e.class_id = new.class_id
            and e.status = 'enrolled'
            and e.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
       ) >= (select capacity from public.classes where id = new.class_id) then
      raise exception 'CLASS_CAPACITY_REACHED';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_enrollment_step8 on public.enrollments;
create trigger trg_validate_enrollment_step8
before insert or update on public.enrollments
for each row execute function app.validate_enrollment_step8();

-- =========================================================
-- B. TRANSITIONS D'INSCRIPTION
-- =========================================================

create or replace function app.validate_enrollment_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending' then
      raise exception 'ENROLLMENT_STATUS: une nouvelle inscription doit commencer en pending';
    end if;
    return new;
  end if;

  if old.status = 'completed' then
    raise exception 'ENROLLMENT_STATUS: une inscription terminée est immuable';
  end if;

  if old.status = 'cancelled' and new.status <> 'pending' then
    raise exception 'ENROLLMENT_STATUS: une inscription annulée doit être réouverte en pending';
  end if;

  if old.status = new.status then
    return new;
  end if;

  if old.status = 'pending' and new.status in ('approved','cancelled') then
    return new;
  end if;

  if old.status = 'approved' and new.status in ('enrolled','cancelled','pending') then
    return new;
  end if;

  if old.status = 'enrolled' and new.status in ('completed','cancelled') then
    return new;
  end if;

  if old.status = 'cancelled' and new.status = 'pending' then
    return new;
  end if;

  raise exception 'ENROLLMENT_STATUS: transition % -> % interdite', old.status, new.status;
end;
$$;

drop trigger if exists trg_enrollment_status_transition on public.enrollments;
create trigger trg_enrollment_status_transition
before update of status on public.enrollments
for each row execute function app.validate_enrollment_status_transition();

-- Maintient le statut administratif de l'élève sans écraser un statut terminal.
create or replace function app.sync_student_status_from_enrollment()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
begin
  if new.status = 'enrolled' then
    update public.students
       set status = 'active',
           residence_type = new.residence_type,
           updated_at = now()
     where id = new.student_id
       and school_id = new.school_id
       and status in ('prospect','active');
  elsif new.status = 'completed' then
    update public.students
       set updated_at = now()
     where id = new.student_id
       and school_id = new.school_id;
  elsif new.status = 'cancelled' then
    update public.students
       set updated_at = now()
     where id = new.student_id
       and school_id = new.school_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_student_status_from_enrollment on public.enrollments;
create trigger trg_sync_student_status_from_enrollment
after insert or update of status, residence_type on public.enrollments
for each row execute function app.sync_student_status_from_enrollment();

-- =========================================================
-- C. PERMISSIONS / RLS
-- =========================================================

insert into public.permissions(code,name,module,action,description)
values
  ('enrollments.view','Consulter les inscriptions','enrollments','view','Consulter les dossiers d’inscription et leur historique'),
  ('enrollments.manage','Gérer les inscriptions','enrollments','manage','Créer, préparer, valider, annuler et finaliser les inscriptions')
on conflict(code) do update set
  name = excluded.name,
  module = excluded.module,
  action = excluded.action,
  description = excluded.description;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('enrollments.view','enrollments.manage')
where r.code in ('super_admin','founder','direction','admin')
on conflict do nothing;

-- On remplace les policies génériques 014 par une version sensible au périmètre.
drop policy if exists enrollments_select_secure on public.enrollments;
drop policy if exists enrollments_insert_secure on public.enrollments;
drop policy if exists enrollments_update_secure on public.enrollments;
drop policy if exists enrollments_delete_secure on public.enrollments;

create policy enrollments_select_016
on public.enrollments
for select
to authenticated
using (
  app.has_permission('enrollments.view', school_id)
  or app.has_permission('enrollments.manage', school_id)
  or app.is_self_student(student_id)
  or app.is_parent_of_student(student_id)
  or app.is_super_admin()
);

create policy enrollments_insert_016
on public.enrollments
for insert
to authenticated
with check (
  app.has_permission('enrollments.manage', school_id)
  or app.is_super_admin()
);

create policy enrollments_update_016
on public.enrollments
for update
to authenticated
using (
  app.has_permission('enrollments.manage', school_id)
  or app.is_super_admin()
)
with check (
  app.has_permission('enrollments.manage', school_id)
  or app.is_super_admin()
);

create policy enrollments_delete_016
on public.enrollments
for delete
to authenticated
using (
  app.has_permission('enrollments.manage', school_id)
  or app.is_super_admin()
);

-- =========================================================
-- D. RPC ATOMIQUES
-- =========================================================

create or replace function public.prepare_enrollment_from_admission(
  p_admission_id uuid,
  p_parent_relationship app.relationship_type default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_user_id uuid := auth.uid();
  v_admission public.admission_applications%rowtype;
  v_student_id uuid;
  v_enrollment_id uuid;
  v_student_number text;
  v_existing uuid;
begin
  select * into v_admission
    from public.admission_applications
   where id = p_admission_id
   for update;

  if not found then
    raise exception 'ADMISSION_NOT_FOUND';
  end if;

  v_school_id := v_admission.school_id;

  if v_user_id is null or not (app.has_permission('enrollments.manage', v_school_id) or app.is_super_admin()) then
    raise exception 'FORBIDDEN_ENROLLMENT_MANAGE';
  end if;

  if v_admission.status <> 'approved' then
    raise exception 'ADMISSION_MUST_BE_APPROVED';
  end if;

  select id into v_existing
    from public.enrollments
   where school_id = v_school_id
     and source_admission_id = p_admission_id;

  if v_existing is not null then
    return jsonb_build_object('enrollment_id', v_existing, 'student_id', v_admission.student_id, 'existing', true);
  end if;

  v_student_id := v_admission.student_id;

  if v_student_id is null then
    v_student_number := 'ELV-' || to_char(coalesce((select start_date from public.school_years where id=v_admission.desired_year_id), current_date), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

    insert into public.students(
      school_id, student_number, first_name, last_name, gender,
      date_of_birth, place_of_birth, nationality, address,
      residence_type, status
    )
    values (
      v_school_id, v_student_number,
      coalesce(v_admission.candidate_first_name, split_part(v_admission.applicant_name, ' ', 1)),
      coalesce(v_admission.candidate_last_name, nullif(trim(substr(v_admission.applicant_name, length(split_part(v_admission.applicant_name, ' ', 1)) + 2)), ''), v_admission.applicant_name),
      v_admission.candidate_gender,
      v_admission.candidate_date_of_birth,
      v_admission.candidate_place_of_birth,
      v_admission.candidate_nationality,
      v_admission.candidate_address,
      coalesce(v_admission.desired_residence_type, 'external'::app.residence_type),
      'prospect'
    )
    returning id into v_student_id;

    update public.admission_applications
       set student_id = v_student_id,
           updated_at = now()
     where id = p_admission_id;
  else
    if not exists (select 1 from public.students where id=v_student_id and school_id=v_school_id) then
      raise exception 'ADMISSION_STUDENT_CROSS_SCHOOL';
    end if;
  end if;

  if v_admission.primary_parent_id is not null and p_parent_relationship is not null then
    if not exists (
      select 1 from public.parents
       where id = v_admission.primary_parent_id
         and school_id = v_school_id
    ) then
      raise exception 'ADMISSION_PARENT_CROSS_SCHOOL';
    end if;

    insert into public.student_parents(
      student_id, parent_id, relationship, is_primary,
      has_financial_responsibility, receives_notifications
    )
    values (
      v_student_id, v_admission.primary_parent_id, p_parent_relationship, true, true, true
    )
    on conflict (student_id,parent_id) do update set
      relationship = excluded.relationship,
      is_primary = true,
      has_financial_responsibility = true,
      receives_notifications = true;
  end if;

  insert into public.enrollments(
    school_id, student_id, school_year_id, class_id,
    requested_level_id, source_admission_id,
    residence_type, status, is_reenrollment,
    registration_fee, notes
  )
  values (
    v_school_id, v_student_id, v_admission.desired_year_id, null,
    v_admission.desired_level_id, p_admission_id,
    coalesce(v_admission.desired_residence_type, 'external'::app.residence_type),
    'pending', false, 0,
    'Créée depuis la préinscription ' || v_admission.application_number
  )
  returning id into v_enrollment_id;

  return jsonb_build_object('enrollment_id', v_enrollment_id, 'student_id', v_student_id, 'existing', false);
end;
$$;

create or replace function public.create_reenrollment_draft(
  p_student_id uuid,
  p_school_year_id uuid,
  p_residence_type app.residence_type default 'external'
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_user_id uuid := auth.uid();
  v_level_id uuid;
  v_enrollment_id uuid;
begin
  select school_id into v_school_id from public.students where id = p_student_id;
  if v_school_id is null then raise exception 'STUDENT_NOT_FOUND'; end if;

  if v_user_id is null or not (app.has_permission('enrollments.manage', v_school_id) or app.is_super_admin()) then
    raise exception 'FORBIDDEN_ENROLLMENT_MANAGE';
  end if;

  if not exists (select 1 from public.school_years where id=p_school_year_id and school_id=v_school_id) then
    raise exception 'SCHOOL_YEAR_CROSS_SCHOOL';
  end if;

  if exists (
    select 1 from public.enrollments
     where student_id=p_student_id
       and school_year_id=p_school_year_id
       and status in ('pending','approved','enrolled')
  ) then
    raise exception 'DUPLICATE_ACTIVE_ENROLLMENT';
  end if;

  select c.level_id into v_level_id
    from public.enrollments e
    join public.classes c on c.id=e.class_id
   where e.student_id=p_student_id
     and e.status in ('enrolled','completed')
   order by e.enrollment_date desc
   limit 1;

  insert into public.enrollments(
    school_id, student_id, school_year_id, class_id,
    requested_level_id, source_admission_id,
    residence_type, status, is_reenrollment,
    registration_fee, notes
  )
  values (
    v_school_id, p_student_id, p_school_year_id, null,
    v_level_id, null,
    p_residence_type, 'pending', true, 0,
    'Brouillon de réinscription'
  )
  returning id into v_enrollment_id;

  return jsonb_build_object('enrollment_id', v_enrollment_id, 'student_id', p_student_id, 'existing', false);
end;
$$;

create or replace function public.finalize_enrollment(
  p_enrollment_id uuid,
  p_class_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_user_id uuid := auth.uid();
  v_enrollment public.enrollments%rowtype;
begin
  select * into v_enrollment from public.enrollments where id=p_enrollment_id;
  if not found then raise exception 'ENROLLMENT_NOT_FOUND'; end if;
  v_school_id := v_enrollment.school_id;

  if v_user_id is null or not (app.has_permission('enrollments.manage', v_school_id) or app.is_super_admin()) then
    raise exception 'FORBIDDEN_ENROLLMENT_MANAGE';
  end if;

  if v_enrollment.status not in ('pending','approved') then
    raise exception 'ENROLLMENT_NOT_READY_TO_FINALIZE';
  end if;

  if p_class_id is null then
    raise exception 'CLASS_REQUIRED_TO_FINALIZE';
  end if;

  update public.enrollments
     set class_id = p_class_id,
         status = 'enrolled',
         updated_at = now()
   where id = p_enrollment_id;

  return jsonb_build_object('enrollment_id', p_enrollment_id, 'status', 'enrolled');
end;
$$;

-- Les fonctions de mutation restent appelables via RPC mais valident toujours l'utilisateur et l'école.
revoke all on function public.prepare_enrollment_from_admission(uuid,app.relationship_type) from public;
revoke all on function public.create_reenrollment_draft(uuid,uuid,app.residence_type) from public;
revoke all on function public.finalize_enrollment(uuid,uuid) from public;
grant execute on function public.prepare_enrollment_from_admission(uuid,app.relationship_type) to authenticated;
grant execute on function public.create_reenrollment_draft(uuid,uuid,app.residence_type) to authenticated;
grant execute on function public.finalize_enrollment(uuid,uuid) to authenticated;

comment on table public.enrollments is 'Inscriptions et réinscriptions : un dossier pending peut être créé avant l’affectation à une classe; approved/enrolled/completed exigent une classe.';
comment on column public.enrollments.registration_number is 'Référence unique de l’inscription dans l’école.';
comment on column public.enrollments.requested_level_id is 'Niveau demandé ou hérité avant affectation définitive à une classe.';
comment on column public.enrollments.source_admission_id is 'Préinscription/admission ayant donné naissance à cette inscription.';

commit;
