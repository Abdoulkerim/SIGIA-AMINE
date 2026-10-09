-- SIGIA-AMINE
-- Migration 023: finance & comptabilite workflows
-- Etape 15 - tarification, facturation, paiements, caisse, depenses, impayes
begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- 01. PERMISSIONS FINANCE FINE
-- =========================================================
insert into public.permissions(code,name,module,action,description) values
('finance.reports','Consulter rapports financiers','finance','reports','Tableaux de bord financiers, impayes et soldes')
on conflict(code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='finance.reports'
where r.code in ('super_admin','founder','direction','accountant') on conflict do nothing;

-- =========================================================
-- 02. COLUMNS / INDEXES / QUALITY CONSTRAINTS
-- =========================================================
alter table public.fee_types add column if not exists created_at timestamptz not null default now();
alter table public.fee_types add column if not exists updated_at timestamptz not null default now();
alter table public.expense_categories add column if not exists created_at timestamptz not null default now();
alter table public.expense_categories add column if not exists updated_at timestamptz not null default now();
alter table public.suppliers add column if not exists created_at timestamptz not null default now();
alter table public.suppliers add column if not exists updated_at timestamptz not null default now();
alter table public.expenses add column if not exists updated_at timestamptz not null default now();
alter table public.collection_reminders add column if not exists updated_at timestamptz not null default now();
alter table public.cash_accounts add constraint cash_accounts_type_ck check(account_type in ('cash','bank','mobile_money','other')) not valid;
alter table public.cash_accounts validate constraint cash_accounts_type_ck;

create unique index if not exists ux_fee_types_school_lower_code on public.fee_types(school_id, lower(code));
create unique index if not exists ux_expense_categories_school_lower_code on public.expense_categories(school_id, lower(code));
create unique index if not exists ux_suppliers_school_lower_code on public.suppliers(school_id, lower(code));
create index if not exists ix_fee_schedules_school_year_level on public.fee_schedules(school_year_id,level_id,fee_type_id);
create index if not exists ix_student_charges_student_status on public.student_charges(student_id,status,due_date);
create index if not exists ix_invoices_student_status on public.invoices(student_id,status,due_date);
create index if not exists ix_invoice_items_invoice on public.invoice_items(invoice_id);
create index if not exists ix_payments_school_date on public.payments(school_id,payment_date desc);
create index if not exists ix_payment_allocations_invoice on public.payment_allocations(invoice_id);
create index if not exists ix_payment_allocations_charge on public.payment_allocations(student_charge_id);
create index if not exists ix_expenses_school_date_status on public.expenses(school_id,expense_date desc,approval_status);
create index if not exists ix_cash_transactions_account_date on public.cash_transactions(cash_account_id,transaction_date desc);
create index if not exists ix_collection_reminders_school_status on public.collection_reminders(school_id,status,reminder_date desc);

-- Invoice item discounts may not exceed line gross amount.
create or replace function app.validate_invoice_item_amounts()
returns trigger language plpgsql security definer set search_path=public,app as $$
begin
  if new.quantity <= 0 or new.unit_amount < 0 or new.discount < 0 then
    raise exception 'INVALID_INVOICE_ITEM_AMOUNT';
  end if;
  if new.discount > (new.quantity * new.unit_amount) then
    raise exception 'INVOICE_ITEM_DISCOUNT_EXCEEDS_GROSS';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_invoice_item_amounts on public.invoice_items;
create trigger trg_validate_invoice_item_amounts
before insert or update on public.invoice_items
for each row execute function app.validate_invoice_item_amounts();

-- Generic updated_at helper is already available in migration 013.
drop trigger if exists trg_fee_types_updated_at on public.fee_types;
create trigger trg_fee_types_updated_at before update on public.fee_types for each row execute function app.set_updated_at();
drop trigger if exists trg_expense_categories_updated_at on public.expense_categories;
create trigger trg_expense_categories_updated_at before update on public.expense_categories for each row execute function app.set_updated_at();
drop trigger if exists trg_suppliers_updated_at on public.suppliers;
create trigger trg_suppliers_updated_at before update on public.suppliers for each row execute function app.set_updated_at();
drop trigger if exists trg_expenses_updated_at on public.expenses;
create trigger trg_expenses_updated_at before update on public.expenses for each row execute function app.set_updated_at();
drop trigger if exists trg_collection_reminders_updated_at on public.collection_reminders;
create trigger trg_collection_reminders_updated_at before update on public.collection_reminders for each row execute function app.set_updated_at();

-- =========================================================
-- 03. CROSS-SCHOOL AND BUSINESS INTEGRITY
-- =========================================================
create or replace function app.validate_finance_relationships()
returns trigger language plpgsql security definer set search_path=public,app as $$
declare
  v_school uuid;
  v_student_school uuid;
  v_parent_school uuid;
  v_fee_school uuid;
  v_enrollment_school uuid;
  v_invoice_school uuid;
  v_account_school uuid;
  v_category_school uuid;
  v_supplier_school uuid;
begin
  if tg_table_name='fee_schedules' then
    select school_id into v_fee_school from public.fee_types where id=new.fee_type_id;
    if v_fee_school is null or v_fee_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_FEE_TYPE'; end if;
    select school_id into v_enrollment_school from public.school_years where id=new.school_year_id;
    if v_enrollment_school is null or v_enrollment_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_SCHOOL_YEAR'; end if;
    if new.level_id is not null then
      select school_id into v_school from public.levels where id=new.level_id;
      if v_school is null or v_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_LEVEL'; end if;
    end if;
  elsif tg_table_name='student_charges' then
    select school_id into v_student_school from public.students where id=new.student_id;
    if v_student_school is null or v_student_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_STUDENT'; end if;
    select school_id into v_fee_school from public.fee_types where id=new.fee_type_id;
    if v_fee_school is null or v_fee_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_FEE_TYPE'; end if;
    if new.enrollment_id is not null then
      select school_id into v_enrollment_school from public.enrollments where id=new.enrollment_id;
      if v_enrollment_school is null or v_enrollment_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_ENROLLMENT'; end if;
      if not exists(select 1 from public.enrollments e where e.id=new.enrollment_id and e.student_id=new.student_id) then raise exception 'FINANCE_ENROLLMENT_STUDENT_MISMATCH'; end if;
    end if;
  elsif tg_table_name='invoices' then
    if new.student_id is not null then
      select school_id into v_student_school from public.students where id=new.student_id;
      if v_student_school is null or v_student_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_STUDENT'; end if;
    end if;
    if new.parent_id is not null then
      select school_id into v_parent_school from public.parents where id=new.parent_id;
      if v_parent_school is null or v_parent_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_PARENT'; end if;
      if new.student_id is not null and not exists(select 1 from public.student_parents sp where sp.student_id=new.student_id and sp.parent_id=new.parent_id) then
        raise exception 'FINANCE_PARENT_NOT_LINKED_TO_STUDENT';
      end if;
    end if;
  elsif tg_table_name='payments' then
    if new.student_id is null and new.payer_parent_id is null then raise exception 'PAYMENT_NEEDS_STUDENT_OR_PARENT'; end if;
    if new.student_id is not null then
      select school_id into v_student_school from public.students where id=new.student_id;
      if v_student_school is null or v_student_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_STUDENT'; end if;
    end if;
    if new.payer_parent_id is not null then
      select school_id into v_parent_school from public.parents where id=new.payer_parent_id;
      if v_parent_school is null or v_parent_school <> new.school_id then raise exception 'FINANCE_CROSS_SCHOOL_PARENT'; end if;
      if new.student_id is not null and not exists(select 1 from public.student_parents sp where sp.student_id=new.student_id and sp.parent_id=new.payer_parent_id) then
        raise exception 'FINANCE_PARENT_NOT_LINKED_TO_STUDENT';
      end if;
    end if;
  elsif tg_table_name='receipts' then
    select school_id into v_invoice_school from public.payments where id=new.payment_id;
    if v_invoice_school is null or v_invoice_school <> new.school_id then raise exception 'RECEIPT_PAYMENT_SCHOOL_MISMATCH'; end if;
  elsif tg_table_name='expenses' then
    if new.category_id is not null then
      select school_id into v_category_school from public.expense_categories where id=new.category_id;
      if v_category_school is null or v_category_school <> new.school_id then raise exception 'EXPENSE_CATEGORY_SCHOOL_MISMATCH'; end if;
    end if;
    if new.supplier_id is not null then
      select school_id into v_supplier_school from public.suppliers where id=new.supplier_id;
      if v_supplier_school is null or v_supplier_school <> new.school_id then raise exception 'EXPENSE_SUPPLIER_SCHOOL_MISMATCH'; end if;
    end if;
  elsif tg_table_name='cash_accounts' then
    if new.account_type not in ('cash','bank','mobile_money','other') then raise exception 'INVALID_CASH_ACCOUNT_TYPE'; end if;
  elsif tg_table_name='cash_transactions' then
    select school_id into v_account_school from public.cash_accounts where id=new.cash_account_id;
    if v_account_school is null or v_account_school <> new.school_id then raise exception 'CASH_ACCOUNT_SCHOOL_MISMATCH'; end if;
    if new.amount < 0 then raise exception 'INVALID_CASH_TRANSACTION_AMOUNT'; end if;
  elsif tg_table_name='cash_closings' then
    select school_id into v_account_school from public.cash_accounts where id=new.cash_account_id;
    if v_account_school is null or v_account_school <> new.school_id then raise exception 'CASH_CLOSING_ACCOUNT_SCHOOL_MISMATCH'; end if;
  elsif tg_table_name='collection_reminders' then
    if new.student_id is null and new.parent_id is null then raise exception 'REMINDER_NEEDS_STUDENT_OR_PARENT'; end if;
    if new.student_id is not null then
      select school_id into v_student_school from public.students where id=new.student_id;
      if v_student_school is null or v_student_school <> new.school_id then raise exception 'REMINDER_STUDENT_SCHOOL_MISMATCH'; end if;
    end if;
    if new.parent_id is not null then
      select school_id into v_parent_school from public.parents where id=new.parent_id;
      if v_parent_school is null or v_parent_school <> new.school_id then raise exception 'REMINDER_PARENT_SCHOOL_MISMATCH'; end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_fee_schedule_relationships on public.fee_schedules;
create trigger trg_validate_fee_schedule_relationships before insert or update on public.fee_schedules for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_student_charge_relationships on public.student_charges;
create trigger trg_validate_student_charge_relationships before insert or update on public.student_charges for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_invoice_relationships on public.invoices;
create trigger trg_validate_invoice_relationships before insert or update on public.invoices for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_payment_relationships on public.payments;
create trigger trg_validate_payment_relationships before insert or update on public.payments for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_receipt_relationships on public.receipts;
create trigger trg_validate_receipt_relationships before insert or update on public.receipts for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_expense_relationships on public.expenses;
create trigger trg_validate_expense_relationships before insert or update on public.expenses for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_cash_account_relationships on public.cash_accounts;
create trigger trg_validate_cash_account_relationships before insert or update on public.cash_accounts for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_cash_transaction_relationships on public.cash_transactions;
create trigger trg_validate_cash_transaction_relationships before insert or update on public.cash_transactions for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_cash_closing_relationships on public.cash_closings;
create trigger trg_validate_cash_closing_relationships before insert or update on public.cash_closings for each row execute function app.validate_finance_relationships();
drop trigger if exists trg_validate_collection_reminder_relationships on public.collection_reminders;
create trigger trg_validate_collection_reminder_relationships before insert or update on public.collection_reminders for each row execute function app.validate_finance_relationships();

-- =========================================================
-- 04. INVOICE TOTALS + PAYMENT STATUS
-- =========================================================
create or replace function app.recompute_invoice_total(p_invoice_id uuid)
returns void language plpgsql security definer set search_path=public,app as $$
declare
  v_subtotal numeric(14,2);
  v_total numeric(14,2);
begin
  select coalesce(sum(quantity*unit_amount),0), coalesce(sum(line_total),0)
    into v_subtotal, v_total
  from public.invoice_items where invoice_id=p_invoice_id;
  update public.invoices
  set subtotal=v_subtotal,total=v_total,updated_at=now()
  where id=p_invoice_id;
end $$;

drop trigger if exists trg_recompute_invoice_total_insert on public.invoice_items;
create or replace function app.trg_recompute_invoice_total()
returns trigger language plpgsql security definer set search_path=public,app as $$
begin
  if tg_op='DELETE' then
    perform app.recompute_invoice_total(old.invoice_id);
  else
    perform app.recompute_invoice_total(new.invoice_id);
    if tg_op='UPDATE' and old.invoice_id is distinct from new.invoice_id then
      perform app.recompute_invoice_total(old.invoice_id);
    end if;
  end if;
  return coalesce(new,old);
end $$;
create trigger trg_recompute_invoice_total_insert after insert or update or delete on public.invoice_items for each row execute function app.trg_recompute_invoice_total();

create or replace function app.refresh_invoice_status(p_invoice_id uuid)
returns void language plpgsql security definer set search_path=public,app as $$
declare
  v_total numeric(14,2);
  v_paid numeric(14,2);
  v_status app.payment_status;
begin
  select total into v_total from public.invoices where id=p_invoice_id for update;
  if v_total is null then return; end if;
  select coalesce(sum(amount),0) into v_paid from public.payment_allocations where invoice_id=p_invoice_id;
  if v_paid <= 0 then v_status='pending';
  elsif v_paid + 0.005 >= v_total then v_status='paid';
  else v_status='partially_paid'; end if;
  update public.invoices set status=v_status,updated_at=now() where id=p_invoice_id;
end $$;

create or replace function app.refresh_student_charge_status(p_charge_id uuid)
returns void language plpgsql security definer set search_path=public,app as $$
declare
  v_due numeric(14,2);
  v_paid numeric(14,2);
  v_status app.payment_status;
begin
  select amount_due into v_due from public.student_charges where id=p_charge_id for update;
  if v_due is null then return; end if;
  select coalesce(sum(amount),0) into v_paid from public.payment_allocations where student_charge_id=p_charge_id;
  if v_paid <= 0 then v_status='pending';
  elsif v_paid + 0.005 >= v_due then v_status='paid';
  else v_status='partially_paid'; end if;
  update public.student_charges set status=v_status where id=p_charge_id;
end $$;

create or replace function app.validate_payment_allocation()
returns trigger language plpgsql security definer set search_path=public,app as $$
declare
  v_payment_school uuid;
  v_payment_amount numeric(14,2);
  v_existing numeric(14,2);
  v_target_school uuid;
  v_target_total numeric(14,2);
  v_payment_student uuid;
  v_target_student uuid;
  v_target_paid numeric(14,2);
begin
  if new.amount <= 0 then raise exception 'INVALID_PAYMENT_ALLOCATION_AMOUNT'; end if;
  if new.invoice_id is null and new.student_charge_id is null then raise exception 'ALLOCATION_NEEDS_INVOICE_OR_CHARGE'; end if;
  if new.invoice_id is not null and new.student_charge_id is not null then raise exception 'ALLOCATION_TARGET_MUST_BE_SINGLE'; end if;
  select school_id, amount, student_id into v_payment_school,v_payment_amount,v_payment_student from public.payments where id=new.payment_id for update;
  if v_payment_school is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
  select coalesce(sum(amount),0) into v_existing from public.payment_allocations where payment_id=new.payment_id and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000');
  if v_existing + new.amount > v_payment_amount + 0.005 then raise exception 'PAYMENT_OVERALLOCATED'; end if;
  if new.invoice_id is not null then
    select school_id,total,student_id into v_target_school,v_target_total,v_target_student from public.invoices where id=new.invoice_id for update;
    if v_target_school is null or v_target_school<>v_payment_school then raise exception 'ALLOCATION_CROSS_SCHOOL_INVOICE'; end if;
    if v_payment_student is not null and v_target_student is not null and v_payment_student<>v_target_student then raise exception 'PAYMENT_STUDENT_INVOICE_MISMATCH'; end if;
    select coalesce(sum(amount),0) into v_target_paid from public.payment_allocations where invoice_id=new.invoice_id and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000');
    if v_target_paid + new.amount > v_target_total + 0.005 then raise exception 'INVOICE_OVERALLOCATED'; end if;
  else
    select school_id,amount_due,student_id into v_target_school,v_target_total,v_target_student from public.student_charges where id=new.student_charge_id for update;
    if v_target_school is null or v_target_school<>v_payment_school then raise exception 'ALLOCATION_CROSS_SCHOOL_CHARGE'; end if;
    if v_payment_student is not null and v_payment_student<>v_target_student then raise exception 'PAYMENT_STUDENT_CHARGE_MISMATCH'; end if;
    select coalesce(sum(amount),0) into v_target_paid from public.payment_allocations where student_charge_id=new.student_charge_id and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000');
    if v_target_paid + new.amount > v_target_total + 0.005 then raise exception 'CHARGE_OVERALLOCATED'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_payment_allocation on public.payment_allocations;
create trigger trg_validate_payment_allocation before insert or update on public.payment_allocations for each row execute function app.validate_payment_allocation();

create or replace function app.refresh_finance_target_status()
returns trigger language plpgsql security definer set search_path=public,app as $$
begin
  if coalesce(new.invoice_id,old.invoice_id) is not null then perform app.refresh_invoice_status(coalesce(new.invoice_id,old.invoice_id)); end if;
  if coalesce(new.student_charge_id,old.student_charge_id) is not null then perform app.refresh_student_charge_status(coalesce(new.student_charge_id,old.student_charge_id)); end if;
  return coalesce(new,old);
end $$;

drop trigger if exists trg_refresh_finance_target_status on public.payment_allocations;
create trigger trg_refresh_finance_target_status after insert or update or delete on public.payment_allocations for each row execute function app.refresh_finance_target_status();

-- =========================================================
-- 05. SCOPED RLS - PARENTS/ELÈVES EN LECTURE, STAFF EN GESTION
-- =========================================================
-- Replaces the baseline generated CRUD policies on finance tables.
do $$
declare r record;
begin
  for r in select policyname,tablename from pg_policies where schemaname='public' and tablename in
  ('fee_types','fee_schedules','student_charges','invoices','invoice_items','payments','payment_allocations','receipts','expense_categories','suppliers','expenses','cash_accounts','cash_transactions','cash_closings','collection_reminders') loop
    execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename);
  end loop;
end $$;

-- Fee configuration: staff only.
create policy fee_types_select_scoped on public.fee_types for select using(app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.is_super_admin());
create policy fee_types_manage_scoped on public.fee_types for all using(app.has_permission('finance.manage',school_id) or app.is_super_admin()) with check(app.has_permission('finance.manage',school_id) or app.is_super_admin());
create policy fee_schedules_select_scoped on public.fee_schedules for select using(app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.is_super_admin());
create policy fee_schedules_manage_scoped on public.fee_schedules for all using(app.has_permission('finance.manage',school_id) or app.is_super_admin()) with check(app.has_permission('finance.manage',school_id) or app.is_super_admin());
create policy expense_categories_select_scoped on public.expense_categories for select using(app.has_permission('finance.view',school_id) or app.has_permission('expenses.manage',school_id) or app.is_super_admin());
create policy expense_categories_manage_scoped on public.expense_categories for all using(app.has_permission('expenses.manage',school_id) or app.is_super_admin()) with check(app.has_permission('expenses.manage',school_id) or app.is_super_admin());
create policy suppliers_select_scoped on public.suppliers for select using(app.has_permission('finance.view',school_id) or app.has_permission('expenses.manage',school_id) or app.has_permission('purchases.manage',school_id) or app.is_super_admin());
create policy suppliers_manage_scoped on public.suppliers for all using(app.has_permission('purchases.manage',school_id) or app.has_permission('expenses.manage',school_id) or app.is_super_admin()) with check(app.has_permission('purchases.manage',school_id) or app.has_permission('expenses.manage',school_id) or app.is_super_admin());

-- Charges/invoices/payments/receipts: child/parent may read own scope, staff manages.
create policy student_charges_select_scoped on public.student_charges for select using(
  app.is_self_student(student_id) or app.is_parent_of_student(student_id) or
  app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.is_super_admin()
);
create policy student_charges_manage_scoped on public.student_charges for all using(app.has_permission('finance.manage',school_id) or app.is_super_admin()) with check(app.has_permission('finance.manage',school_id) or app.is_super_admin());

create policy invoices_select_scoped_v2 on public.invoices for select using(
  (student_id is not null and (app.is_self_student(student_id) or app.is_parent_of_student(student_id))) or
  app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.is_super_admin()
);
create policy invoices_manage_scoped_v2 on public.invoices for all using(app.has_permission('finance.manage',school_id) or app.is_super_admin()) with check(app.has_permission('finance.manage',school_id) or app.is_super_admin());

create policy invoice_items_select_scoped_v2 on public.invoice_items for select using(exists(select 1 from public.invoices i where i.id=invoice_id and (
  (i.student_id is not null and (app.is_self_student(i.student_id) or app.is_parent_of_student(i.student_id))) or
  app.has_permission('finance.view',i.school_id) or app.has_permission('finance.manage',i.school_id) or app.is_super_admin()
)));
create policy invoice_items_manage_scoped_v2 on public.invoice_items for all using(exists(select 1 from public.invoices i where i.id=invoice_id and (app.has_permission('finance.manage',i.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.invoices i where i.id=invoice_id and (app.has_permission('finance.manage',i.school_id) or app.is_super_admin())));

create policy payments_select_scoped_v2 on public.payments for select using(
  (student_id is not null and (app.is_self_student(student_id) or app.is_parent_of_student(student_id))) or
  app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.is_super_admin()
);
create policy payments_manage_scoped_v2 on public.payments for all using(app.has_permission('finance.manage',school_id) or app.is_super_admin()) with check(app.has_permission('finance.manage',school_id) or app.is_super_admin());

create policy payment_allocations_select_scoped_v2 on public.payment_allocations for select using(exists(select 1 from public.payments p where p.id=payment_id and (
  (p.student_id is not null and (app.is_self_student(p.student_id) or app.is_parent_of_student(p.student_id))) or
  app.has_permission('finance.view',p.school_id) or app.has_permission('finance.manage',p.school_id) or app.is_super_admin()
)));
create policy payment_allocations_manage_scoped_v2 on public.payment_allocations for all using(exists(select 1 from public.payments p where p.id=payment_id and (app.has_permission('finance.manage',p.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.payments p where p.id=payment_id and (app.has_permission('finance.manage',p.school_id) or app.is_super_admin())));

create policy receipts_select_scoped on public.receipts for select using(exists(select 1 from public.payments p where p.id=payment_id and (
  (p.student_id is not null and (app.is_self_student(p.student_id) or app.is_parent_of_student(p.student_id))) or
  app.has_permission('finance.view',p.school_id) or app.has_permission('finance.manage',p.school_id) or app.is_super_admin()
)));
create policy receipts_manage_scoped on public.receipts for all using(app.has_permission('finance.manage',school_id) or app.is_super_admin()) with check(app.has_permission('finance.manage',school_id) or app.is_super_admin());

create policy expenses_select_scoped on public.expenses for select using(app.has_permission('finance.view',school_id) or app.has_permission('expenses.manage',school_id) or app.is_super_admin());
create policy expenses_manage_scoped on public.expenses for all using(app.has_permission('expenses.manage',school_id) or app.is_super_admin()) with check(app.has_permission('expenses.manage',school_id) or app.is_super_admin());

create policy cash_accounts_select_scoped on public.cash_accounts for select using(app.has_permission('finance.view',school_id) or app.has_permission('cash.manage',school_id) or app.is_super_admin());
create policy cash_accounts_manage_scoped on public.cash_accounts for all using(app.has_permission('cash.manage',school_id) or app.is_super_admin()) with check(app.has_permission('cash.manage',school_id) or app.is_super_admin());
create policy cash_transactions_select_scoped on public.cash_transactions for select using(app.has_permission('finance.view',school_id) or app.has_permission('cash.manage',school_id) or app.is_super_admin());
-- Direct writes are disabled: sensitive cash movements go through SECURITY DEFINER RPCs.
create policy cash_closings_select_scoped on public.cash_closings for select using(app.has_permission('finance.view',school_id) or app.has_permission('cash.manage',school_id) or app.is_super_admin());
create policy cash_closings_manage_scoped on public.cash_closings for all using(app.has_permission('cash.manage',school_id) or app.is_super_admin()) with check(app.has_permission('cash.manage',school_id) or app.is_super_admin());

create policy collection_reminders_select_scoped on public.collection_reminders for select using(
  (student_id is not null and (app.is_self_student(student_id) or app.is_parent_of_student(student_id))) or
  app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.is_super_admin()
);
create policy collection_reminders_manage_scoped on public.collection_reminders for all using(app.has_permission('finance.manage',school_id) or app.is_super_admin()) with check(app.has_permission('finance.manage',school_id) or app.is_super_admin());

-- Financial ledgers are write-protected from direct Data API mutation.
drop policy if exists student_charges_manage_scoped on public.student_charges;
drop policy if exists invoices_manage_scoped_v2 on public.invoices;
drop policy if exists invoice_items_manage_scoped_v2 on public.invoice_items;
drop policy if exists payments_manage_scoped_v2 on public.payments;
drop policy if exists payment_allocations_manage_scoped_v2 on public.payment_allocations;
drop policy if exists receipts_manage_scoped on public.receipts;
drop policy if exists expenses_manage_scoped on public.expenses;
drop policy if exists cash_accounts_manage_scoped on public.cash_accounts;
drop policy if exists cash_closings_manage_scoped on public.cash_closings;
drop policy if exists collection_reminders_manage_scoped on public.collection_reminders;

-- =========================================================
-- 06. SECURE RPCS - WRITE PATHS
-- =========================================================
create or replace function public.create_fee_type(p_school_id uuid,p_code text,p_name text,p_category text,p_description text default null)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_id uuid;
begin
  if not app.is_super_admin() and not app.has_permission('finance.manage',p_school_id) then raise exception 'FORBIDDEN'; end if;
  insert into public.fee_types(school_id,code,name,category,description) values(p_school_id,trim(p_code),trim(p_name),trim(p_category),nullif(trim(p_description),'')) returning id into v_id;
  return v_id;
end $$;

create or replace function public.create_fee_schedule(p_school_year_id uuid,p_level_id uuid,p_residence_type app.residence_type,p_fee_type_id uuid,p_amount numeric,p_due_date date default null,p_installment_no integer default 1)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_id uuid; v_school uuid;
begin
  select school_id into v_school from public.school_years where id=p_school_year_id;
  if v_school is null then raise exception 'SCHOOL_YEAR_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('finance.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  if p_amount < 0 or p_installment_no < 1 then raise exception 'INVALID_FEE_SCHEDULE'; end if;
  insert into public.fee_schedules(school_id,school_year_id,level_id,residence_type,fee_type_id,amount,due_date,installment_no)
  values(v_school,p_school_year_id,p_level_id,p_residence_type,p_fee_type_id,p_amount,p_due_date,p_installment_no) returning id into v_id;
  return v_id;
end $$;

create or replace function public.create_student_charge(p_student_id uuid,p_fee_type_id uuid,p_amount_due numeric,p_due_date date,p_enrollment_id uuid default null,p_description text default null)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_id uuid; v_school uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null then raise exception 'STUDENT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('finance.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  if p_amount_due <= 0 then raise exception 'CHARGE_AMOUNT_MUST_BE_POSITIVE'; end if;
  insert into public.student_charges(school_id,student_id,enrollment_id,fee_type_id,description,amount_due,due_date)
  values(v_school,p_student_id,p_enrollment_id,p_fee_type_id,nullif(trim(p_description),''),p_amount_due,p_due_date) returning id into v_id;
  return v_id;
end $$;

create or replace function public.create_invoice(p_student_id uuid,p_parent_id uuid,p_issue_date date,p_due_date date,p_notes text,p_items jsonb)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare
  v_school uuid; v_id uuid; v_number text; item jsonb;
  v_fee_type uuid; v_description text; v_qty numeric; v_unit numeric; v_discount numeric;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null and p_parent_id is not null then select school_id into v_school from public.parents where id=p_parent_id; end if;
  if v_school is null then raise exception 'INVOICE_SCOPE_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('finance.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'INVOICE_NEEDS_ITEMS'; end if;
  v_number := 'FAC-' || to_char(now(),'YYYYMMDDHH24MISSMS') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.invoices(school_id,invoice_number,student_id,parent_id,issue_date,due_date,notes,created_by)
  values(v_school,v_number,p_student_id,p_parent_id,coalesce(p_issue_date,current_date),p_due_date,p_notes,auth.uid()) returning id into v_id;
  for item in select * from jsonb_array_elements(p_items) loop
    v_fee_type := nullif(item->>'fee_type_id','')::uuid;
    v_description := trim(coalesce(item->>'description',''));
    v_qty := coalesce(nullif(item->>'quantity','')::numeric,1);
    v_unit := coalesce(nullif(item->>'unit_amount','')::numeric,0);
    v_discount := coalesce(nullif(item->>'discount','')::numeric,0);
    if v_description='' or v_unit<0 or v_qty<=0 or v_discount<0 or v_discount>v_qty*v_unit then raise exception 'INVALID_INVOICE_ITEM'; end if;
    insert into public.invoice_items(invoice_id,fee_type_id,description,quantity,unit_amount,discount)
    values(v_id,v_fee_type,v_description,v_qty,v_unit,v_discount);
  end loop;
  return v_id;
end $$;

create or replace function public.record_payment(p_student_id uuid,p_parent_id uuid,p_amount numeric,p_payment_date timestamptz,p_method app.payment_method,p_reference text,p_notes text,p_allocations jsonb,p_cash_account_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare
  v_school uuid; v_payment uuid; v_number text; a jsonb; v_sum numeric:=0; v_amount numeric;
  v_invoice uuid; v_charge uuid; v_cash_school uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  if v_school is null and p_parent_id is not null then select school_id into v_school from public.parents where id=p_parent_id; end if;
  if v_school is null then raise exception 'PAYMENT_SCOPE_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('finance.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  if p_amount <= 0 then raise exception 'PAYMENT_AMOUNT_MUST_BE_POSITIVE'; end if;
  if p_allocations is null or jsonb_typeof(p_allocations)<>'array' or jsonb_array_length(p_allocations)=0 then raise exception 'PAYMENT_NEEDS_ALLOCATIONS'; end if;
  for a in select * from jsonb_array_elements(p_allocations) loop
    v_amount := (a->>'amount')::numeric;
    v_sum := v_sum + v_amount;
  end loop;
  if abs(v_sum-p_amount) > 0.005 then raise exception 'PAYMENT_ALLOCATIONS_MUST_EQUAL_PAYMENT'; end if;
  if p_cash_account_id is not null then
    select school_id into v_cash_school from public.cash_accounts where id=p_cash_account_id;
    if v_cash_school is null or v_cash_school<>v_school then raise exception 'PAYMENT_CASH_ACCOUNT_SCHOOL_MISMATCH'; end if;
  end if;
  v_number := 'PAY-' || to_char(now(),'YYYYMMDDHH24MISSMS') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.payments(school_id,payment_number,payer_parent_id,student_id,amount,payment_date,method,reference,status,received_by,notes)
  values(v_school,v_number,p_parent_id,p_student_id,p_amount,coalesce(p_payment_date,now()),p_method,nullif(trim(p_reference),''),'paid',auth.uid(),nullif(trim(p_notes),'')) returning id into v_payment;
  for a in select * from jsonb_array_elements(p_allocations) loop
    v_invoice := null; v_charge := null;
    if nullif(a->>'invoice_id','') is not null then v_invoice := (a->>'invoice_id')::uuid; end if;
    if nullif(a->>'student_charge_id','') is not null then v_charge := (a->>'student_charge_id')::uuid; end if;
    insert into public.payment_allocations(payment_id,invoice_id,student_charge_id,amount) values(v_payment,v_invoice,v_charge,(a->>'amount')::numeric);
  end loop;
  insert into public.receipts(school_id,payment_id,receipt_number,issued_at) values(v_school,v_payment,'REC-'||to_char(now(),'YYYYMMDDHH24MISSMS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),coalesce(p_payment_date,now()));
  if p_cash_account_id is not null then
    insert into public.cash_transactions(school_id,cash_account_id,transaction_type,amount,transaction_date,reference_type,reference_id,description,created_by)
    values(v_school,p_cash_account_id,'income',p_amount,coalesce(p_payment_date,now()),'payment',v_payment,'Encaissement paiement '||v_number,auth.uid());
  end if;
  return v_payment;
end $$;

create or replace function public.create_expense(p_category_id uuid,p_supplier_id uuid,p_amount numeric,p_expense_date date,p_description text,p_payment_method app.payment_method default null,p_cash_account_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_school uuid; v_id uuid; v_number text; v_status app.approval_status:='draft';
begin
  if p_category_id is not null then select school_id into v_school from public.expense_categories where id=p_category_id; end if;
  if v_school is null and p_supplier_id is not null then select school_id into v_school from public.suppliers where id=p_supplier_id; end if;
  if v_school is null and p_cash_account_id is not null then select school_id into v_school from public.cash_accounts where id=p_cash_account_id; end if;
  if v_school is null then select school_id into v_school from public.users where id=auth.uid(); end if;
  if v_school is null then raise exception 'EXPENSE_SCOPE_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('expenses.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  if p_amount < 0 then raise exception 'EXPENSE_AMOUNT_INVALID'; end if;
  if p_cash_account_id is not null and p_payment_method is null then raise exception 'EXPENSE_PAYMENT_METHOD_REQUIRED'; end if;
  v_number := 'DEP-' || to_char(now(),'YYYYMMDDHH24MISSMS') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.expenses(school_id,expense_number,category_id,supplier_id,amount,expense_date,description,payment_method,approval_status,created_by)
  values(v_school,v_number,p_category_id,p_supplier_id,p_amount,coalesce(p_expense_date,current_date),trim(p_description),p_payment_method,v_status,auth.uid()) returning id into v_id;
  return v_id;
end $$;

create or replace function public.approve_expense(p_expense_id uuid,p_cash_account_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_school uuid; v_amount numeric; v_method app.payment_method; v_status app.approval_status;
 v_account_school uuid;
begin
  select school_id,amount,payment_method,approval_status into v_school,v_amount,v_method,v_status from public.expenses where id=p_expense_id for update;
  if v_school is null then raise exception 'EXPENSE_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('expenses.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  if v_status='approved' then return p_expense_id; end if;
  if v_method is not null and p_cash_account_id is not null then
    select school_id into v_account_school from public.cash_accounts where id=p_cash_account_id;
    if v_account_school is null or v_account_school<>v_school then raise exception 'EXPENSE_CASH_ACCOUNT_SCHOOL_MISMATCH'; end if;
  end if;
  update public.expenses set approval_status='approved',approved_by=auth.uid(),updated_at=now() where id=p_expense_id;
  if p_cash_account_id is not null and v_method is not null then
    if exists(select 1 from public.cash_transactions where reference_type='expense' and reference_id=p_expense_id) then
      raise exception 'EXPENSE_ALREADY_POSTED_TO_CASH';
    end if;
    insert into public.cash_transactions(school_id,cash_account_id,transaction_type,amount,transaction_date,reference_type,reference_id,description,created_by)
    select school_id,p_cash_account_id,'expense',amount,expense_date::timestamptz,'expense',id,'Dépense '||expense_number,auth.uid()
    from public.expenses where id=p_expense_id;
  end if;
  return p_expense_id;
end $$;

create or replace function public.create_cash_account(p_school_id uuid,p_code text,p_name text,p_account_type text default 'cash',p_opening_balance numeric default 0)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_id uuid;
begin
  if not app.is_super_admin() and not app.has_permission('cash.manage',p_school_id) then raise exception 'FORBIDDEN'; end if;
  if p_opening_balance < 0 then raise exception 'OPENING_BALANCE_INVALID'; end if;
  insert into public.cash_accounts(school_id,code,name,account_type,opening_balance) values(p_school_id,trim(p_code),trim(p_name),p_account_type,p_opening_balance) returning id into v_id;
  return v_id;
end $$;

create or replace function public.close_cash_account(p_cash_account_id uuid,p_closing_date date,p_actual_balance numeric,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_school uuid; v_opening numeric; v_income numeric; v_expense numeric; v_expected numeric; v_id uuid;
begin
  select school_id,opening_balance into v_school,v_opening from public.cash_accounts where id=p_cash_account_id;
  if v_school is null then raise exception 'CASH_ACCOUNT_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('cash.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  select coalesce(sum(amount),0) into v_income from public.cash_transactions where cash_account_id=p_cash_account_id and transaction_date < (p_closing_date+1)::timestamptz and transaction_type in ('income','adjustment');
  select coalesce(sum(amount),0) into v_expense from public.cash_transactions where cash_account_id=p_cash_account_id and transaction_date < (p_closing_date+1)::timestamptz and transaction_type='expense';
  v_expected := coalesce(v_opening,0)+v_income-v_expense;
  insert into public.cash_closings(school_id,cash_account_id,closing_date,expected_balance,actual_balance,closed_by,notes)
  values(v_school,p_cash_account_id,p_closing_date,v_expected,p_actual_balance,auth.uid(),nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.create_collection_reminder(p_student_id uuid,p_parent_id uuid,p_amount_due numeric,p_reminder_date date,p_channel text,p_message text)
returns uuid language plpgsql security definer set search_path=public,app as $$
declare v_school uuid; v_id uuid;
begin
  if p_student_id is not null then select school_id into v_school from public.students where id=p_student_id; end if;
  if v_school is null and p_parent_id is not null then select school_id into v_school from public.parents where id=p_parent_id; end if;
  if v_school is null then raise exception 'REMINDER_SCOPE_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('finance.manage',v_school) then raise exception 'FORBIDDEN'; end if;
  insert into public.collection_reminders(school_id,student_id,parent_id,amount_due,reminder_date,channel,message,created_by)
  values(v_school,p_student_id,p_parent_id,greatest(p_amount_due,0),coalesce(p_reminder_date,current_date),nullif(trim(p_channel),''),nullif(trim(p_message),''),auth.uid()) returning id into v_id;
  return v_id;
end $$;

-- Secure dashboard. Returns only schools visible to the caller.
create or replace function public.get_finance_dashboard(p_school_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public,app as $$
declare v_school uuid; v_today date:=current_date; v_result jsonb;
begin
  v_school := coalesce(p_school_id,(select school_id from public.users where id=auth.uid()));
  if v_school is null or (not app.is_super_admin() and v_school not in (select app.my_school_ids())) then raise exception 'FORBIDDEN'; end if;
  if not app.is_super_admin() and not app.has_permission('finance.view',v_school) then raise exception 'FORBIDDEN'; end if;
  select jsonb_build_object(
    'invoice_receivable', coalesce((select sum(greatest(i.total-coalesce(pa.paid,0),0)) from public.invoices i left join lateral (select sum(amount) paid from public.payment_allocations where invoice_id=i.id) pa on true where i.school_id=v_school and i.status<>'cancelled'),0),
    'charge_receivable', coalesce((select sum(greatest(sc.amount_due-coalesce(pa.paid,0),0)) from public.student_charges sc left join lateral (select sum(amount) paid from public.payment_allocations where student_charge_id=sc.id) pa on true where sc.school_id=v_school and sc.status<>'cancelled'),0),
    'payments_today', coalesce((select sum(amount) from public.payments where school_id=v_school and payment_date::date=v_today and status='paid'),0),
    'expenses_today', coalesce((select sum(amount) from public.expenses where school_id=v_school and expense_date=v_today and approval_status='approved'),0),
    'unpaid_invoices', coalesce((select count(*) from public.invoices i where i.school_id=v_school and i.status in ('pending','partially_paid')),0),
    'overdue_invoices', coalesce((select count(*) from public.invoices i where i.school_id=v_school and i.status in ('pending','partially_paid') and i.due_date is not null and i.due_date<v_today),0),
    'cash_accounts', coalesce((select jsonb_agg(x order by x.name) from (
      select ca.id,ca.name,ca.account_type,round(ca.opening_balance + coalesce((select sum(case when ct.transaction_type in ('income','adjustment') then ct.amount when ct.transaction_type='expense' then -ct.amount else 0 end) from public.cash_transactions ct where ct.cash_account_id=ca.id),0),2) balance
      from public.cash_accounts ca where ca.school_id=v_school and ca.is_active=true
    ) x), '[]'::jsonb)
  ) into v_result;
  return v_result;
end $$;

-- Restrict RPC execution to authenticated users; RLS remains the data safety layer.
revoke all on function public.create_fee_type(uuid,text,text,text,text) from public,anon;
grant execute on function public.create_fee_type(uuid,text,text,text,text) to authenticated;
revoke all on function public.create_fee_schedule(uuid,uuid,app.residence_type,uuid,numeric,date,integer) from public,anon;
grant execute on function public.create_fee_schedule(uuid,uuid,app.residence_type,uuid,numeric,date,integer) to authenticated;
revoke all on function public.create_student_charge(uuid,uuid,numeric,date,uuid,text) from public,anon;
grant execute on function public.create_student_charge(uuid,uuid,numeric,date,uuid,text) to authenticated;
revoke all on function public.create_invoice(uuid,uuid,date,date,text,jsonb) from public,anon;
grant execute on function public.create_invoice(uuid,uuid,date,date,text,jsonb) to authenticated;
revoke all on function public.record_payment(uuid,uuid,numeric,timestamptz,app.payment_method,text,text,jsonb,uuid) from public,anon;
grant execute on function public.record_payment(uuid,uuid,numeric,timestamptz,app.payment_method,text,text,jsonb,uuid) to authenticated;
revoke all on function public.create_expense(uuid,uuid,numeric,date,text,app.payment_method,uuid) from public,anon;
grant execute on function public.create_expense(uuid,uuid,numeric,date,text,app.payment_method,uuid) to authenticated;
revoke all on function public.approve_expense(uuid,uuid) from public,anon;
grant execute on function public.approve_expense(uuid,uuid) to authenticated;
revoke all on function public.create_cash_account(uuid,text,text,text,numeric) from public,anon;
grant execute on function public.create_cash_account(uuid,text,text,text,numeric) to authenticated;
revoke all on function public.close_cash_account(uuid,date,numeric,text) from public,anon;
grant execute on function public.close_cash_account(uuid,date,numeric,text) to authenticated;
revoke all on function public.create_collection_reminder(uuid,uuid,numeric,date,text,text) from public,anon;
grant execute on function public.create_collection_reminder(uuid,uuid,numeric,date,text,text) to authenticated;
revoke all on function public.get_finance_dashboard(uuid) from public,anon;
grant execute on function public.get_finance_dashboard(uuid) to authenticated;

commit;
