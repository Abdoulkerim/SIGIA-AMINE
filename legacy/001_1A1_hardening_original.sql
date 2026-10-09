-- SIGIA-AMINE | Étape 1A.1 - Hardening définitif du modèle
-- Objectif : corriger les points critiques de l'audit avant toute construction UI.
-- À exécuter APRÈS la migration V1.0, sur une base sauvegardée/staging d'abord.
-- Ne contient aucune donnée métier Al Amine.

begin;

create extension if not exists pgcrypto;
create schema if not exists app;

/* =========================================================
   A. IDENTITÉ ET ISOLATION MULTI-ÉCOLES
   ========================================================= */

alter table public.users
  add constraint users_email_unique_per_school unique (school_id, email);

alter table public.students add column if not exists user_id uuid references public.users(id) on delete set null;
alter table public.parents   add column if not exists user_id uuid references public.users(id) on delete set null;

create unique index if not exists uq_students_user_id on public.students(user_id) where user_id is not null;
create unique index if not exists uq_parents_user_id on public.parents(user_id) where user_id is not null;
create unique index if not exists uq_employee_user_id on public.employees(user_id) where user_id is not null;
create unique index if not exists uq_student_primary_parent on public.student_parents(student_id) where is_primary;

create or replace function app.same_school_or_null(p_school_id uuid, p_other_school_id uuid)
returns boolean
language sql stable security definer set search_path=public,app
as $$ select p_school_id is null or p_other_school_id is null or p_school_id=p_other_school_id $$;

-- Vérifie les relations qui portent un school_id explicite.
create or replace function app.assert_school_relation()
returns trigger
language plpgsql
security definer
set search_path=public,app
as $$
declare
  parent_school uuid;
  child_school uuid := new.school_id;
begin
  case tg_table_name
    when 'school_settings' then
      select school_id into parent_school from public.schools where id=new.school_id;
    when 'school_years' then
      select id into parent_school from public.schools where id=new.school_id;
    when 'classes' then
      select school_id into parent_school from public.school_years where id=new.school_year_id;
      if parent_school is not null and parent_school<>child_school then raise exception 'CROSS_SCHOOL: classes.school_year_id'; end if;
      if new.level_id is not null then
        select school_id into parent_school from public.levels where id=new.level_id;
        if parent_school is not null and parent_school<>child_school then raise exception 'CROSS_SCHOOL: classes.level_id'; end if;
      end if;
      if new.homeroom_teacher_id is not null then
        select school_id into parent_school from public.employees where id=new.homeroom_teacher_id;
        if parent_school is not null and parent_school<>child_school then raise exception 'CROSS_SCHOOL: classes.homeroom_teacher_id'; end if;
      end if;
    when 'programs' then
      select school_id into parent_school from public.school_years where id=new.school_year_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: programs.school_year_id'; end if;
      select school_id into parent_school from public.subjects where id=new.subject_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: programs.subject_id'; end if;
      if new.level_id is not null then select school_id into parent_school from public.levels where id=new.level_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: programs.level_id'; end if; end if;
    when 'teacher_assignments' then
      select school_id into parent_school from public.school_years where id=new.school_year_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: teacher_assignments.school_year_id'; end if;
      select school_id into parent_school from public.employees where id=new.teacher_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: teacher_assignments.teacher_id'; end if;
      select school_id into parent_school from public.classes where id=new.class_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: teacher_assignments.class_id'; end if;
      select school_id into parent_school from public.subjects where id=new.subject_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: teacher_assignments.subject_id'; end if;
    when 'enrollments' then
      select school_id into parent_school from public.students where id=new.student_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: enrollments.student_id'; end if;
      select school_id into parent_school from public.school_years where id=new.school_year_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: enrollments.school_year_id'; end if;
      select school_id into parent_school from public.classes where id=new.class_id;
      if parent_school<>child_school then raise exception 'CROSS_SCHOOL: enrollments.class_id'; end if;
    when 'assessments' then
      select school_id into parent_school from public.school_years where id=new.school_year_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: assessments.school_year_id'; end if;
      select school_id into parent_school from public.classes where id=new.class_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: assessments.class_id'; end if;
      select school_id into parent_school from public.subjects where id=new.subject_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: assessments.subject_id'; end if;
      if new.teacher_id is not null then select school_id into parent_school from public.employees where id=new.teacher_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: assessments.teacher_id'; end if; end if;
      if new.period_id is not null then select sy.school_id into parent_school from public.academic_periods ap join public.school_years sy on sy.id=ap.school_year_id where ap.id=new.period_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: assessments.period_id'; end if; end if;
    when 'report_cards' then
      select school_id into parent_school from public.students where id=new.student_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: report_cards.student_id'; end if;
      select school_id into parent_school from public.school_years where id=new.school_year_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: report_cards.school_year_id'; end if;
      select school_id into parent_school from public.classes where id=new.class_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: report_cards.class_id'; end if;
    when 'payments' then
      if new.student_id is not null then select school_id into parent_school from public.students where id=new.student_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: payments.student_id'; end if; end if;
      if new.payer_parent_id is not null then select school_id into parent_school from public.parents where id=new.payer_parent_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: payments.payer_parent_id'; end if; end if;
    when 'invoices' then
      if new.student_id is not null then select school_id into parent_school from public.students where id=new.student_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: invoices.student_id'; end if; end if;
      if new.parent_id is not null then select school_id into parent_school from public.parents where id=new.parent_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: invoices.parent_id'; end if; end if;
    when 'expenses' then
      if new.category_id is not null then select school_id into parent_school from public.expense_categories where id=new.category_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: expenses.category_id'; end if; end if;
      if new.supplier_id is not null then select school_id into parent_school from public.suppliers where id=new.supplier_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: expenses.supplier_id'; end if; end if;
    when 'cash_transactions' then
      select school_id into parent_school from public.cash_accounts where id=new.cash_account_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: cash_transactions.cash_account_id'; end if;
    when 'cash_closings' then
      select school_id into parent_school from public.cash_accounts where id=new.cash_account_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: cash_closings.cash_account_id'; end if;
    when 'products' then
      if new.category_id is not null then select school_id into parent_school from public.stock_categories where id=new.category_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: products.category_id'; end if; end if;
    when 'stock_movements' then
      select school_id into parent_school from public.products where id=new.product_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: stock_movements.product_id'; end if;
      select school_id into parent_school from public.stock_locations where id=new.location_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: stock_movements.location_id'; end if;
    when 'purchase_orders' then
      select school_id into parent_school from public.suppliers where id=new.supplier_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: purchase_orders.supplier_id'; end if;
    when 'stock_inventories' then
      select school_id into parent_school from public.stock_locations where id=new.location_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: stock_inventories.location_id'; end if;
    when 'employee_attendance' then
      select school_id into parent_school from public.employees where id=new.employee_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: employee_attendance.employee_id'; end if;
    when 'employee_leaves' then
      select school_id into parent_school from public.employees where id=new.employee_id; if parent_school<>child_school then raise exception 'CROSS_SCHOOL: employee_leaves.employee_id'; end if;
    when 'ai_conversations' then
      select school_id into parent_school from public.users where id=new.user_id; if parent_school is not null and parent_school<>child_school then raise exception 'CROSS_SCHOOL: ai_conversations.user_id'; end if;
    when 'notifications' then
      select school_id into parent_school from public.users where id=new.recipient_user_id; if parent_school is not null and parent_school<>child_school then raise exception 'CROSS_SCHOOL: notifications.recipient_user_id'; end if;
    else null;
  end case;
  return new;
end $$;

-- Attach only where the child has school_id and the relation is business-critical.
do $$
declare t text;
begin
  foreach t in array array['classes','programs','teacher_assignments','enrollments','assessments','report_cards','payments','invoices','expenses','cash_transactions','cash_closings','products','stock_movements','purchase_orders','stock_inventories','employee_attendance','employee_leaves','ai_conversations','notifications'] loop
    execute format('drop trigger if exists trg_school_integrity on public.%I',t);
    execute format('create trigger trg_school_integrity before insert or update on public.%I for each row execute function app.assert_school_relation()',t);
  end loop;
end $$;


-- Comptes : un utilisateur, un rôle, un élève, un parent ou un employé ne peut être rattaché à une autre école.
create or replace function app.assert_identity_school()
returns trigger language plpgsql security definer set search_path=public,app
as $$
declare s uuid;
begin
  if tg_table_name='user_roles' then
    if new.school_id is not null then
      select school_id into s from public.users where id=new.user_id;
      if s is not null and s<>new.school_id then raise exception 'CROSS_SCHOOL: user_roles.user_id'; end if;
    end if;
  elsif tg_table_name='employees' then
    if new.user_id is not null then
      select school_id into s from public.users where id=new.user_id;
      if s is not null and s<>new.school_id then raise exception 'CROSS_SCHOOL: employees.user_id'; end if;
    end if;
  elsif tg_table_name='students' then
    if new.user_id is not null then
      select school_id into s from public.users where id=new.user_id;
      if s is not null and s<>new.school_id then raise exception 'CROSS_SCHOOL: students.user_id'; end if;
    end if;
  elsif tg_table_name='parents' then
    if new.user_id is not null then
      select school_id into s from public.users where id=new.user_id;
      if s is not null and s<>new.school_id then raise exception 'CROSS_SCHOOL: parents.user_id'; end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_identity_school on public.user_roles;
create trigger trg_identity_school before insert or update on public.user_roles for each row execute function app.assert_identity_school();
drop trigger if exists trg_identity_school on public.employees;
create trigger trg_identity_school before insert or update on public.employees for each row execute function app.assert_identity_school();
drop trigger if exists trg_identity_school on public.students;
create trigger trg_identity_school before insert or update on public.students for each row execute function app.assert_identity_school();
drop trigger if exists trg_identity_school on public.parents;
create trigger trg_identity_school before insert or update on public.parents for each row execute function app.assert_identity_school();

-- Relations sans school_id : elles doivent obligatoirement passer par une ligne parente du même établissement.
create or replace function app.assert_relation_school()
returns trigger language plpgsql security definer set search_path=public,app
as $$
declare s1 uuid; s2 uuid;
begin
  case tg_table_name
    when 'student_parents' then
      select school_id into s1 from public.students where id=new.student_id;
      select school_id into s2 from public.parents where id=new.parent_id;
    when 'enrollment_history' then
      select school_id into s1 from public.enrollments where id=new.enrollment_id;
      select school_id into s2 from public.students where id=new.student_id;
    when 'report_card_items' then
      select school_id into s1 from public.report_cards where id=new.report_card_id;
      select school_id into s2 from public.subjects where id=new.subject_id;
    when 'attendance_records' then
      select school_id into s1 from public.attendance_sessions where id=new.session_id;
      select school_id into s2 from public.students where id=new.student_id;
    when 'invoice_items' then
      select school_id into s1 from public.invoices where id=new.invoice_id;
      select school_id into s2 from public.fee_types where id=new.fee_type_id;
    when 'payment_allocations' then
      select school_id into s1 from public.payments where id=new.payment_id;
      if new.invoice_id is not null then select school_id into s2 from public.invoices where id=new.invoice_id;
      elsif new.student_charge_id is not null then select school_id into s2 from public.student_charges where id=new.student_charge_id;
      end if;
    when 'purchase_items' then
      select school_id into s1 from public.purchase_orders where id=new.purchase_order_id;
      select school_id into s2 from public.products where id=new.product_id;
    when 'stock_balances' then
      select school_id into s1 from public.products where id=new.product_id;
      select school_id into s2 from public.stock_locations where id=new.location_id;
    when 'stock_inventory_items' then
      select school_id into s1 from public.stock_inventories where id=new.inventory_id;
      select school_id into s2 from public.products where id=new.product_id;
    when 'payroll_items' then
      select school_id into s1 from public.payroll_periods where id=new.payroll_period_id;
      select school_id into s2 from public.employees where id=new.employee_id;
    when 'ai_messages' then
      select school_id into s1 from public.ai_conversations where id=new.conversation_id;
    when 'menu_items' then
      select school_id into s1 from public.menus where id=new.menu_id;
      select school_id into s2 from public.meal_types where id=new.meal_type_id;
    when 'boarding_dormitories' then
      select school_id into s1 from public.boarding_buildings where id=new.building_id;
      if new.supervisor_employee_id is not null then select school_id into s2 from public.employees where id=new.supervisor_employee_id; end if;
    when 'boarding_rooms' then
      select bb.school_id into s1 from public.boarding_dormitories bd join public.boarding_buildings bb on bb.id=bd.building_id where bd.id=new.dormitory_id;
    when 'boarding_beds' then
      select bb.school_id into s1 from public.boarding_rooms br join public.boarding_dormitories bd on bd.id=br.dormitory_id join public.boarding_buildings bb on bb.id=bd.building_id where br.id=new.room_id;
    when 'wushu_attendance' then
      select school_id into s1 from public.wushu_sessions where id=new.session_id;
      select school_id into s2 from public.students where id=new.student_id;
    when 'wushu_competition_results' then
      select school_id into s1 from public.wushu_competitions where id=new.competition_id;
      select school_id into s2 from public.students where id=new.student_id;
    when 'agriculture_expenses' then
      select ea.school_id into s1 from public.agriculture_campaigns ac join public.economic_activities ea on ea.id=ac.activity_id where ac.id=new.campaign_id;
    when 'livestock_events' then
      select ea.school_id into s1 from public.livestock l join public.economic_activities ea on ea.id=l.activity_id where l.id=new.livestock_id;
    when 'productions' then
      select school_id into s1 from public.economic_activities where id=new.activity_id;
    when 'employee_contracts' then
      select school_id into s1 from public.employees where id=new.employee_id;
    else null;
  end case;
  if s1 is null then raise exception 'INTEGRITY: parent record introuvable pour %.%',tg_table_name,tg_op; end if;
  if s2 is not null and s1<>s2 then raise exception 'CROSS_SCHOOL: relation %',tg_table_name; end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['student_parents','enrollment_history','report_card_items','attendance_records','invoice_items','payment_allocations','purchase_items','stock_balances','stock_inventory_items','payroll_items','ai_messages','menu_items','boarding_dormitories','boarding_rooms','boarding_beds','wushu_attendance','wushu_competition_results','agriculture_expenses','livestock_events','productions','employee_contracts'] loop
    execute format('drop trigger if exists trg_relation_school_integrity on public.%I',t);
    execute format('create trigger trg_relation_school_integrity before insert or update on public.%I for each row execute function app.assert_relation_school()',t);
  end loop;
end $$;

/* =========================================================
   B. RBAC + RLS : rôle -> permission -> action -> données
   ========================================================= */

create or replace function app.my_role_codes(p_school_id uuid default null)
returns setof text language sql stable security definer set search_path=public,app
as $$
  select r.code from public.user_roles ur join public.roles r on r.id=ur.role_id
  where ur.user_id=auth.uid() and ur.is_active and (p_school_id is null or ur.school_id=p_school_id)
$$;

create or replace function app.has_role_code(p_code text,p_school_id uuid default null)
returns boolean language sql stable security definer set search_path=public,app
as $$ select exists(select 1 from app.my_role_codes(p_school_id) x where x=p_code) $$;

create or replace function app.is_parent_of_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path=public,app
as $$
 select exists(
   select 1 from public.students s
   join public.student_parents sp on sp.student_id=s.id
   join public.parents p on p.id=sp.parent_id
   where s.id=p_student_id and p.user_id=auth.uid()
 )
$$;

create or replace function app.is_self_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path=public,app
as $$ select exists(select 1 from public.students where id=p_student_id and user_id=auth.uid()) $$;

create or replace function app.is_teacher_for_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path=public,app
as $$
 select exists(
   select 1 from public.enrollments e
   join public.teacher_assignments ta on ta.class_id=e.class_id and ta.school_year_id=e.school_year_id
   join public.employees emp on emp.id=ta.teacher_id
   where e.student_id=p_student_id and emp.user_id=auth.uid() and e.status='enrolled'
 )
$$;

create or replace function app.can_school_action(p_school_id uuid,p_permission text,p_action text default 'select')
returns boolean language sql stable security definer set search_path=public,app
as $$
 select app.is_super_admin()
    or (
      p_school_id in (select app.my_school_ids())
      and (
        (p_action='select' and (app.has_permission(p_permission,p_school_id) or app.has_permission(replace(p_permission,'.view','.manage'),p_school_id)))
        or (p_action<>'select' and app.has_permission(p_permission,p_school_id))
      )
    )
$$;

-- On retire toutes les policies V1 afin d'éviter un cumul permissif.
do $$
declare r record;
begin
  for r in select schemaname,tablename,policyname from pg_policies where schemaname='public' loop
    execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename);
  end loop;
end $$;

-- Tables métier avec school_id : policies CRUD centralisées et permissionnées.
do $$
declare t text; perm text; tbl record;
begin
  for tbl in
    select * from (values
      ('school_settings','settings.manage'),('school_years','settings.manage'),('levels','classes.manage'),('classes','classes.manage'),('subjects','subjects.manage'),('programs','classes.manage'),
      ('employees','hr.manage'),('teacher_assignments','teachers.manage'),('students','students.manage'),('parents','parents.manage'),('authorized_pickup_persons','students.manage'),('admission_applications','enrollments.manage'),('enrollments','enrollments.manage'),
      ('document_types','students.manage'),('documents','students.manage'),('timetable_slots','timetable.manage'),('assessment_types','assessments.manage'),('assessments','assessments.manage'),('report_cards','report_cards.generate'),
      ('attendance_sessions','attendance.manage'),('absence_justifications','attendance.manage'),('discipline_categories','discipline.manage'),('discipline_events','discipline.manage'),('student_followups','discipline.manage'),('student_rewards','discipline.manage'),
      ('boarding_buildings','boarding.manage'),('boarding_assignments','boarding.manage'),('boarding_movements','boarding.manage'),('boarding_attendance','boarding.manage'),('meal_types','catering.manage'),('menus','catering.manage'),('meal_service_records','catering.manage'),('meal_attendance','catering.manage'),
      ('tahfiz_levels','tahfiz.manage'),('student_tahfiz','tahfiz.manage'),('tahfiz_sessions','tahfiz.manage'),('islamic_training','arabic.manage'),('wushu_groups','wushu.manage'),('student_wushu','wushu.manage'),('wushu_sessions','wushu.manage'),('wushu_evaluations','wushu.manage'),('wushu_competitions','wushu.manage'),
      ('fee_types','finance.manage'),('fee_schedules','finance.manage'),('student_charges','finance.manage'),('invoices','finance.manage'),('payments','finance.manage'),('receipts','finance.manage'),('expense_categories','expenses.manage'),('suppliers','purchases.manage'),('expenses','expenses.manage'),('cash_accounts','cash.manage'),('cash_transactions','cash.manage'),('cash_closings','cash.manage'),('collection_reminders','finance.manage'),
      ('stock_categories','stock.manage'),('stock_locations','stock.manage'),('products','stock.manage'),('stock_movements','stock.manage'),('purchase_orders','purchases.manage'),('stock_inventories','stock.manage'),('economic_activities','agriculture.manage'),('sales','agriculture.manage'),
      ('employee_attendance','hr.manage'),('employee_leaves','hr.manage'),('payroll_periods','hr.manage'),('announcements','communication.manage'),('notifications','communication.manage'),('ai_conversations','ai.use'),('ai_alerts','ai.use')
    ) as v(tab,permission) loop
    t:=tbl.tab; perm:=tbl.permission;
    execute format('create policy %I on public.%I for select using (app.can_school_action(school_id,%L,''select'') or app.has_role_code(''direction'',school_id) or app.has_role_code(''founder'',school_id))',t||'_select_secure',t,perm);
    execute format('create policy %I on public.%I for insert with check (app.can_school_action(school_id,%L,''insert''))',t||'_insert_secure',t,perm);
    execute format('create policy %I on public.%I for update using (app.can_school_action(school_id,%L,''update'')) with check (app.can_school_action(school_id,%L,''update''))',t||'_update_secure',t,perm,perm);
    execute format('create policy %I on public.%I for delete using (app.can_school_action(school_id,%L,''delete''))',t||'_delete_secure',t,perm);
  end loop;
end $$;

-- Lecture des données personnelles : parent/enfant/enseignant sans donner accès à toute l'école.
create policy students_select_scoped on public.students for select using (
  app.is_self_student(id) or app.is_parent_of_student(id) or app.is_teacher_for_student(id)
  or app.has_permission('students.view',school_id) or app.has_permission('students.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);
create policy students_update_staff on public.students for update using(app.has_permission('students.manage',school_id) or app.is_super_admin()) with check(app.has_permission('students.manage',school_id) or app.is_super_admin());

create policy parents_select_scoped on public.parents for select using (
  user_id=auth.uid() or exists(select 1 from public.student_parents sp where sp.parent_id=id and app.is_self_student(sp.student_id))
  or app.has_permission('parents.view',school_id) or app.has_permission('parents.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);

-- Portails parent/élève : données strictement liées à l'enfant / au compte.
create policy grades_select_scoped on public.grades for select using (
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.is_teacher_for_student(student_id)
  or exists(select 1 from public.assessments a where a.id=assessment_id and (app.has_permission('grades.enter',a.school_id) or app.has_permission('grades.publish',a.school_id) or app.has_role_code('direction',a.school_id) or app.has_role_code('founder',a.school_id)))
  or app.is_super_admin()
);
create policy grades_write_staff on public.grades for all using (
  exists(select 1 from public.assessments a where a.id=assessment_id and app.has_permission('grades.enter',a.school_id)) or app.is_super_admin()
) with check (
  exists(select 1 from public.assessments a where a.id=assessment_id and app.has_permission('grades.enter',a.school_id)) or app.is_super_admin()
);

create policy report_cards_select_scoped on public.report_cards for select using (
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.has_permission('report_cards.generate',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);

-- finance parent : uniquement les factures/paiements de ses enfants.
drop policy if exists invoices_select_secure on public.invoices;
create policy invoices_select_scoped on public.invoices for select using (
  (student_id is not null and (app.is_self_student(student_id) or app.is_parent_of_student(student_id)))
  or app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);
drop policy if exists payments_select_secure on public.payments;
create policy payments_select_scoped on public.payments for select using (
  (student_id is not null and (app.is_self_student(student_id) or app.is_parent_of_student(student_id)))
  or app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);

-- Enseignant : ses classes/matières pour les évaluations/présences.
create or replace function app.is_teacher_for_class(p_class_id uuid,p_school_year_id uuid default null)
returns boolean language sql stable security definer set search_path=public,app
as $$
 select exists(select 1 from public.teacher_assignments ta join public.employees e on e.id=ta.teacher_id where ta.class_id=p_class_id and (p_school_year_id is null or ta.school_year_id=p_school_year_id) and e.user_id=auth.uid() and ta.school_id in(select app.my_school_ids()))
$$;

-- Direction : pilotage en lecture, modifications toujours soumises aux permissions métier.
create policy audit_select_secure on public.audit_logs for select using(app.has_permission('audit.view',school_id) or app.is_super_admin());



/* =========================================================
   B2. POLICIES DES TABLES SANS school_id + IDENTITÉ
   ========================================================= */

create policy schools_select_secure on public.schools for select using(id in(select app.my_school_ids()) or app.is_super_admin());
create policy schools_manage_secure on public.schools for update using(app.is_super_admin()) with check(app.is_super_admin());
create policy users_select_secure on public.users for select using(id=auth.uid() or app.has_permission('users.manage',school_id) or app.is_super_admin());
create policy users_update_self_or_admin on public.users for update using(id=auth.uid() or app.has_permission('users.manage',school_id) or app.is_super_admin()) with check(id=auth.uid() or app.has_permission('users.manage',school_id) or app.is_super_admin());
create policy users_insert_admin on public.users for insert with check(app.has_permission('users.manage',school_id) or app.is_super_admin());
create policy users_delete_admin on public.users for delete using(app.has_permission('users.manage',school_id) or app.is_super_admin());

create policy roles_select_secure on public.roles for select to authenticated using(auth.uid() is not null);
create policy permissions_select_secure on public.permissions for select to authenticated using(auth.uid() is not null);
create policy role_permissions_select_secure on public.role_permissions for select to authenticated using(auth.uid() is not null);
create policy user_roles_select_secure on public.user_roles for select using(user_id=auth.uid() or app.has_permission('users.roles.manage',school_id) or app.is_super_admin());
create policy user_roles_manage_secure on public.user_roles for all using(app.has_permission('users.roles.manage',school_id) or app.is_super_admin()) with check(app.has_permission('users.roles.manage',school_id) or app.is_super_admin());
create policy teacher_profiles_secure on public.teacher_profiles for all using(employee_id in(select e.id from public.employees e where e.school_id in(select app.my_school_ids()) and (e.user_id=auth.uid() or app.has_permission('teachers.manage',e.school_id) or app.has_permission('hr.manage',e.school_id))) or app.is_super_admin()) with check(employee_id in(select e.id from public.employees e where e.school_id in(select app.my_school_ids()) and (e.user_id=auth.uid() or app.has_permission('teachers.manage',e.school_id) or app.has_permission('hr.manage',e.school_id))) or app.is_super_admin());
create policy academic_periods_secure on public.academic_periods for all using(school_year_id in(select sy.id from public.school_years sy where sy.school_id in(select app.my_school_ids()))) with check(school_year_id in(select sy.id from public.school_years sy where sy.school_id in(select app.my_school_ids())));
create policy student_parents_secure on public.student_parents for all using(
  app.is_parent_of_student(student_id) or app.has_permission('parents.manage',(select school_id from public.students where id=student_id)) or app.has_permission('students.manage',(select school_id from public.students where id=student_id)) or app.is_super_admin()
) with check(
  (select s.school_id from public.students s where s.id=student_id)=(select p.school_id from public.parents p where p.id=parent_id)
  and (app.has_permission('parents.manage',(select school_id from public.students where id=student_id)) or app.has_permission('students.manage',(select school_id from public.students where id=student_id)) or app.is_super_admin())
);
create policy enrollment_history_secure on public.enrollment_history for select using(student_id in(select id from public.students where school_id in(select app.my_school_ids())) and (app.has_permission('students.view',(select school_id from public.students where id=student_id)) or app.has_permission('students.manage',(select school_id from public.students where id=student_id)) or app.is_parent_of_student(student_id) or app.is_self_student(student_id) or app.is_super_admin()));
create policy enrollment_history_manage on public.enrollment_history for all using(app.has_permission('students.manage',(select school_id from public.students where id=student_id)) or app.is_super_admin()) with check(app.has_permission('students.manage',(select school_id from public.students where id=student_id)) or app.is_super_admin());
create policy report_card_items_secure on public.report_card_items for select using(report_card_id in(select id from public.report_cards where school_id in(select app.my_school_ids())));
create policy report_card_items_manage on public.report_card_items for all using(exists(select 1 from public.report_cards r where r.id=report_card_id and (app.has_permission('report_cards.generate',r.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.report_cards r where r.id=report_card_id and (app.has_permission('report_cards.generate',r.school_id) or app.is_super_admin())));
create policy attendance_records_secure on public.attendance_records for select using(exists(select 1 from public.attendance_sessions s where s.id=session_id and (app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.is_teacher_for_class(s.class_id,s.school_year_id) or app.has_permission('attendance.manage',s.school_id) or app.is_super_admin())));
create policy attendance_records_manage on public.attendance_records for all using(exists(select 1 from public.attendance_sessions s where s.id=session_id and (app.has_permission('attendance.manage',s.school_id) or app.is_teacher_for_class(s.class_id,s.school_year_id) or app.is_super_admin()))) with check(exists(select 1 from public.attendance_sessions s where s.id=session_id and (app.has_permission('attendance.manage',s.school_id) or app.is_teacher_for_class(s.class_id,s.school_year_id) or app.is_super_admin())));
create policy menu_items_secure on public.menu_items for select using(menu_id in(select id from public.menus where school_id in(select app.my_school_ids())));
create policy menu_items_manage on public.menu_items for all using(exists(select 1 from public.menus m where m.id=menu_id and (app.has_permission('catering.manage',m.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.menus m where m.id=menu_id and (app.has_permission('catering.manage',m.school_id) or app.is_super_admin())));
create policy payment_allocations_secure on public.payment_allocations for select using(exists(select 1 from public.payments p where p.id=payment_id and (app.is_self_student(p.student_id) or app.is_parent_of_student(p.student_id) or app.has_permission('finance.view',p.school_id) or app.has_permission('finance.manage',p.school_id) or app.is_super_admin())));
create policy payment_allocations_manage on public.payment_allocations for all using(exists(select 1 from public.payments p where p.id=payment_id and (app.has_permission('finance.manage',p.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.payments p where p.id=payment_id and (app.has_permission('finance.manage',p.school_id) or app.is_super_admin())));
create policy invoice_items_secure on public.invoice_items for select using(exists(select 1 from public.invoices i where i.id=invoice_id and (app.is_self_student(i.student_id) or app.is_parent_of_student(i.student_id) or app.has_permission('finance.view',i.school_id) or app.has_permission('finance.manage',i.school_id) or app.is_super_admin())));
create policy invoice_items_manage on public.invoice_items for all using(exists(select 1 from public.invoices i where i.id=invoice_id and (app.has_permission('finance.manage',i.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.invoices i where i.id=invoice_id and (app.has_permission('finance.manage',i.school_id) or app.is_super_admin())));
create policy stock_balances_secure on public.stock_balances for select using(exists(select 1 from public.products p join public.stock_locations l on l.id=location_id where p.id=product_id and p.school_id=l.school_id and p.school_id in(select app.my_school_ids())));
create policy stock_balances_manage on public.stock_balances for all using(exists(select 1 from public.products p join public.stock_locations l on l.id=location_id where p.id=product_id and p.school_id=l.school_id and app.has_permission('stock.manage',p.school_id))) with check(exists(select 1 from public.products p join public.stock_locations l on l.id=location_id where p.id=product_id and p.school_id=l.school_id and app.has_permission('stock.manage',p.school_id)));
create policy purchase_items_secure on public.purchase_items for select using(exists(select 1 from public.purchase_orders po where po.id=purchase_order_id and po.school_id in(select app.my_school_ids())));
create policy purchase_items_manage on public.purchase_items for all using(exists(select 1 from public.purchase_orders po where po.id=purchase_order_id and (app.has_permission('purchases.manage',po.school_id) or app.has_permission('stock.manage',po.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.purchase_orders po where po.id=purchase_order_id and (app.has_permission('purchases.manage',po.school_id) or app.has_permission('stock.manage',po.school_id) or app.is_super_admin())));
create policy stock_inventory_items_secure on public.stock_inventory_items for select using(exists(select 1 from public.stock_inventories si where si.id=inventory_id and si.school_id in(select app.my_school_ids())));
create policy stock_inventory_items_manage on public.stock_inventory_items for all using(exists(select 1 from public.stock_inventories si where si.id=inventory_id and (app.has_permission('stock.manage',si.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.stock_inventories si where si.id=inventory_id and (app.has_permission('stock.manage',si.school_id) or app.is_super_admin())));
create policy payroll_items_secure on public.payroll_items for select using(exists(select 1 from public.payroll_periods pp where pp.id=payroll_period_id and (app.has_permission('hr.manage',pp.school_id) or app.has_role_code('direction',pp.school_id) or app.has_role_code('founder',pp.school_id) or app.is_super_admin())));
create policy payroll_items_manage on public.payroll_items for all using(exists(select 1 from public.payroll_periods pp where pp.id=payroll_period_id and (app.has_permission('hr.manage',pp.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.payroll_periods pp where pp.id=payroll_period_id and (app.has_permission('hr.manage',pp.school_id) or app.is_super_admin())));
create policy ai_messages_secure on public.ai_messages for all using(exists(select 1 from public.ai_conversations c where c.id=conversation_id and (c.user_id=auth.uid() or app.has_permission('ai.use',c.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.ai_conversations c where c.id=conversation_id and (c.user_id=auth.uid() or app.has_permission('ai.use',c.school_id) or app.is_super_admin())));
create policy quran_surahs_select_secure on public.quran_surahs for select to authenticated using(true);
create policy wushu_attendance_secure on public.wushu_attendance for select using(exists(select 1 from public.wushu_sessions ws where ws.id=session_id and (app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.has_permission('wushu.manage',ws.school_id) or app.is_super_admin())));
create policy wushu_attendance_manage on public.wushu_attendance for all using(exists(select 1 from public.wushu_sessions ws where ws.id=session_id and (app.has_permission('wushu.manage',ws.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.wushu_sessions ws where ws.id=session_id and (app.has_permission('wushu.manage',ws.school_id) or app.is_super_admin())));
create policy wushu_results_secure on public.wushu_competition_results for select using(exists(select 1 from public.wushu_competitions c where c.id=competition_id and (app.is_self_student(student_id) or app.is_parent_of_student(student_id) or app.has_permission('wushu.manage',c.school_id) or app.is_super_admin())));
create policy wushu_results_manage on public.wushu_competition_results for all using(exists(select 1 from public.wushu_competitions c where c.id=competition_id and (app.has_permission('wushu.manage',c.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.wushu_competitions c where c.id=competition_id and (app.has_permission('wushu.manage',c.school_id) or app.is_super_admin())));
create policy agriculture_campaigns_secure on public.agriculture_campaigns for select using(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())));
create policy agriculture_campaigns_manage on public.agriculture_campaigns for all using(exists(select 1 from public.economic_activities e where e.id=activity_id and (app.has_permission('agriculture.manage',e.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.economic_activities e where e.id=activity_id and (app.has_permission('agriculture.manage',e.school_id) or app.is_super_admin())));
create policy agriculture_expenses_secure on public.agriculture_expenses for select using(exists(select 1 from public.agriculture_campaigns ac join public.economic_activities e on e.id=ac.activity_id where ac.id=campaign_id and e.school_id in(select app.my_school_ids())));
create policy agriculture_expenses_manage on public.agriculture_expenses for all using(exists(select 1 from public.agriculture_campaigns ac join public.economic_activities e on e.id=ac.activity_id where ac.id=campaign_id and (app.has_permission('agriculture.manage',e.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.agriculture_campaigns ac join public.economic_activities e on e.id=ac.activity_id where ac.id=campaign_id and (app.has_permission('agriculture.manage',e.school_id) or app.is_super_admin())));
create policy livestock_secure on public.livestock for select using(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())));
create policy livestock_manage on public.livestock for all using(exists(select 1 from public.economic_activities e where e.id=activity_id and (app.has_permission('livestock.manage',e.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.economic_activities e where e.id=activity_id and (app.has_permission('livestock.manage',e.school_id) or app.is_super_admin())));
create policy livestock_events_secure on public.livestock_events for select using(exists(select 1 from public.livestock l join public.economic_activities e on e.id=l.activity_id where l.id=livestock_id and e.school_id in(select app.my_school_ids())));
create policy livestock_events_manage on public.livestock_events for all using(exists(select 1 from public.livestock l join public.economic_activities e on e.id=l.activity_id where l.id=livestock_id and (app.has_permission('livestock.manage',e.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.livestock l join public.economic_activities e on e.id=l.activity_id where l.id=livestock_id and (app.has_permission('livestock.manage',e.school_id) or app.is_super_admin())));
create policy productions_secure on public.productions for select using(activity_id in(select id from public.economic_activities where school_id in(select app.my_school_ids())));
create policy productions_manage on public.productions for all using(exists(select 1 from public.economic_activities e where e.id=activity_id and (app.has_permission('agriculture.manage',e.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.economic_activities e where e.id=activity_id and (app.has_permission('agriculture.manage',e.school_id) or app.is_super_admin())));
create policy employee_contracts_secure on public.employee_contracts for select using(exists(select 1 from public.employees e where e.id=employee_id and (e.user_id=auth.uid() or app.has_permission('hr.manage',e.school_id) or app.has_role_code('direction',e.school_id) or app.is_super_admin())));
create policy employee_contracts_manage on public.employee_contracts for all using(exists(select 1 from public.employees e where e.id=employee_id and (app.has_permission('hr.manage',e.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.employees e where e.id=employee_id and (app.has_permission('hr.manage',e.school_id) or app.is_super_admin())));
create policy notifications_recipient_secure on public.notifications for select using(recipient_user_id=auth.uid() or app.has_permission('communication.manage',school_id) or app.is_super_admin());
create policy notifications_recipient_update on public.notifications for update using(recipient_user_id=auth.uid() or app.has_permission('communication.manage',school_id) or app.is_super_admin()) with check(recipient_user_id=auth.uid() or app.has_permission('communication.manage',school_id) or app.is_super_admin());
create policy notification_preferences_self_secure on public.notification_preferences for all using(user_id=auth.uid() or app.is_super_admin()) with check(user_id=auth.uid() or app.is_super_admin());



-- Audit des notes : écriture exclusivement par trigger SECURITY DEFINER, lecture par audit/finance pédagogique autorisée.
create or replace function app.audit_grade_change()
returns trigger language plpgsql security definer set search_path=public,app
as $$
begin
  if tg_op='UPDATE' and old.score is distinct from new.score then
    insert into public.grade_audit(grade_id,old_score,new_score,changed_by,reason)
    values(new.id,old.score,new.score,auth.uid(),'Modification de note');
  end if;
  return new;
end $$;
drop trigger if exists trg_audit_grade_change on public.grades;
create trigger trg_audit_grade_change after update on public.grades for each row execute function app.audit_grade_change();
create policy grade_audit_select_secure on public.grade_audit for select using(exists(select 1 from public.grades g join public.assessments a on a.id=g.assessment_id where g.id=grade_id and (app.has_permission('audit.view',a.school_id) or app.has_permission('grades.publish',a.school_id) or app.is_super_admin())));

/* =========================================================
   C. RÈGLES MÉTIER CRITIQUES
   ========================================================= */

-- Inscriptions : une seule inscription active par élève et année.
create unique index if not exists uq_enrollment_active_student_year on public.enrollments(student_id,school_year_id) where status in ('pending','approved','enrolled');
create or replace function app.validate_enrollment()
returns trigger language plpgsql as $$
declare student_school uuid; year_school uuid; class_school uuid;
begin
 select school_id into student_school from public.students where id=new.student_id;
 select school_id into year_school from public.school_years where id=new.school_year_id;
 select school_id into class_school from public.classes where id=new.class_id;
 if student_school<>new.school_id or year_school<>new.school_id or class_school<>new.school_id then raise exception 'ENROLLMENT_CROSS_SCHOOL'; end if;
 if new.status in ('approved','enrolled') then
   if (select count(*) from public.enrollments e where e.student_id=new.student_id and e.school_year_id=new.school_year_id and e.status in ('approved','enrolled') and e.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid))>0 then raise exception 'DUPLICATE_ACTIVE_ENROLLMENT'; end if;
   if (select capacity from public.classes where id=new.class_id) is not null and (select count(*) from public.enrollments e where e.class_id=new.class_id and e.status='enrolled' and e.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)) >= (select capacity from public.classes where id=new.class_id) then raise exception 'CLASS_CAPACITY_REACHED'; end if;
 end if;
 return new;
end $$;
drop trigger if exists trg_validate_enrollment on public.enrollments;
create trigger trg_validate_enrollment before insert or update on public.enrollments for each row execute function app.validate_enrollment();

-- Notes : verrouillage après publication + score borné.
create or replace function app.validate_grade_hardened()
returns trigger language plpgsql as $$
declare published boolean; maxs numeric;
begin
 select a.is_published,a.max_score into published,maxs from public.assessments a where a.id=new.assessment_id;
 if new.score<0 or new.score>maxs then raise exception 'GRADE_OUT_OF_RANGE'; end if;
 if tg_op='UPDATE' and published and (new.score is distinct from old.score or new.observation is distinct from old.observation) then raise exception 'PUBLISHED_GRADE_LOCKED'; end if;
 new.normalized_score=round((new.score/maxs)*20,2);
 return new;
end $$;
drop trigger if exists trg_validate_grade_hardened on public.grades;
create trigger trg_validate_grade_hardened before insert or update on public.grades for each row execute function app.validate_grade_hardened();

-- Évaluations : publication réservée à grades.publish.
create or replace function app.validate_assessment_publication()
returns trigger language plpgsql as $$
begin
 if new.is_published and (tg_op='INSERT' or not old.is_published) and not app.has_permission('grades.publish',new.school_id) and not app.is_super_admin() then raise exception 'PERMISSION_REQUIRED: grades.publish'; end if;
 if old.is_published and (new.title is distinct from old.title or new.max_score is distinct from old.max_score or new.coefficient is distinct from old.coefficient or new.class_id is distinct from old.class_id or new.subject_id is distinct from old.subject_id) then raise exception 'PUBLISHED_ASSESSMENT_LOCKED'; end if;
 return new;
end $$;
drop trigger if exists trg_validate_assessment_publication on public.assessments;
create trigger trg_validate_assessment_publication before insert or update on public.assessments for each row execute function app.validate_assessment_publication();

-- Bulletins : un bulletin publié devient immuable sauf workflow explicite d'administration.
create or replace function app.validate_report_card_lock()
returns trigger language plpgsql as $$
begin
 if old.status='published' and to_jsonb(new) is distinct from to_jsonb(old) and not app.has_permission('grades.publish',new.school_id) and not app.is_super_admin() then raise exception 'PUBLISHED_REPORT_CARD_LOCKED'; end if;
 return new;
end $$;
drop trigger if exists trg_validate_report_card_lock on public.report_cards;
create trigger trg_validate_report_card_lock before update on public.report_cards for each row execute function app.validate_report_card_lock();

-- Finance : allocation atomique et plafonnée.
create or replace function app.validate_payment_allocation()
returns trigger language plpgsql as $$
declare payment_total numeric; allocated_total numeric; invoice_total numeric; invoice_alloc numeric; charge_due numeric; charge_alloc numeric;
begin
 if new.invoice_id is null and new.student_charge_id is null then raise exception 'ALLOCATION_TARGET_REQUIRED'; end if;
 select amount into payment_total from public.payments where id=new.payment_id and status not in ('cancelled','refunded') for update;
 if payment_total is null then raise exception 'PAYMENT_NOT_ALLOCATABLE'; end if;
 select coalesce(sum(amount),0) into allocated_total from public.payment_allocations where payment_id=new.payment_id and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);
 if allocated_total+new.amount>payment_total then raise exception 'PAYMENT_ALLOCATION_EXCEEDS_PAYMENT'; end if;
 if new.invoice_id is not null then
   select total into invoice_total from public.invoices where id=new.invoice_id for update;
   if invoice_total is null then raise exception 'INVOICE_NOT_FOUND'; end if;
   if (select school_id from public.invoices where id=new.invoice_id)<>(select school_id from public.payments where id=new.payment_id) then raise exception 'ALLOCATION_CROSS_SCHOOL'; end if;
   select coalesce(sum(amount),0) into invoice_alloc from public.payment_allocations where invoice_id=new.invoice_id and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);
   if invoice_alloc+new.amount>invoice_total then raise exception 'PAYMENT_ALLOCATION_EXCEEDS_INVOICE'; end if;
 end if;
 if new.student_charge_id is not null then
   select amount_due into charge_due from public.student_charges where id=new.student_charge_id for update;
   if charge_due is null then raise exception 'CHARGE_NOT_FOUND'; end if;
   if (select school_id from public.student_charges where id=new.student_charge_id)<>(select school_id from public.payments where id=new.payment_id) then raise exception 'ALLOCATION_CROSS_SCHOOL'; end if;
   select coalesce(sum(amount),0) into charge_alloc from public.payment_allocations where student_charge_id=new.student_charge_id and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);
   if charge_alloc+new.amount>charge_due then raise exception 'PAYMENT_ALLOCATION_EXCEEDS_CHARGE'; end if;
 end if;
 return new;
end $$;
drop trigger if exists trg_validate_payment_allocation on public.payment_allocations;
create trigger trg_validate_payment_allocation before insert or update on public.payment_allocations for each row execute function app.validate_payment_allocation();

-- Factures : lignes non négatives et total recalculé côté serveur.
alter table public.invoice_items drop constraint if exists invoice_items_discount_check;
alter table public.invoice_items add constraint invoice_items_discount_check check(discount>=0 and discount<=quantity*unit_amount);
create or replace function app.recalculate_invoice_total_hardened()
returns trigger language plpgsql as $$
declare iid uuid;
begin
 iid:=coalesce(new.invoice_id,old.invoice_id);
 update public.invoices i set subtotal=x.subtotal,total=greatest(0,x.subtotal-i.discount),updated_at=now()
 from (select coalesce(sum(line_total),0) subtotal from public.invoice_items where invoice_id=iid) x
 where i.id=iid;
 return coalesce(new,old);
end $$;
drop trigger if exists trg_invoice_total_hardened on public.invoice_items;
create trigger trg_invoice_total_hardened after insert or update or delete on public.invoice_items for each row execute function app.recalculate_invoice_total_hardened();

-- Caisse : interdiction d'écrire dans un compte d'une autre école et verrouillage après clôture.
create or replace function app.validate_cash_transaction()
returns trigger language plpgsql as $$
declare s uuid; last_close date;
begin
 select school_id into s from public.cash_accounts where id=new.cash_account_id;
 if s<>new.school_id then raise exception 'CASH_CROSS_SCHOOL'; end if;
 select max(closing_date) into last_close from public.cash_closings where cash_account_id=new.cash_account_id;
 if last_close is not null and new.transaction_date::date<=last_close then raise exception 'CASH_PERIOD_CLOSED'; end if;
 return new;
end $$;
drop trigger if exists trg_validate_cash_transaction on public.cash_transactions;
create trigger trg_validate_cash_transaction before insert or update on public.cash_transactions for each row execute function app.validate_cash_transaction();

-- Stocks : source de vérité = mouvements; balance matérialisée synchronisée dans une transaction.
create or replace function app.apply_stock_movement()
returns trigger language plpgsql as $$
declare delta numeric; new_balance numeric;
begin
 if new.movement_type in ('purchase','return','adjustment','production_in') then delta:=new.quantity; else delta:=-new.quantity; end if;
 insert into public.stock_balances(product_id,location_id,quantity,updated_at) values(new.product_id,new.location_id,delta,now())
 on conflict(product_id,location_id) do update set quantity=public.stock_balances.quantity+excluded.quantity,updated_at=now()
 returning quantity into new_balance;
 if new_balance<0 and new.movement_type not in ('adjustment') then raise exception 'NEGATIVE_STOCK_NOT_ALLOWED'; end if;
 return new;
end $$;
drop trigger if exists trg_apply_stock_movement on public.stock_movements;
create trigger trg_apply_stock_movement after insert on public.stock_movements for each row execute function app.apply_stock_movement();

alter table public.products drop constraint if exists products_stock_range_check;
alter table public.products add constraint products_stock_range_check check(maximum_stock is null or maximum_stock>=minimum_stock);
alter table public.purchase_items drop constraint if exists purchase_items_received_check;
alter table public.purchase_items add constraint purchase_items_received_check check(received_quantity>=0 and received_quantity<=quantity);

-- Internat : un élève et un lit ne peuvent avoir qu'une affectation active à la fois.
create unique index if not exists uq_active_boarding_student on public.boarding_assignments(student_id) where status='active' and end_date is null;
create unique index if not exists uq_active_boarding_bed on public.boarding_assignments(bed_id) where status='active' and end_date is null;
create or replace function app.validate_boarding_assignment()
returns trigger language plpgsql as $$
declare s1 uuid; s2 uuid;
begin
 select school_id into s1 from public.students where id=new.student_id;
 select bb.school_id into s2 from public.boarding_beds b join public.boarding_rooms r on r.id=b.room_id join public.boarding_dormitories d on d.id=r.dormitory_id join public.boarding_buildings bb on bb.id=d.building_id where b.id=new.bed_id;
 if s1<>new.school_id or s2<>new.school_id then raise exception 'BOARDING_CROSS_SCHOOL'; end if;
 return new;
end $$;
drop trigger if exists trg_validate_boarding_assignment on public.boarding_assignments;
create trigger trg_validate_boarding_assignment before insert or update on public.boarding_assignments for each row execute function app.validate_boarding_assignment();

-- RH : contrats actifs et congés qui se chevauchent interdits.
create unique index if not exists uq_active_employee_contract on public.employee_contracts(employee_id) where status='active';
create or replace function app.prevent_overlapping_leave()
returns trigger language plpgsql as $$
begin
 if exists(select 1 from public.employee_leaves x where x.employee_id=new.employee_id and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid) and x.status in ('submitted','approved') and daterange(x.start_date,x.end_date,'[]') && daterange(new.start_date,new.end_date,'[]')) then raise exception 'OVERLAPPING_LEAVE'; end if;
 return new;
end $$;
drop trigger if exists trg_prevent_overlapping_leave on public.employee_leaves;
create trigger trg_prevent_overlapping_leave before insert or update on public.employee_leaves for each row execute function app.prevent_overlapping_leave();

alter table public.payroll_items add constraint payroll_non_negative_check check(base_salary>=0 and allowances>=0 and deductions>=0 and net_salary>=0);
alter table public.payroll_periods add constraint payroll_period_dates_check check(end_date>=start_date);

/* =========================================================
   D. PERFORMANCE
   ========================================================= */

create index if not exists idx_school_years_school_dates on public.school_years(school_id,start_date,end_date);
create index if not exists idx_classes_school_year_level on public.classes(school_id,school_year_id,level_id);
create index if not exists idx_subjects_school_name on public.subjects(school_id,name);
create index if not exists idx_employees_school_user on public.employees(school_id,user_id);
create index if not exists idx_teacher_assignments_school_year_teacher on public.teacher_assignments(school_id,school_year_id,teacher_id);
create index if not exists idx_teacher_assignments_school_year_class_subject on public.teacher_assignments(school_id,school_year_id,class_id,subject_id);
create index if not exists idx_enrollments_school_year_class on public.enrollments(school_id,school_year_id,class_id,status);
create index if not exists idx_student_parents_student_parent on public.student_parents(student_id,parent_id);
create index if not exists idx_documents_student on public.documents(school_id,student_id,created_at desc);
create index if not exists idx_assessments_school_year_class_subject on public.assessments(school_id,school_year_id,class_id,subject_id);
create index if not exists idx_grades_assessment_student on public.grades(assessment_id,student_id);
create index if not exists idx_attendance_sessions_class_date on public.attendance_sessions(school_id,class_id,session_date desc);
create index if not exists idx_attendance_records_session_student on public.attendance_records(session_id,student_id);
create index if not exists idx_discipline_school_student_date on public.discipline_events(school_id,student_id,event_date desc);
create index if not exists idx_payments_school_student_date on public.payments(school_id,student_id,payment_date desc);
create index if not exists idx_invoices_school_student_status on public.invoices(school_id,student_id,status);
create index if not exists idx_payment_allocations_payment on public.payment_allocations(payment_id);
create index if not exists idx_payment_allocations_invoice on public.payment_allocations(invoice_id);
create index if not exists idx_payment_allocations_charge on public.payment_allocations(student_charge_id);
create index if not exists idx_cash_transactions_school_account_date on public.cash_transactions(school_id,cash_account_id,transaction_date desc);
create index if not exists idx_stock_movements_school_product_location_date on public.stock_movements(school_id,product_id,location_id,movement_date desc);
create index if not exists idx_purchase_items_order_product on public.purchase_items(purchase_order_id,product_id);
create index if not exists idx_notifications_recipient_unread on public.notifications(recipient_user_id,read_at,created_at desc);
create index if not exists idx_ai_messages_conversation_created on public.ai_messages(conversation_id,created_at);

/* =========================================================
   E. SUPABASE : STORAGE + AUDIT + SECURITY DEFINER
   ========================================================= */

-- Fonctions SECURITY DEFINER : search_path figé et accès minimisé.
alter function app.my_school_ids() set search_path=public,app;
alter function app.is_super_admin() set search_path=public,app;
alter function app.has_permission(text,uuid) set search_path=public,app;

-- Audit : aucune modification/suppression directe par les utilisateurs.
create or replace function app.prevent_audit_mutation()
returns trigger language plpgsql security definer set search_path=public,app
as $$ begin raise exception 'AUDIT_IMMUTABLE'; end $$;
drop trigger if exists trg_audit_immutable_update on public.audit_logs;
drop trigger if exists trg_audit_immutable_delete on public.audit_logs;
create trigger trg_audit_immutable_update before update on public.audit_logs for each row execute function app.prevent_audit_mutation();
create trigger trg_audit_immutable_delete before delete on public.audit_logs for each row execute function app.prevent_audit_mutation();

-- Audit : insert via fonction dédiée uniquement.
create or replace function app.write_audit(p_school_id uuid,p_action text,p_table_name text,p_record_id uuid,p_old jsonb default null,p_new jsonb default null)
returns bigint language plpgsql security definer set search_path=public,app
as $$
declare v_id bigint;
begin
 insert into public.audit_logs(school_id,actor_user_id,action,table_name,record_id,old_data,new_data)
 values(p_school_id,auth.uid(),p_action,p_table_name,p_record_id,p_old,p_new)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function app.write_audit(uuid,text,text,uuid,jsonb,jsonb) from public;
grant execute on function app.write_audit(uuid,text,text,uuid,jsonb,jsonb) to authenticated;

-- Storage : buckets privés. Les policies Storage sont à créer si le projet utilise ces buckets.
insert into storage.buckets(id,name,public)
values
 ('school-documents','school-documents',false),
 ('student-photos','student-photos',false),
 ('report-cards','report-cards',false),
 ('receipts','receipts',false),
 ('school-assets','school-assets',false)
on conflict(id) do update set public=false;

-- Policies Storage : le chemin doit commencer par le school_id UUID.
drop policy if exists storage_school_documents_select on storage.objects;
create policy storage_school_documents_select on storage.objects for select to authenticated
using(bucket_id='school-documents' and (split_part(name,'/',1)::uuid in (select app.my_school_ids()) or app.is_super_admin()));
drop policy if exists storage_school_documents_insert on storage.objects;
create policy storage_school_documents_insert on storage.objects for insert to authenticated
with check(bucket_id='school-documents' and split_part(name,'/',1)::uuid in (select app.my_school_ids()));
drop policy if exists storage_school_documents_update on storage.objects;
create policy storage_school_documents_update on storage.objects for update to authenticated
using(bucket_id='school-documents' and split_part(name,'/',1)::uuid in (select app.my_school_ids()))
with check(bucket_id='school-documents' and split_part(name,'/',1)::uuid in (select app.my_school_ids()));
drop policy if exists storage_school_documents_delete on storage.objects;
create policy storage_school_documents_delete on storage.objects for delete to authenticated
using(bucket_id='school-documents' and app.has_permission('students.manage',split_part(name,'/',1)::uuid));

-- Les autres buckets restent privés et suivent le même principe de chemin school_id/...

do $$
declare b text; p text;
begin
  foreach b in array array['student-photos','report-cards','receipts','school-assets'] loop
    p:='storage_'||replace(b,'-','_');
    execute format('drop policy if exists %I on storage.objects',p||'_select');
    execute format('create policy %I on storage.objects for select to authenticated using(bucket_id=%L and (split_part(name,''/'',1)::uuid in (select app.my_school_ids()) or app.is_super_admin()))',p||'_select',b);
    execute format('drop policy if exists %I on storage.objects',p||'_insert');
    execute format('create policy %I on storage.objects for insert to authenticated with check(bucket_id=%L and split_part(name,''/'',1)::uuid in (select app.my_school_ids()))',p||'_insert',b);
  end loop;
end $$;

/* =========================================================
   F. MATRICE DES RÔLES
   ========================================================= */

-- Complète la matrice métier sans donner de droits implicites aux portails.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code='direction'
  and p.code in ('students.view','parents.view','enrollments.manage','classes.manage','subjects.manage','teachers.manage','timetable.manage','assessments.manage','grades.publish','report_cards.generate','attendance.manage','discipline.manage','finance.view','boarding.manage','catering.manage','hr.manage','stock.manage','purchases.manage','agriculture.manage','livestock.manage','communication.manage','reports.view','ai.use','audit.view')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code='parent' and p.code in ('students.view','parents.view','finance.view','reports.view')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code='student' and p.code in ('students.view','reports.view')
on conflict do nothing;

-- Les portails ne reçoivent jamais de permissions de modification financière/pédagogique.
delete from public.role_permissions rp using public.roles r, public.permissions p
where rp.role_id=r.id and rp.permission_id=p.id and r.code in ('parent','student')
  and p.code in ('students.manage','parents.manage','finance.manage','expenses.manage','cash.manage','grades.enter','grades.publish','report_cards.generate','users.manage','users.roles.manage','settings.manage');

commit;

/* =========================================================
   G. CHECKLIST DE VALIDATION 1A.1
   =========================================================
   1. Deux school_id différents sur une relation critique => erreur CROSS_SCHOOL.
   2. Parent => uniquement ses enfants sur les données du portail.
   3. Élève => uniquement son propre dossier/résultats/finance.
   4. Enseignant => périmètre lié à ses affectations.
   5. Comptable => finance selon permissions, pas administration technique.
   6. Surveillant => présence/disciplines selon permissions.
   7. Direction => pilotage transversal sans contourner les permissions d'écriture.
   8. IT => administration technique sans accès métier global implicite.
   9. Paiement => allocations plafonnées et transactionnelles.
  10. Stock => mouvements source + balance synchronisée, stock négatif bloqué.
  11. Internat => étudiant/lit uniques parmi les affectations actives.
  12. Notes/bulletins publiés => verrouillés.
  13. Audit => lecture contrôlée et modification directe interdite.
  14. Storage => buckets privés et chemins isolés par school_id.
*/
