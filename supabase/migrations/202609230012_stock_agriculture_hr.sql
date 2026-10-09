-- SIGIA-AMINE
-- Migration 012: stock_agriculture_hr
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Stock, purchases, agriculture, livestock, AGR, HR and payroll.

-- 16. STOCKS / ACHATS
-- =========================================================
create table if not exists public.stock_categories(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  unique(school_id,code)
);

create table if not exists public.stock_locations(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  location_type text,
  unique(school_id,name)
);

create table if not exists public.products(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  sku text not null,
  name text not null,
  category_id uuid references public.stock_categories(id) on delete set null,
  unit text not null,
  minimum_stock numeric(14,3) not null default 0,
  maximum_stock numeric(14,3),
  unit_cost numeric(14,2) not null default 0,
  is_active boolean not null default true,
  unique(school_id,sku)
);

create table if not exists public.stock_balances(
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  location_id uuid not null references public.stock_locations(id) on delete cascade,
  quantity numeric(14,3) not null default 0,
  updated_at timestamptz not null default now(),
  unique(product_id,location_id)
);

create table if not exists public.stock_movements(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  location_id uuid not null references public.stock_locations(id) on delete restrict,
  movement_type app.stock_movement_type not null,
  quantity numeric(14,3) not null check(quantity>0),
  unit_cost numeric(14,2),
  reference_type text,
  reference_id uuid,
  movement_date timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  notes text
);

create table if not exists public.purchase_orders(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  order_number text not null,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  order_date date not null default current_date,
  expected_date date,
  status app.approval_status not null default 'draft',
  subtotal numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  created_by uuid references public.users(id) on delete set null,
  unique(school_id,order_number)
);

create table if not exists public.purchase_items(
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  unit_cost numeric(14,2) not null check(unit_cost>=0),
  received_quantity numeric(14,3) not null default 0,
  line_total numeric(14,2) generated always as (quantity*unit_cost) stored
);

create table if not exists public.stock_inventories(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  location_id uuid not null references public.stock_locations(id) on delete restrict,
  inventory_date date not null,
  status text not null default 'draft',
  performed_by uuid references public.users(id) on delete set null,
  notes text,
  unique(location_id,inventory_date)
);

create table if not exists public.stock_inventory_items(
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.stock_inventories(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  system_quantity numeric(14,3) not null,
  counted_quantity numeric(14,3) not null,
  difference numeric(14,3) generated always as (counted_quantity-system_quantity) stored,
  unique(inventory_id,product_id)
);

-- =========================================================

-- 17. AGRICULTURE / ÉLEVAGE / AGR
-- =========================================================
create table if not exists public.economic_activities(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  activity_type text not null,
  responsible_employee_id uuid references public.employees(id) on delete set null,
  location text,
  status text not null default 'active',
  unique(school_id,code)
);

create table if not exists public.agriculture_campaigns(
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  crop text not null,
  start_date date,
  end_date date,
  area numeric(14,3),
  area_unit text,
  expected_yield numeric(14,3),
  actual_yield numeric(14,3),
  notes text
);

create table if not exists public.agriculture_expenses(
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.agriculture_campaigns(id) on delete cascade,
  expense_date date not null default current_date,
  category text not null,
  amount numeric(14,2) not null check(amount>=0),
  description text
);

create table if not exists public.livestock(
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  animal_type text not null,
  tag_number text,
  acquisition_date date,
  acquisition_cost numeric(14,2) default 0,
  status text not null default 'active',
  sex text,
  birth_date date,
  notes text,
  unique(activity_id,tag_number)
);

create table if not exists public.livestock_events(
  id uuid primary key default gen_random_uuid(),
  livestock_id uuid not null references public.livestock(id) on delete cascade,
  event_date date not null default current_date,
  event_type text not null,
  quantity numeric(14,3),
  amount numeric(14,2),
  description text
);

create table if not exists public.productions(
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  production_date date not null default current_date,
  product_name text not null,
  quantity numeric(14,3) not null check(quantity>=0),
  unit text not null,
  unit_cost numeric(14,2) default 0,
  notes text
);

create table if not exists public.sales(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  activity_id uuid references public.economic_activities(id) on delete set null,
  sale_number text not null,
  sale_date date not null default current_date,
  customer_name text,
  amount numeric(14,2) not null check(amount>=0),
  payment_method app.payment_method,
  description text,
  unique(school_id,sale_number)
);

-- =========================================================

-- 18. RESSOURCES HUMAINES
-- =========================================================
create table if not exists public.employee_contracts(
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  contract_type text not null,
  start_date date not null,
  end_date date,
  salary numeric(14,2),
  status text not null default 'active',
  document_id uuid references public.documents(id) on delete set null,
  check(end_date is null or end_date>=start_date)
);

create table if not exists public.employee_attendance(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  attendance_date date not null,
  status app.attendance_status not null,
  check_in time,
  check_out time,
  notes text,
  unique(employee_id,attendance_date)
);

create table if not exists public.employee_leaves(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  leave_type text not null,
  start_date date not null,
  end_date date not null,
  reason text,
  status app.approval_status not null default 'draft',
  approved_by uuid references public.users(id) on delete set null,
  check(end_date>=start_date)
);

create table if not exists public.payroll_periods(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  period_label text not null,
  start_date date not null,
  end_date date not null,
  status text not null default 'draft',
  unique(school_id,period_label)
);

create table if not exists public.payroll_items(
  id uuid primary key default gen_random_uuid(),
  payroll_period_id uuid not null references public.payroll_periods(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  base_salary numeric(14,2) not null default 0,
  allowances numeric(14,2) not null default 0,
  deductions numeric(14,2) not null default 0,
  net_salary numeric(14,2) generated always as ((base_salary+allowances)-deductions) stored,
  payment_status app.payment_status not null default 'pending',
  unique(payroll_period_id,employee_id)
);

-- =========================================================

commit;
