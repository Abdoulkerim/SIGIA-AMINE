-- SIGIA-AMINE
-- Migration 013: communication_ai_audit_logic_seed
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Communication/IA/audit tables, indexes, base triggers/functions/calculations, RBAC seed and views. V1 RLS section is intentionally not imported; migration 014 is authoritative for access control.

-- 2. FONCTIONS DE SÉCURITÉ
-- =========================================================
create or replace function app.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create or replace function app.my_school_ids()
returns setof uuid
language sql stable security definer set search_path=public,app
as $$
  select ur.school_id from public.user_roles ur
  where ur.user_id=auth.uid() and ur.is_active=true and ur.school_id is not null
  union
  select u.school_id from public.users u
  where u.id=auth.uid() and u.school_id is not null
$$;

create or replace function app.is_super_admin()
returns boolean language sql stable security definer set search_path=public,app
as $$
  select exists(
    select 1 from public.user_roles ur
    join public.roles r on r.id=ur.role_id
    where ur.user_id=auth.uid() and ur.is_active=true and r.code='super_admin'
  )
$$;

create or replace function app.has_permission(p_code text,p_school_id uuid default null)
returns boolean language sql stable security definer set search_path=public,app
as $$
  select app.is_super_admin() or exists(
    select 1
    from public.user_roles ur
    join public.role_permissions rp on rp.role_id=ur.role_id
    join public.permissions p on p.id=rp.permission_id
    where ur.user_id=auth.uid()
      and ur.is_active=true
      and p.code=p_code
      and (p_school_id is null or ur.school_id=p_school_id)
  )
$$;

-- =========================================================

-- 19. COMMUNICATION / IA / AUDIT
-- =========================================================
create table if not exists public.announcements(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  content text not null,
  audience jsonb not null default '[]'::jsonb,
  published_at timestamptz,
  expires_at timestamptz,
  created_by uuid references public.users(id) on delete set null,
  status text not null default 'draft',
  created_at timestamptz not null default now()
);

create table if not exists public.notifications(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  recipient_user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  notification_type text,
  related_table text,
  related_id uuid,
  read_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_preferences(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  whatsapp_enabled boolean not null default false,
  push_enabled boolean not null default true,
  preferences jsonb not null default '{}'::jsonb
);

create table if not exists public.ai_conversations(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  title text,
  scope jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_messages(
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check(role in ('system','user','assistant','tool')),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_alerts(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  alert_type text not null,
  severity integer not null default 1 check(severity between 1 and 5),
  title text not null,
  description text not null,
  related_table text,
  related_id uuid,
  status text not null default 'open',
  generated_at timestamptz not null default now(),
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz
);

create table if not exists public.audit_logs(
  id bigint generated always as identity primary key,
  school_id uuid references public.schools(id) on delete set null,
  actor_user_id uuid references public.users(id) on delete set null,
  action text not null,
  table_name text,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

-- =========================================================

-- 20. INDEXES
-- =========================================================
create index if not exists idx_users_school on public.users(school_id);
create index if not exists idx_user_roles_user_school on public.user_roles(user_id,school_id);
create index if not exists idx_school_year_current on public.school_years(school_id,is_current);
create index if not exists idx_students_school_name on public.students(school_id,last_name,first_name);
create index if not exists idx_students_status on public.students(school_id,status);
create index if not exists idx_enrollments_student_year on public.enrollments(student_id,school_year_id);
create index if not exists idx_enrollments_class on public.enrollments(class_id);
create index if not exists idx_student_parents_parent on public.student_parents(parent_id);
create index if not exists idx_employees_school_name on public.employees(school_id,last_name,first_name);
create index if not exists idx_teacher_assignments_teacher on public.teacher_assignments(teacher_id);
create index if not exists idx_teacher_assignments_class on public.teacher_assignments(class_id);
create index if not exists idx_assessments_class_period on public.assessments(class_id,period_id);
create index if not exists idx_grades_student on public.grades(student_id);
create index if not exists idx_report_cards_student_period on public.report_cards(student_id,period_id);
create index if not exists idx_attendance_date on public.attendance_sessions(school_id,session_date);
create index if not exists idx_attendance_student on public.attendance_records(student_id);
create index if not exists idx_discipline_student_date on public.discipline_events(student_id,event_date);
create index if not exists idx_boarding_student on public.boarding_assignments(student_id);
create index if not exists idx_payments_student_date on public.payments(student_id,payment_date);
create index if not exists idx_invoices_student_status on public.invoices(student_id,status);
create index if not exists idx_cash_account_date on public.cash_transactions(cash_account_id,transaction_date);
create index if not exists idx_stock_product_location on public.stock_movements(product_id,location_id,movement_date);
create index if not exists idx_notifications_user on public.notifications(recipient_user_id,read_at);
create index if not exists idx_audit_school_date on public.audit_logs(school_id,created_at desc);

-- =========================================================

-- 21. TRIGGERS MÉTIER
-- =========================================================
drop trigger if exists trg_schools_updated_at on public.schools;
create trigger trg_schools_updated_at before update on public.schools for each row execute function app.set_updated_at();
drop trigger if exists trg_settings_updated_at on public.school_settings;
create trigger trg_settings_updated_at before update on public.school_settings for each row execute function app.set_updated_at();
drop trigger if exists trg_years_updated_at on public.school_years;
create trigger trg_years_updated_at before update on public.school_years for each row execute function app.set_updated_at();
drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users for each row execute function app.set_updated_at();
drop trigger if exists trg_classes_updated_at on public.classes;
create trigger trg_classes_updated_at before update on public.classes for each row execute function app.set_updated_at();
drop trigger if exists trg_programs_updated_at on public.programs;
create trigger trg_programs_updated_at before update on public.programs for each row execute function app.set_updated_at();
drop trigger if exists trg_employees_updated_at on public.employees;
create trigger trg_employees_updated_at before update on public.employees for each row execute function app.set_updated_at();
drop trigger if exists trg_students_updated_at on public.students;
create trigger trg_students_updated_at before update on public.students for each row execute function app.set_updated_at();
drop trigger if exists trg_parents_updated_at on public.parents;
create trigger trg_parents_updated_at before update on public.parents for each row execute function app.set_updated_at();
drop trigger if exists trg_enrollments_updated_at on public.enrollments;
create trigger trg_enrollments_updated_at before update on public.enrollments for each row execute function app.set_updated_at();
drop trigger if exists trg_assessments_updated_at on public.assessments;
create trigger trg_assessments_updated_at before update on public.assessments for each row execute function app.set_updated_at();
drop trigger if exists trg_grades_updated_at on public.grades;
create trigger trg_grades_updated_at before update on public.grades for each row execute function app.set_updated_at();
drop trigger if exists trg_report_cards_updated_at on public.report_cards;
create trigger trg_report_cards_updated_at before update on public.report_cards for each row execute function app.set_updated_at();
drop trigger if exists trg_invoices_updated_at on public.invoices;
create trigger trg_invoices_updated_at before update on public.invoices for each row execute function app.set_updated_at();

create or replace function app.ensure_single_current_year()
returns trigger language plpgsql as $$
begin
  if new.is_current then
    update public.school_years set is_current=false
    where school_id=new.school_id and id<>new.id;
  end if;
  return new;
end $$;

drop trigger if exists trg_single_current_year on public.school_years;
create trigger trg_single_current_year before insert or update on public.school_years
for each row execute function app.ensure_single_current_year();

create or replace function app.validate_grade()
returns trigger language plpgsql as $$
declare v_max numeric;
begin
  select max_score into v_max from public.assessments where id=new.assessment_id;
  if new.score>v_max then raise exception 'La note % dépasse le barème %',new.score,v_max; end if;
  if v_max is null or v_max <= 0 then
    raise exception 'Barème invalide pour l''évaluation %', new.assessment_id;
  end if;
  new.normalized_score=round((new.score/v_max)*20,2);
  return new;
end $$;

drop trigger if exists trg_validate_grade on public.grades;
create trigger trg_validate_grade before insert or update on public.grades
for each row execute function app.validate_grade();

create or replace function app.audit_grade_change()
returns trigger language plpgsql as $$
begin
  if tg_op='UPDATE' and old.score is distinct from new.score then
    insert into public.grade_audit(grade_id,old_score,new_score,changed_by,reason)
    values(new.id,old.score,new.score,auth.uid(),'Modification de note');
  end if;
  return new;
end $$;

drop trigger if exists trg_audit_grade_change on public.grades;
create trigger trg_audit_grade_change after update on public.grades
for each row execute function app.audit_grade_change();

-- =========================================================

-- 22. FONCTIONS DE CALCUL
-- =========================================================
create or replace function app.student_balance(p_student_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select coalesce((select sum(amount_due) from public.student_charges where student_id=p_student_id),0)
       - coalesce((select sum(pa.amount) from public.payment_allocations pa
                   join public.student_charges sc on sc.id=pa.student_charge_id
                   where sc.student_id=p_student_id),0)
$$;

create or replace function app.invoice_balance(p_invoice_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select coalesce((select total from public.invoices where id=p_invoice_id),0)
       - coalesce((select sum(amount) from public.payment_allocations where invoice_id=p_invoice_id),0)
$$;

create or replace function app.subject_average(p_student_id uuid,p_subject_id uuid,p_period_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select round(sum(g.normalized_score*g.coefficient)/nullif(sum(g.coefficient),0),2)
  from public.grades g
  join public.assessments a on a.id=g.assessment_id
  where g.student_id=p_student_id and a.subject_id=p_subject_id
    and a.period_id=p_period_id and a.is_published=true
$$;

create or replace function app.stock_quantity(p_product_id uuid,p_location_id uuid)
returns numeric language sql stable security definer set search_path=public,app
as $$
  select coalesce(sum(case
    when movement_type in ('purchase','return','adjustment','production_in') then quantity
    when movement_type in ('sale','issue','loss','transfer','production_out') then -quantity
    else 0 end),0)
  from public.stock_movements
  where product_id=p_product_id and location_id=p_location_id
$$;

-- =========================================================

-- 24. RÔLES INITIAUX
-- =========================================================
insert into public.roles(code,name,description) values
('super_admin','Administrateur système','Administration technique globale'),
('founder','Coordonnateur / Fondateur','Pilotage global'),
('direction','Direction','Pilotage général'),
('admin','Administration / Secrétariat','Dossiers, inscriptions, documents'),
('academic_director','Direction des études','Pédagogie et résultats'),
('teacher','Enseignant','Classes, présences, notes'),
('accountant','Comptable / Finance','Facturation, paiements, dépenses'),
('boarding_manager','Responsable internat','Internat et restauration'),
('supervisor','Surveillant / Encadrement','Présences et discipline'),
('tahfiz_manager','Responsable Tahfiz','Suivi Tahfiz'),
('arabic_manager','Responsable Arabe','Formation arabe'),
('wushu_manager','Responsable Wushu','Wushu'),
('catering_manager','Responsable restauration','Menus et repas'),
('agriculture_manager','Responsable agriculture','Production agricole'),
('livestock_manager','Responsable élevage','Cheptel et production'),
('hr_manager','Responsable personnel','Ressources humaines'),
('stock_manager','Responsable stocks','Stocks et inventaires'),
('parent','Parent / Tuteur','Espace famille'),
('student','Élève','Espace personnel'),
('it_admin','Administrateur informatique','Comptes, sécurité, configuration')
on conflict(code) do nothing;

insert into public.permissions(code,name,module,action,description) values
('users.manage','Gérer utilisateurs','users','manage','Créer/modifier/désactiver les comptes'),
('users.roles.manage','Gérer rôles','users','roles','Attribuer les rôles'),
('students.view','Consulter élèves','students','view','Consulter les dossiers autorisés'),
('students.manage','Gérer élèves','students','manage','Créer/modifier les dossiers'),
('parents.view','Consulter parents','parents','view','Consulter les parents'),
('parents.manage','Gérer parents','parents','manage','Créer/modifier les parents'),
('enrollments.manage','Gérer inscriptions','enrollments','manage','Admissions et inscriptions'),
('classes.manage','Gérer classes','academic','manage','Classes et affectations'),
('subjects.manage','Gérer matières','academic','manage','Matières et coefficients'),
('teachers.manage','Gérer enseignants','academic','manage','Affectations pédagogiques'),
('timetable.manage','Gérer emploi du temps','academic','manage','Créneaux et conflits'),
('assessments.manage','Gérer évaluations','grades','manage','Créer les évaluations'),
('grades.enter','Saisir notes','grades','enter','Saisie/modification des notes'),
('grades.publish','Publier notes','grades','publish','Publication des notes'),
('report_cards.generate','Générer bulletins','grades','report_cards','Générer les bulletins'),
('attendance.manage','Gérer présence','attendance','manage','Appel et assiduité'),
('discipline.manage','Gérer discipline','discipline','manage','Incidents et suivi éducatif'),
('finance.view','Consulter finance','finance','view','Consultation financière'),
('finance.manage','Gérer finance','finance','manage','Facturation et paiements'),
('expenses.manage','Gérer dépenses','finance','expenses','Dépenses et justificatifs'),
('cash.manage','Gérer caisse','finance','cash','Caisse et clôtures'),
('boarding.manage','Gérer internat','boarding','manage','Chambres, lits, mouvements'),
('catering.manage','Gérer restauration','catering','manage','Menus et repas'),
('tahfiz.manage','Gérer Tahfiz','tahfiz','manage','Suivi Tahfiz'),
('arabic.manage','Gérer arabe','arabic','manage','Formation arabe'),
('wushu.manage','Gérer Wushu','wushu','manage','Wushu'),
('hr.manage','Gérer personnel','hr','manage','Personnel et congés'),
('stock.manage','Gérer stocks','stock','manage','Stocks et inventaires'),
('purchases.manage','Gérer achats','purchases','manage','Fournisseurs et commandes'),
('agriculture.manage','Gérer agriculture','agriculture','manage','Production agricole'),
('livestock.manage','Gérer élevage','livestock','manage','Cheptel'),
('communication.manage','Gérer communication','communication','manage','Annonces'),
('reports.view','Consulter rapports','reports','view','Statistiques et tableaux de bord'),
('ai.use','Utiliser IA','ai','use','Assistant et analyses'),
('audit.view','Consulter audit','security','audit','Journal des opérations'),
('documents.view','Consulter documents','documents','view','Consulter les documents autorisés'),
('documents.manage','Gérer documents','documents','manage','Créer/modifier/archiver les documents'),
('settings.manage','Gérer paramètres','settings','manage','Paramétrage')
on conflict(code) do nothing;

-- Super-admin et fondateur : toutes les permissions.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code in('super_admin','founder') on conflict do nothing;

-- Matrice métier initiale.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','students.manage','parents.view','parents.manage','enrollments.manage','classes.manage','subjects.manage','documents.view','documents.manage','communication.manage','reports.view')
where r.code='admin' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','classes.manage','subjects.manage','teachers.manage','timetable.manage','assessments.manage','grades.enter','grades.publish','report_cards.generate','attendance.manage','reports.view')
where r.code='academic_director' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','assessments.manage','grades.enter','attendance.manage','reports.view')
where r.code='teacher' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('finance.view','finance.manage','expenses.manage','cash.manage','reports.view')
where r.code='accountant' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','boarding.manage','catering.manage','attendance.manage','discipline.manage','reports.view')
where r.code='boarding_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','attendance.manage','discipline.manage')
where r.code='supervisor' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','tahfiz.manage','reports.view')
where r.code='tahfiz_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','arabic.manage','reports.view')
where r.code='arabic_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('students.view','wushu.manage','reports.view')
where r.code='wushu_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('catering.manage','stock.manage','purchases.manage','reports.view')
where r.code='catering_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('agriculture.manage','stock.manage','finance.view','reports.view')
where r.code='agriculture_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('livestock.manage','stock.manage','finance.view','reports.view')
where r.code='livestock_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('hr.manage','reports.view')
where r.code='hr_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('stock.manage','purchases.manage','reports.view')
where r.code='stock_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('users.manage','users.roles.manage','settings.manage','audit.view')
where r.code='it_admin' on conflict do nothing;

-- =========================================================

-- 25. VUES DE PILOTAGE
-- =========================================================
create or replace view public.v_class_effectives as
select c.id class_id,c.school_id,c.school_year_id,c.name class_name,
count(e.student_id) filter(where e.status='enrolled') active_students
from public.classes c
left join public.enrollments e on e.class_id=c.id
group by c.id,c.school_id,c.school_year_id,c.name;

create or replace view public.v_student_financial_summary as
select
  s.id student_id,
  s.school_id,
  s.student_number,
  s.first_name,
  s.last_name,
  coalesce((select sum(sc.amount_due)
            from public.student_charges sc
            where sc.student_id=s.id),0) total_due,
  coalesce((select sum(pa.amount)
            from public.payment_allocations pa
            join public.student_charges sc on sc.id=pa.student_charge_id
            join public.payments p on p.id=pa.payment_id
            where sc.student_id=s.id and p.status='paid'),0) total_paid,
  coalesce((select sum(sc.amount_due)
            from public.student_charges sc
            where sc.student_id=s.id),0)
  -
  coalesce((select sum(pa.amount)
            from public.payment_allocations pa
            join public.student_charges sc on sc.id=pa.student_charge_id
            join public.payments p on p.id=pa.payment_id
            where sc.student_id=s.id and p.status='paid'),0) balance
from public.students s;

comment on table public.students is 'Dossier numérique central de l’élève.';
comment on table public.enrollments is 'Scolarité annuelle : classe, régime, statut et historique.';
comment on table public.grades is 'Notes brutes et notes normalisées; les modifications doivent être auditées.';
comment on table public.payments is 'Encaissements financiers.';
comment on table public.audit_logs is 'Traçabilité des opérations sensibles.';
comment on table public.ai_alerts is 'Alertes issues des règles métier et/ou de l’IA; validation humaine obligatoire.';

commit;

-- FIN SIGIA-AMINE V1.0

-- Additional FK/search-path indexes validated during audit 1A.1.
create index if not exists idx_users_email on public.users(lower(email)) where email is not null;
create index if not exists idx_user_roles_school_role on public.user_roles(school_id,role_id) where is_active;
create index if not exists idx_student_parents_parent_student on public.student_parents(parent_id,student_id);
create index if not exists idx_enrollment_history_student on public.enrollment_history(student_id,changed_at desc);
create index if not exists idx_documents_parent on public.documents(school_id,parent_id,created_at desc);
create index if not exists idx_documents_employee on public.documents(school_id,employee_id,created_at desc);
create index if not exists idx_report_card_items_report on public.report_card_items(report_card_id);
create index if not exists idx_fee_schedules_school_year on public.fee_schedules(school_id,school_year_id);
create index if not exists idx_student_charges_student_status on public.student_charges(school_id,student_id,status);
create index if not exists idx_receipts_payment on public.receipts(payment_id);
create index if not exists idx_expenses_school_date on public.expenses(school_id,expense_date desc);
create index if not exists idx_stock_balances_location_product on public.stock_balances(location_id,product_id);
create index if not exists idx_purchase_orders_supplier_date on public.purchase_orders(school_id,supplier_id,order_date desc);
create index if not exists idx_employee_leaves_employee_dates on public.employee_leaves(school_id,employee_id,start_date,end_date);

commit;
