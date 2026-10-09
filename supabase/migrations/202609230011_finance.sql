-- SIGIA-AMINE
-- Migration 011: finance
-- Baseline generated from V1.0 + 1A.1 hardening
-- Source of truth: supabase/migrations/

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Fees, charges, invoices, payments, receipts, expenses, cash and reminders.

-- 15. FINANCE / COMPTABILITÉ
-- =========================================================
create table if not exists public.fee_types(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  category text not null,
  description text,
  is_active boolean not null default true,
  unique(school_id,code)
);

create table if not exists public.fee_schedules(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year_id uuid not null references public.school_years(id) on delete restrict,
  level_id uuid references public.levels(id) on delete set null,
  residence_type app.residence_type,
  fee_type_id uuid not null references public.fee_types(id) on delete restrict,
  amount numeric(14,2) not null check(amount>=0),
  due_date date,
  installment_no integer not null default 1,
  unique(school_year_id,level_id,residence_type,fee_type_id,installment_no)
);

create table if not exists public.student_charges(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  fee_type_id uuid not null references public.fee_types(id) on delete restrict,
  description text,
  amount_due numeric(14,2) not null check(amount_due>=0),
  due_date date,
  status app.payment_status not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists public.invoices(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  invoice_number text not null,
  student_id uuid references public.students(id) on delete set null,
  parent_id uuid references public.parents(id) on delete set null,
  issue_date date not null default current_date,
  due_date date,
  subtotal numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  status app.payment_status not null default 'pending',
  notes text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,invoice_number)
);

create table if not exists public.invoice_items(
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  fee_type_id uuid references public.fee_types(id) on delete set null,
  description text not null,
  quantity numeric(12,2) not null default 1 check(quantity>0),
  unit_amount numeric(14,2) not null check(unit_amount>=0),
  discount numeric(14,2) not null default 0 check(discount>=0),
  line_total numeric(14,2) generated always as ((quantity*unit_amount)-discount) stored
);

create table if not exists public.payments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  payment_number text not null,
  payer_parent_id uuid references public.parents(id) on delete set null,
  student_id uuid references public.students(id) on delete set null,
  amount numeric(14,2) not null check(amount>0),
  payment_date timestamptz not null default now(),
  method app.payment_method not null,
  reference text,
  status app.payment_status not null default 'paid',
  received_by uuid references public.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  unique(school_id,payment_number)
);

create table if not exists public.payment_allocations(
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  student_charge_id uuid references public.student_charges(id) on delete set null,
  amount numeric(14,2) not null check(amount>0)
);

create table if not exists public.receipts(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  payment_id uuid not null unique references public.payments(id) on delete cascade,
  receipt_number text not null,
  issued_at timestamptz not null default now(),
  file_path text,
  unique(school_id,receipt_number)
);

create table if not exists public.expense_categories(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  unique(school_id,code)
);

create table if not exists public.suppliers(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  contact_name text,
  phone text,
  email text,
  address text,
  tax_id text,
  unique(school_id,code)
);

create table if not exists public.expenses(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  expense_number text not null,
  category_id uuid references public.expense_categories(id) on delete set null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  amount numeric(14,2) not null check(amount>=0),
  expense_date date not null default current_date,
  description text not null,
  payment_method app.payment_method,
  approval_status app.approval_status not null default 'draft',
  approved_by uuid references public.users(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(school_id,expense_number)
);

create table if not exists public.cash_accounts(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  account_type text not null default 'cash',
  opening_balance numeric(14,2) not null default 0,
  is_active boolean not null default true,
  unique(school_id,code)
);

create table if not exists public.cash_transactions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts(id) on delete restrict,
  transaction_type app.transaction_type not null,
  amount numeric(14,2) not null check(amount>=0),
  transaction_date timestamptz not null default now(),
  reference_type text,
  reference_id uuid,
  description text not null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.cash_closings(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts(id) on delete restrict,
  closing_date date not null,
  expected_balance numeric(14,2) not null,
  actual_balance numeric(14,2) not null,
  difference numeric(14,2) generated always as (actual_balance-expected_balance) stored,
  closed_by uuid references public.users(id) on delete set null,
  notes text,
  unique(cash_account_id,closing_date)
);

create table if not exists public.collection_reminders(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid references public.students(id) on delete cascade,
  parent_id uuid references public.parents(id) on delete set null,
  amount_due numeric(14,2) not null,
  reminder_date date not null default current_date,
  channel text,
  message text,
  status text not null default 'pending',
  sent_at timestamptz,
  created_by uuid references public.users(id) on delete set null
);

-- =========================================================

commit;
