-- SIGIA-AMINE
-- Migration 027 — Stocks / Achats
-- Étape 19 : structuration opérationnelle des stocks, achats, réceptions,
-- inventaires, transferts et suivi des factures fournisseurs.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- 01. TYPES / PERMISSIONS
-- =========================================================

insert into public.permissions(code,name,module,action,description) values
  ('stock.view','Consulter stocks','stock','view','Consulter articles, niveaux et mouvements'),
  ('inventory.manage','Gérer inventaires','stock','inventory','Préparer, compter et clôturer les inventaires'),
  ('purchases.view','Consulter achats','purchases','view','Consulter fournisseurs, demandes, commandes et réceptions')
on conflict(code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code in ('super_admin','founder')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('stock.view','stock.manage','inventory.manage','purchases.view','purchases.manage','reports.view')
where r.code='stock_manager'
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('purchases.view','purchases.manage')
where r.code='accountant'
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('stock.view','purchases.view')
where r.code='catering_manager'
on conflict do nothing;

-- =========================================================
-- 02. MASTER DATA — PRODUITS / FOURNISSEURS
-- =========================================================
alter table public.products add column if not exists description text;
alter table public.products add column if not exists barcode text;
alter table public.products add column if not exists reorder_quantity numeric(14,3) not null default 0;
alter table public.products add column if not exists is_perishable boolean not null default false;
create unique index if not exists uq_products_school_barcode
  on public.products(school_id,barcode)
  where barcode is not null and btrim(barcode)<>'';
alter table public.suppliers add column if not exists is_active boolean not null default true;

-- =========================================================
-- 03. DEMANDES D'ACHAT
-- =========================================================
create table if not exists public.purchase_requests(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  request_number text not null,
  requested_by uuid not null references public.users(id) on delete restrict,
  requested_at timestamptz not null default now(),
  needed_by date,
  department text,
  reason text,
  status app.approval_status not null default 'draft',
  decided_by uuid references public.users(id) on delete set null,
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,request_number)
);

create table if not exists public.purchase_request_items(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.purchase_requests(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  estimated_unit_cost numeric(14,2) not null default 0 check(estimated_unit_cost>=0),
  notes text,
  unique(request_id,product_id)
);

-- =========================================================
-- 04. RÉCEPTIONS D'ACHAT
-- =========================================================
create table if not exists public.purchase_receipts(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete restrict,
  receipt_number text not null,
  location_id uuid not null references public.stock_locations(id) on delete restrict,
  received_at timestamptz not null default now(),
  status text not null default 'posted' check(status in ('draft','posted','cancelled')),
  received_by uuid references public.users(id) on delete set null,
  notes text,
  unique(school_id,receipt_number)
);

create table if not exists public.purchase_receipt_items(
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references public.purchase_receipts(id) on delete cascade,
  purchase_item_id uuid not null references public.purchase_items(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  unit_cost numeric(14,2) not null check(unit_cost>=0),
  stock_movement_id uuid unique references public.stock_movements(id) on delete restrict
);

-- =========================================================
-- 05. TRANSFERTS ENTRE MAGASINS
-- =========================================================
create table if not exists public.stock_transfers(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  transfer_number text not null,
  source_location_id uuid not null references public.stock_locations(id) on delete restrict,
  target_location_id uuid not null references public.stock_locations(id) on delete restrict,
  status text not null default 'draft' check(status in ('draft','submitted','approved','dispatched','received','cancelled')),
  transfer_date date not null default current_date,
  requested_by uuid references public.users(id) on delete set null,
  approved_by uuid references public.users(id) on delete set null,
  received_by uuid references public.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  unique(school_id,transfer_number),
  check(source_location_id<>target_location_id)
);

create table if not exists public.stock_transfer_items(
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.stock_transfers(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  dispatched_quantity numeric(14,3) not null default 0 check(dispatched_quantity>=0),
  received_quantity numeric(14,3) not null default 0 check(received_quantity>=0),
  unique(transfer_id,product_id)
);

-- =========================================================
-- 06. FACTURES FOURNISSEURS / PAIEMENTS
-- =========================================================
create table if not exists public.purchase_invoices(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  purchase_order_id uuid references public.purchase_orders(id) on delete set null,
  invoice_number text not null,
  invoice_date date not null default current_date,
  due_date date,
  amount numeric(14,2) not null check(amount>=0),
  paid_amount numeric(14,2) not null default 0 check(paid_amount>=0),
  status text not null default 'draft' check(status in ('draft','posted','partially_paid','paid','cancelled')),
  notes text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(school_id,supplier_id,invoice_number),
  check(paid_amount<=amount)
);

create table if not exists public.purchase_invoice_payments(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  purchase_invoice_id uuid not null references public.purchase_invoices(id) on delete restrict,
  cash_account_id uuid not null references public.cash_accounts(id) on delete restrict,
  amount numeric(14,2) not null check(amount>0),
  payment_date timestamptz not null default now(),
  reference text,
  created_by uuid references public.users(id) on delete set null,
  cash_transaction_id uuid unique references public.cash_transactions(id) on delete restrict
);

-- Liaison achats -> dépenses pour le suivi financier sans double écriture.
alter table public.purchase_orders add column if not exists source_request_id uuid references public.purchase_requests(id) on delete set null;
alter table public.purchase_orders add column if not exists default_location_id uuid references public.stock_locations(id) on delete set null;
alter table public.expenses add column if not exists purchase_order_id uuid references public.purchase_orders(id) on delete set null;
create index if not exists ix_expenses_purchase_order on public.expenses(purchase_order_id);

-- =========================================================
-- 07. INDEXES / TRIGGERS
-- =========================================================
create index if not exists ix_purchase_requests_school_status on public.purchase_requests(school_id,status,requested_at desc);
create index if not exists ix_purchase_request_items_request on public.purchase_request_items(request_id);
create index if not exists ix_purchase_receipts_school_date on public.purchase_receipts(school_id,received_at desc);
create index if not exists ix_purchase_receipt_items_receipt on public.purchase_receipt_items(receipt_id);
create index if not exists ix_stock_transfers_school_status on public.stock_transfers(school_id,status,transfer_date desc);
create index if not exists ix_stock_transfer_items_transfer on public.stock_transfer_items(transfer_id);
create index if not exists ix_purchase_invoices_school_status on public.purchase_invoices(school_id,status,invoice_date desc);
create index if not exists ix_purchase_invoice_payments_invoice on public.purchase_invoice_payments(purchase_invoice_id,payment_date desc);
create index if not exists ix_stock_movements_product_location_date on public.stock_movements(product_id,location_id,movement_date desc);
create index if not exists ix_stock_balances_low on public.stock_balances(product_id,location_id,quantity);

create or replace function app.validate_stock_product_location()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare ps uuid; ls uuid;
begin
  select school_id into ps from public.products where id=new.product_id;
  select school_id into ls from public.stock_locations where id=new.location_id;
  if ps is null or ls is null or ps<>ls or ps<>new.school_id then
    raise exception 'STOCK_CROSS_SCHOOL';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_stock_product_location on public.stock_movements;
create trigger trg_validate_stock_product_location
before insert or update on public.stock_movements
for each row execute function app.validate_stock_product_location();

create or replace function app.apply_stock_movement()
returns trigger language plpgsql security definer set search_path = '' as $$
declare delta numeric; new_balance numeric;
begin
  if new.movement_type in ('purchase','return','production_in','adjustment') then
    delta:=new.quantity;
  else
    delta:=-new.quantity;
  end if;
  insert into public.stock_balances(product_id,location_id,quantity,updated_at)
  values(new.product_id,new.location_id,delta,now())
  on conflict(product_id,location_id) do update
    set quantity=public.stock_balances.quantity+excluded.quantity,updated_at=now()
  returning quantity into new_balance;
  if new_balance<0 then raise exception 'NEGATIVE_STOCK_NOT_ALLOWED'; end if;
  return new;
end $$;

-- Le trigger existait déjà dans 1A.1 ; on le remplace avec la table des nouveaux types.
drop trigger if exists trg_apply_stock_movement on public.stock_movements;
create trigger trg_apply_stock_movement after insert on public.stock_movements
for each row execute function app.apply_stock_movement();

create or replace function app.touch_stock_purchase_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists trg_purchase_request_updated_at on public.purchase_requests;
create trigger trg_purchase_request_updated_at before update on public.purchase_requests
for each row execute function app.touch_stock_purchase_updated_at();

-- =========================================================
-- 08. RLS : LECTURE STAFF + ÉCRITURES VIA RPC
-- =========================================================
alter table public.purchase_requests enable row level security;
alter table public.purchase_request_items enable row level security;
alter table public.purchase_receipts enable row level security;
alter table public.purchase_receipt_items enable row level security;
alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_items enable row level security;
alter table public.purchase_invoices enable row level security;
alter table public.purchase_invoice_payments enable row level security;

-- Tables existantes : on remplace les policies permissives des workflows baseline.
do $$
declare r record;
begin
  for r in select policyname,tablename from pg_policies where schemaname='public' and tablename in
    ('stock_categories','stock_locations','products','stock_balances','stock_movements','purchase_orders','purchase_items','stock_inventories','stock_inventory_items','suppliers') loop
      execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename);
  end loop;
end $$;

create policy stock_categories_select_step19 on public.stock_categories for select using(app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.is_super_admin());
create policy stock_locations_select_step19 on public.stock_locations for select using(app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.has_permission('inventory.manage',school_id) or app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.is_super_admin());
create policy products_select_step19 on public.products for select using(app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.is_super_admin());
create policy stock_balances_select_step19 on public.stock_balances for select using(exists(select 1 from public.products p join public.stock_locations l on l.id=location_id where p.id=product_id and p.school_id=l.school_id and (app.has_permission('stock.view',p.school_id) or app.has_permission('stock.manage',p.school_id) or app.has_permission('inventory.manage',p.school_id) or app.is_super_admin())));
create policy stock_movements_select_step19 on public.stock_movements for select using(app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.has_permission('inventory.manage',school_id) or app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.is_super_admin());
create policy purchase_orders_select_step19 on public.purchase_orders for select using(app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.is_super_admin());
create policy purchase_items_select_step19 on public.purchase_items for select using(exists(select 1 from public.purchase_orders po where po.id=purchase_order_id and (app.has_permission('purchases.view',po.school_id) or app.has_permission('purchases.manage',po.school_id) or app.has_permission('stock.view',po.school_id) or app.has_permission('stock.manage',po.school_id) or app.is_super_admin())));
create policy stock_inventories_select_step19 on public.stock_inventories for select using(app.has_permission('inventory.manage',school_id) or app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.is_super_admin());
create policy stock_inventory_items_select_step19 on public.stock_inventory_items for select using(exists(select 1 from public.stock_inventories si where si.id=inventory_id and (app.has_permission('inventory.manage',si.school_id) or app.has_permission('stock.view',si.school_id) or app.has_permission('stock.manage',si.school_id) or app.is_super_admin())));
create policy suppliers_select_step19 on public.suppliers for select using(app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.has_permission('finance.view',school_id) or app.is_super_admin());

create policy purchase_requests_select_step19 on public.purchase_requests for select using(app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin());
create policy purchase_request_items_select_step19 on public.purchase_request_items for select using(exists(select 1 from public.purchase_requests r where r.id=request_id and (app.has_permission('purchases.view',r.school_id) or app.has_permission('purchases.manage',r.school_id) or app.has_role_code('direction',r.school_id) or app.has_role_code('founder',r.school_id) or app.is_super_admin())));
create policy purchase_receipts_select_step19 on public.purchase_receipts for select using(app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.is_super_admin());
create policy purchase_receipt_items_select_step19 on public.purchase_receipt_items for select using(exists(select 1 from public.purchase_receipts r where r.id=receipt_id and (app.has_permission('purchases.view',r.school_id) or app.has_permission('purchases.manage',r.school_id) or app.has_permission('stock.view',r.school_id) or app.has_permission('stock.manage',r.school_id) or app.is_super_admin())));
create policy stock_transfers_select_step19 on public.stock_transfers for select using(app.has_permission('stock.view',school_id) or app.has_permission('stock.manage',school_id) or app.is_super_admin());
create policy stock_transfer_items_select_step19 on public.stock_transfer_items for select using(exists(select 1 from public.stock_transfers t where t.id=transfer_id and (app.has_permission('stock.view',t.school_id) or app.has_permission('stock.manage',t.school_id) or app.is_super_admin())));
create policy purchase_invoices_select_step19 on public.purchase_invoices for select using(app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.has_permission('finance.view',school_id) or app.has_permission('finance.manage',school_id) or app.is_super_admin());
create policy purchase_invoice_payments_select_step19 on public.purchase_invoice_payments for select using(app.has_permission('purchases.view',school_id) or app.has_permission('purchases.manage',school_id) or app.has_permission('finance.view',school_id) or app.has_permission('cash.manage',school_id) or app.is_super_admin());

-- Aucune mutation directe côté authenticated sur les tables sensibles.
do $$
declare t text;
begin
  foreach t in array array['stock_categories','stock_locations','products','stock_movements','purchase_orders','purchase_items','stock_inventories','stock_inventory_items','suppliers','purchase_requests','purchase_request_items','purchase_receipts','purchase_receipt_items','stock_transfers','stock_transfer_items','purchase_invoices','purchase_invoice_payments'] loop
    execute format('revoke insert, update, delete on public.%I from authenticated',t);
  end loop;
end $$;

-- =========================================================
-- 09. RPC — FOURNISSEURS / PRODUITS / EMPLACEMENTS
-- =========================================================
create or replace function public.create_supplier(p_code text,p_name text,p_contact_name text default null,p_phone text default null,p_email text default null,p_address text default null,p_tax_id text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; s uuid;
begin
  select school_id into s from public.users where id=auth.uid();
  if s is null or not (app.has_permission('purchases.manage',s) or app.is_super_admin()) then raise exception 'PURCHASE_SUPPLIER_FORBIDDEN'; end if;
  insert into public.suppliers(school_id,code,name,contact_name,phone,email,address,tax_id,is_active)
  values(s,trim(p_code),trim(p_name),nullif(trim(p_contact_name),''),nullif(trim(p_phone),''),nullif(trim(p_email),''),nullif(trim(p_address),''),nullif(trim(p_tax_id),''),true)
  returning id into sid;
  return sid;
end $$;

grant execute on function public.create_supplier(text,text,text,text,text,text,text) to authenticated;

create or replace function public.create_stock_category(p_code text,p_name text)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; cid uuid;
begin
  select school_id into sid from public.users where id=auth.uid();
  if sid is null or not (app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'STOCK_CATEGORY_FORBIDDEN'; end if;
  insert into public.stock_categories(school_id,code,name) values(sid,trim(p_code),trim(p_name)) returning id into cid;
  return cid;
end $$;
grant execute on function public.create_stock_category(text,text) to authenticated;

create or replace function public.create_stock_location(p_name text,p_location_type text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; lid uuid;
begin
  select school_id into sid from public.users where id=auth.uid();
  if sid is null or not (app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'STOCK_LOCATION_FORBIDDEN'; end if;
  insert into public.stock_locations(school_id,name,location_type) values(sid,trim(p_name),nullif(trim(p_location_type),'')) returning id into lid;
  return lid;
end $$;
grant execute on function public.create_stock_location(text,text) to authenticated;

create or replace function public.create_product(p_sku text,p_name text,p_category_id uuid,p_unit text,p_minimum_stock numeric default 0,p_maximum_stock numeric default null,p_unit_cost numeric default 0,p_barcode text default null,p_description text default null,p_reorder_quantity numeric default 0,p_is_perishable boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; pid uuid; cat_school uuid;
begin
  select school_id into sid from public.users where id=auth.uid();
  if sid is null or not (app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'STOCK_PRODUCT_FORBIDDEN'; end if;
  if p_minimum_stock<0 or p_reorder_quantity<0 or p_unit_cost<0 or (p_maximum_stock is not null and p_maximum_stock<p_minimum_stock) then raise exception 'STOCK_PRODUCT_LIMITS_INVALID'; end if;
  if p_category_id is not null then select school_id into cat_school from public.stock_categories where id=p_category_id; if cat_school<>sid then raise exception 'STOCK_CATEGORY_CROSS_SCHOOL'; end if; end if;
  insert into public.products(school_id,sku,name,category_id,unit,minimum_stock,maximum_stock,unit_cost,is_active,barcode,description,reorder_quantity,is_perishable)
  values(sid,trim(p_sku),trim(p_name),p_category_id,trim(p_unit),p_minimum_stock,p_maximum_stock,p_unit_cost,true,nullif(trim(p_barcode),''),nullif(trim(p_description),''),p_reorder_quantity,p_is_perishable)
  returning id into pid;
  return pid;
end $$;
grant execute on function public.create_product(text,text,uuid,text,numeric,numeric,numeric,text,text,numeric,boolean) to authenticated;

-- =========================================================
-- 10. RPC — MOUVEMENTS / INVENTAIRES
-- =========================================================
create or replace function public.record_stock_movement(p_product_id uuid,p_location_id uuid,p_movement_type app.stock_movement_type,p_quantity numeric,p_unit_cost numeric default null,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; ps uuid; ls uuid; mid uuid; balance numeric;
begin
  select school_id into ps from public.products where id=p_product_id;
  select school_id into ls from public.stock_locations where id=p_location_id;
  if ps is null or ls is null or ps<>ls then raise exception 'STOCK_CONTEXT_INVALID'; end if;
  sid:=ps;
  if not (app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'STOCK_MOVEMENT_FORBIDDEN'; end if;
  if p_quantity<=0 or (p_unit_cost is not null and p_unit_cost<0) then raise exception 'STOCK_MOVEMENT_INVALID'; end if;
  if p_movement_type not in ('purchase','sale','issue','return','adjustment','loss','transfer','production_in','production_out') then raise exception 'STOCK_MOVEMENT_TYPE_INVALID'; end if;
  insert into public.stock_movements(school_id,product_id,location_id,movement_type,quantity,unit_cost,created_by,notes)
  values(sid,p_product_id,p_location_id,p_movement_type,p_quantity,p_unit_cost,auth.uid(),nullif(trim(p_notes),''))
  returning id into mid;
  select quantity into balance from public.stock_balances where product_id=p_product_id and location_id=p_location_id;
  if balance<0 then raise exception 'NEGATIVE_STOCK_NOT_ALLOWED'; end if;
  return mid;
end $$;
grant execute on function public.record_stock_movement(uuid,uuid,app.stock_movement_type,numeric,numeric,text) to authenticated;

create or replace function public.create_stock_inventory(p_location_id uuid,p_inventory_date date,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; iid uuid; r record;
begin
  select school_id into sid from public.stock_locations where id=p_location_id;
  if sid is null then raise exception 'INVENTORY_LOCATION_INVALID'; end if;
  if not (app.has_permission('inventory.manage',sid) or app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'INVENTORY_FORBIDDEN'; end if;
  insert into public.stock_inventories(school_id,location_id,inventory_date,status,performed_by,notes)
  values(sid,p_location_id,p_inventory_date,'draft',auth.uid(),nullif(trim(p_notes),''))
  returning id into iid;
  for r in select p.id product_id,coalesce(sb.quantity,0) quantity
    from public.products p
    left join public.stock_balances sb on sb.product_id=p.id and sb.location_id=p_location_id
    where p.school_id=sid and p.is_active=true
  loop
    insert into public.stock_inventory_items(inventory_id,product_id,system_quantity,counted_quantity)
    values(iid,r.product_id,r.quantity,r.quantity);
  end loop;
  return iid;
end $$;
grant execute on function public.create_stock_inventory(uuid,date,text) to authenticated;

create or replace function public.set_stock_inventory_count(p_inventory_item_id uuid,p_counted_quantity numeric)
returns void language plpgsql security definer set search_path='' as $$
declare sid uuid; status text;
begin
  select si.school_id,si.status into sid,status
  from public.stock_inventory_items sii join public.stock_inventories si on si.id=sii.inventory_id
  where sii.id=p_inventory_item_id;
  if sid is null or status<>'draft' then raise exception 'INVENTORY_ITEM_LOCKED'; end if;
  if not (app.has_permission('inventory.manage',sid) or app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'INVENTORY_FORBIDDEN'; end if;
  if p_counted_quantity<0 then raise exception 'INVENTORY_COUNT_INVALID'; end if;
  update public.stock_inventory_items set counted_quantity=p_counted_quantity where id=p_inventory_item_id;
end $$;
grant execute on function public.set_stock_inventory_count(uuid,numeric) to authenticated;

create or replace function public.finalize_stock_inventory(p_inventory_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare sid uuid; st text; r record;
begin
  select school_id,status into sid,st from public.stock_inventories where id=p_inventory_id for update;
  if sid is null or st<>'draft' then raise exception 'INVENTORY_NOT_DRAFT'; end if;
  if not (app.has_permission('inventory.manage',sid) or app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'INVENTORY_FORBIDDEN'; end if;
  for r in select sii.*,si.location_id from public.stock_inventory_items sii join public.stock_inventories si on si.id=sii.inventory_id where sii.inventory_id=p_inventory_id loop
    if r.difference>0 then
      insert into public.stock_movements(school_id,product_id,location_id,movement_type,quantity,unit_cost,reference_type,reference_id,created_by,notes)
      values(sid,r.product_id,r.location_id,'adjustment',r.difference,null,'inventory',p_inventory_id,auth.uid(),'Ajustement positif inventaire');
    elsif r.difference<0 then
      insert into public.stock_movements(school_id,product_id,location_id,movement_type,quantity,unit_cost,reference_type,reference_id,created_by,notes)
      values(sid,r.product_id,r.location_id,'loss',abs(r.difference),null,'inventory',p_inventory_id,auth.uid(),'Ajustement négatif inventaire');
    end if;
  end loop;
  update public.stock_inventories set status='finalized' where id=p_inventory_id;
end $$;
grant execute on function public.finalize_stock_inventory(uuid) to authenticated;

-- =========================================================
-- 11. RPC — DEMANDE / COMMANDE / APPROBATION
-- =========================================================
create or replace function public.create_purchase_request(p_request_number text,p_needed_by date,p_department text,p_reason text,p_items jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; rid uuid; item jsonb; ps uuid; qty numeric; cost numeric;
begin
  select school_id into sid from public.users where id=auth.uid();
  if sid is null or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_REQUEST_FORBIDDEN'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'PURCHASE_REQUEST_EMPTY'; end if;
  insert into public.purchase_requests(school_id,request_number,requested_by,needed_by,department,reason,status)
  values(sid,trim(p_request_number),auth.uid(),p_needed_by,nullif(trim(p_department),''),nullif(trim(p_reason),''),'draft') returning id into rid;
  for item in select value from jsonb_array_elements(p_items) loop
    ps:=(item->>'product_id')::uuid; qty:=(item->>'quantity')::numeric; cost:=coalesce((item->>'estimated_unit_cost')::numeric,0);
    if qty<=0 or cost<0 then raise exception 'PURCHASE_REQUEST_ITEM_INVALID'; end if;
    if not exists(select 1 from public.products where id=ps and school_id=sid and is_active) then raise exception 'PURCHASE_PRODUCT_INVALID'; end if;
    insert into public.purchase_request_items(request_id,product_id,quantity,estimated_unit_cost,notes) values(rid,ps,qty,cost,nullif(item->>'notes',''));
  end loop;
  return rid;
end $$;
grant execute on function public.create_purchase_request(text,date,text,text,jsonb) to authenticated;

create or replace function public.decide_purchase_request(p_request_id uuid,p_decision app.approval_status,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
  select school_id into sid from public.purchase_requests where id=p_request_id;
  if sid is null or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_REQUEST_FORBIDDEN'; end if;
  if p_decision not in ('approved','rejected','cancelled') then raise exception 'PURCHASE_REQUEST_DECISION_INVALID'; end if;
  update public.purchase_requests set status=p_decision,decided_by=auth.uid(),decided_at=now(),decision_note=nullif(trim(p_note),'') where id=p_request_id and status in ('draft','submitted');
end $$;
grant execute on function public.decide_purchase_request(uuid,app.approval_status,text) to authenticated;

create or replace function public.submit_purchase_request(p_request_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
  select school_id into sid from public.purchase_requests where id=p_request_id;
  if sid is null or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_REQUEST_FORBIDDEN'; end if;
  update public.purchase_requests set status='submitted' where id=p_request_id and status='draft';
end $$;
grant execute on function public.submit_purchase_request(uuid) to authenticated;

create or replace function public.create_purchase_order(p_order_number text,p_supplier_id uuid,p_order_date date,p_expected_date date,p_default_location_id uuid,p_request_id uuid,p_items jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; ss uuid; ls uuid; rs uuid; poid uuid; item jsonb; pid uuid; qty numeric; cost numeric; total numeric:=0; req_status app.approval_status;
begin
  select school_id into sid from public.users where id=auth.uid();
  select school_id into ss from public.suppliers where id=p_supplier_id and is_active=true;
  if sid is null or ss<>sid or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_ORDER_FORBIDDEN'; end if;
  if p_default_location_id is not null then select school_id into ls from public.stock_locations where id=p_default_location_id; if ls<>sid then raise exception 'PURCHASE_LOCATION_INVALID'; end if; end if;
  if p_request_id is not null then select school_id,status into rs,req_status from public.purchase_requests where id=p_request_id; if rs<>sid or req_status<>'approved' then raise exception 'PURCHASE_REQUEST_NOT_APPROVED'; end if; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'PURCHASE_ORDER_EMPTY'; end if;
  insert into public.purchase_orders(school_id,order_number,supplier_id,order_date,expected_date,status,created_by)
  values(sid,trim(p_order_number),p_supplier_id,p_order_date,p_expected_date,'draft',auth.uid()) returning id into poid;
  update public.purchase_orders set source_request_id=p_request_id,default_location_id=p_default_location_id where id=poid;
  for item in select value from jsonb_array_elements(p_items) loop
    pid:=(item->>'product_id')::uuid; qty:=(item->>'quantity')::numeric; cost:=(item->>'unit_cost')::numeric;
    if qty<=0 or cost<0 then raise exception 'PURCHASE_ORDER_ITEM_INVALID'; end if;
    if not exists(select 1 from public.products where id=pid and school_id=sid and is_active) then raise exception 'PURCHASE_PRODUCT_INVALID'; end if;
    insert into public.purchase_items(purchase_order_id,product_id,quantity,unit_cost,received_quantity) values(poid,pid,qty,cost,0);
    total:=total+(qty*cost);
  end loop;
  update public.purchase_orders set subtotal=total,total=total where id=poid;
  return poid;
end $$;
grant execute on function public.create_purchase_order(text,uuid,date,date,uuid,uuid,jsonb) to authenticated;

create or replace function public.set_purchase_order_status(p_purchase_order_id uuid,p_status app.approval_status)
returns void language plpgsql security definer set search_path='' as $$
declare sid uuid; old_status app.approval_status;
begin
  select school_id,status into sid,old_status from public.purchase_orders where id=p_purchase_order_id for update;
  if sid is null or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_ORDER_FORBIDDEN'; end if;
  if p_status not in ('submitted','approved','rejected','cancelled') then raise exception 'PURCHASE_ORDER_STATUS_INVALID'; end if;
  if p_status='approved' and not exists(select 1 from public.purchase_items where purchase_order_id=p_purchase_order_id) then raise exception 'PURCHASE_ORDER_EMPTY'; end if;
  update public.purchase_orders set status=p_status where id=p_purchase_order_id;
end $$;
grant execute on function public.set_purchase_order_status(uuid,app.approval_status) to authenticated;

-- =========================================================
-- 12. RPC — RÉCEPTION / TRANSFERT
-- =========================================================
create or replace function public.receive_purchase_order(p_purchase_order_id uuid,p_location_id uuid,p_receipt_number text,p_received_at timestamptz,p_items jsonb,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; locschool uuid; status app.approval_status; rid uuid; item jsonb; pi_id uuid; qty numeric; available numeric; prod uuid; movement uuid; all_received boolean;
begin
  select school_id,status into sid,status from public.purchase_orders where id=p_purchase_order_id for update;
  select school_id into locschool from public.stock_locations where id=p_location_id;
  if sid is null or locschool<>sid or not (app.has_permission('purchases.manage',sid) or app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_RECEIPT_FORBIDDEN'; end if;
  if status not in ('approved','submitted') then raise exception 'PURCHASE_ORDER_NOT_RECEIVABLE'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'PURCHASE_RECEIPT_EMPTY'; end if;
  insert into public.purchase_receipts(school_id,purchase_order_id,receipt_number,location_id,received_at,status,received_by,notes)
  values(sid,p_purchase_order_id,trim(p_receipt_number),p_location_id,p_received_at,'posted',auth.uid(),nullif(trim(p_notes),'')) returning id into rid;
  for item in select value from jsonb_array_elements(p_items) loop
    pi_id:=(item->>'purchase_item_id')::uuid; qty:=(item->>'quantity')::numeric;
    select product_id,quantity-received_quantity into prod,available from public.purchase_items where id=pi_id and purchase_order_id=p_purchase_order_id for update;
    if prod is null or qty<=0 or qty>available then raise exception 'PURCHASE_RECEIPT_QUANTITY_INVALID'; end if;
    insert into public.stock_movements(school_id,product_id,location_id,movement_type,quantity,unit_cost,reference_type,reference_id,created_by,notes)
    select sid,prod,p_location_id,'purchase',qty,unit_cost,'purchase_receipt',rid,auth.uid(),'Réception achat'
    from public.purchase_items where id=pi_id;
    select id into movement from public.stock_movements where reference_type='purchase_receipt' and reference_id=rid and product_id=prod order by movement_date desc limit 1;
    insert into public.purchase_receipt_items(receipt_id,purchase_item_id,product_id,quantity,unit_cost,stock_movement_id)
    select rid,pi_id,prod,qty,unit_cost,movement from public.purchase_items where id=pi_id;
    update public.purchase_items set received_quantity=received_quantity+qty where id=pi_id;
  end loop;
  select not exists(select 1 from public.purchase_items where purchase_order_id=p_purchase_order_id and received_quantity<quantity) into all_received;
  update public.purchase_orders set status=case when all_received then 'approved' else 'submitted' end where id=p_purchase_order_id;
  return rid;
end $$;
grant execute on function public.receive_purchase_order(uuid,uuid,text,timestamptz,jsonb,text) to authenticated;

create or replace function public.create_stock_transfer(p_transfer_number text,p_source_location_id uuid,p_target_location_id uuid,p_transfer_date date,p_items jsonb,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; s1 uuid; s2 uuid; tid uuid; item jsonb; pid uuid; qty numeric;
begin
  select school_id into s1 from public.stock_locations where id=p_source_location_id;
  select school_id into s2 from public.stock_locations where id=p_target_location_id;
  if s1 is null or s1<>s2 or p_source_location_id=p_target_location_id then raise exception 'STOCK_TRANSFER_CONTEXT_INVALID'; end if;
  sid:=s1;
  if not (app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'STOCK_TRANSFER_FORBIDDEN'; end if;
  insert into public.stock_transfers(school_id,transfer_number,source_location_id,target_location_id,status,transfer_date,requested_by,notes)
  values(sid,trim(p_transfer_number),p_source_location_id,p_target_location_id,'draft',p_transfer_date,auth.uid(),nullif(trim(p_notes),'')) returning id into tid;
  for item in select value from jsonb_array_elements(p_items) loop
    pid:=(item->>'product_id')::uuid; qty:=(item->>'quantity')::numeric;
    if qty<=0 or not exists(select 1 from public.products where id=pid and school_id=sid and is_active) then raise exception 'STOCK_TRANSFER_ITEM_INVALID'; end if;
    insert into public.stock_transfer_items(transfer_id,product_id,quantity) values(tid,pid,qty);
  end loop;
  return tid;
end $$;
grant execute on function public.create_stock_transfer(text,uuid,uuid,date,jsonb,text) to authenticated;

create or replace function public.complete_stock_transfer(p_transfer_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare sid uuid; status text; source uuid; target uuid; r record; balance numeric;
begin
  select school_id,status,source_location_id,target_location_id into sid,status,source,target from public.stock_transfers where id=p_transfer_id for update;
  if sid is null or not (app.has_permission('stock.manage',sid) or app.is_super_admin()) then raise exception 'STOCK_TRANSFER_FORBIDDEN'; end if;
  if status not in ('draft','approved','submitted') then raise exception 'STOCK_TRANSFER_STATUS_INVALID'; end if;
  for r in select * from public.stock_transfer_items where transfer_id=p_transfer_id loop
    select quantity into balance from public.stock_balances where product_id=r.product_id and location_id=source for update;
    if coalesce(balance,0)<r.quantity then raise exception 'STOCK_TRANSFER_INSUFFICIENT'; end if;
    insert into public.stock_movements(school_id,product_id,location_id,movement_type,quantity,reference_type,reference_id,created_by,notes)
      values(sid,r.product_id,source,'transfer',r.quantity,'stock_transfer',p_transfer_id,auth.uid(),'Transfert sortant');
    insert into public.stock_movements(school_id,product_id,location_id,movement_type,quantity,reference_type,reference_id,created_by,notes)
      values(sid,r.product_id,target,'return',r.quantity,'stock_transfer',p_transfer_id,auth.uid(),'Transfert entrant');
    update public.stock_transfer_items set dispatched_quantity=quantity,received_quantity=quantity where id=r.id;
  end loop;
  update public.stock_transfers set status='received',approved_by=coalesce(approved_by,auth.uid()),received_by=auth.uid() where id=p_transfer_id;
end $$;
grant execute on function public.complete_stock_transfer(uuid) to authenticated;



create or replace function public.add_purchase_request_item(p_request_id uuid,p_product_id uuid,p_quantity numeric,p_estimated_unit_cost numeric default 0,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; ps uuid; st app.approval_status; iid uuid;
begin
  select school_id,status into sid,st from public.purchase_requests where id=p_request_id for update;
  select school_id into ps from public.products where id=p_product_id and is_active;
  if sid is null or ps<>sid or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_REQUEST_FORBIDDEN'; end if;
  if st<>'draft' or p_quantity<=0 or p_estimated_unit_cost<0 then raise exception 'PURCHASE_REQUEST_ITEM_INVALID'; end if;
  insert into public.purchase_request_items(request_id,product_id,quantity,estimated_unit_cost,notes)
  values(p_request_id,p_product_id,p_quantity,p_estimated_unit_cost,nullif(trim(p_notes),''))
  on conflict(request_id,product_id) do update set quantity=excluded.quantity,estimated_unit_cost=excluded.estimated_unit_cost,notes=excluded.notes
  returning id into iid;
  return iid;
end $$;
grant execute on function public.add_purchase_request_item(uuid,uuid,numeric,numeric,text) to authenticated;

create or replace function public.add_purchase_order_item(p_purchase_order_id uuid,p_product_id uuid,p_quantity numeric,p_unit_cost numeric)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; ps uuid; st app.approval_status; iid uuid;
begin
  select school_id,status into sid,st from public.purchase_orders where id=p_purchase_order_id for update;
  select school_id into ps from public.products where id=p_product_id and is_active;
  if sid is null or ps<>sid or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_ORDER_FORBIDDEN'; end if;
  if st<>'draft' or p_quantity<=0 or p_unit_cost<0 then raise exception 'PURCHASE_ORDER_ITEM_INVALID'; end if;
  insert into public.purchase_items(purchase_order_id,product_id,quantity,unit_cost,received_quantity)
  values(p_purchase_order_id,p_product_id,p_quantity,p_unit_cost,0)
  on conflict do nothing returning id into iid;
  if iid is null then
    update public.purchase_items set quantity=p_quantity,unit_cost=p_unit_cost where purchase_order_id=p_purchase_order_id and product_id=p_product_id returning id into iid;
  end if;
  update public.purchase_orders po set subtotal=(select coalesce(sum(pi.line_total),0) from public.purchase_items pi where pi.purchase_order_id=po.id),total=(select coalesce(sum(pi.line_total),0) from public.purchase_items pi where pi.purchase_order_id=po.id) where po.id=p_purchase_order_id;
  return iid;
end $$;
grant execute on function public.add_purchase_order_item(uuid,uuid,numeric,numeric) to authenticated;

-- =========================================================
-- 13. RPC — FACTURES FOURNISSEURS / PAIEMENTS
-- =========================================================
create or replace function public.create_purchase_invoice(p_supplier_id uuid,p_purchase_order_id uuid,p_invoice_number text,p_invoice_date date,p_due_date date,p_amount numeric,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; ss uuid; po_school uuid; iid uuid;
begin
  select school_id into sid from public.users where id=auth.uid();
  select school_id into ss from public.suppliers where id=p_supplier_id and is_active;
  if p_purchase_order_id is not null then select school_id into po_school from public.purchase_orders where id=p_purchase_order_id; end if;
  if sid is null or ss<>sid or (p_purchase_order_id is not null and po_school<>sid) or not (app.has_permission('purchases.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_INVOICE_FORBIDDEN'; end if;
  if p_purchase_order_id is not null and not exists(select 1 from public.purchase_orders where id=p_purchase_order_id and supplier_id=p_supplier_id) then raise exception 'PURCHASE_INVOICE_SUPPLIER_MISMATCH'; end if;
  if p_amount<=0 then raise exception 'PURCHASE_INVOICE_AMOUNT_INVALID'; end if;
  insert into public.purchase_invoices(school_id,supplier_id,purchase_order_id,invoice_number,invoice_date,due_date,amount,status,created_by,notes)
  values(sid,p_supplier_id,p_purchase_order_id,trim(p_invoice_number),p_invoice_date,p_due_date,p_amount,'posted',auth.uid(),nullif(trim(p_notes),'')) returning id into iid;
  return iid;
end $$;
grant execute on function public.create_purchase_invoice(uuid,uuid,text,date,date,numeric,text) to authenticated;

create or replace function public.pay_purchase_invoice(p_purchase_invoice_id uuid,p_cash_account_id uuid,p_amount numeric,p_payment_date timestamptz,p_reference text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; invoice_amount numeric; paid numeric; cash_school uuid; pid uuid; tx uuid; status text;
begin
  select school_id,amount,paid_amount,status into sid,invoice_amount,paid,status from public.purchase_invoices where id=p_purchase_invoice_id for update;
  select school_id into cash_school from public.cash_accounts where id=p_cash_account_id;
  if sid is null or cash_school<>sid or not (app.has_permission('cash.manage',sid) or app.has_permission('finance.manage',sid) or app.is_super_admin()) then raise exception 'PURCHASE_PAYMENT_FORBIDDEN'; end if;
  if status='cancelled' or p_amount<=0 or p_amount>(invoice_amount-paid) then raise exception 'PURCHASE_PAYMENT_AMOUNT_INVALID'; end if;
  insert into public.cash_transactions(school_id,cash_account_id,transaction_type,amount,transaction_date,reference_type,reference_id,description,created_by)
  values(sid,p_cash_account_id,'expense',p_amount,p_payment_date,'purchase_invoice',p_purchase_invoice_id,'Paiement facture fournisseur',auth.uid()) returning id into tx;
  insert into public.purchase_invoice_payments(school_id,purchase_invoice_id,cash_account_id,amount,payment_date,reference,created_by,cash_transaction_id)
  values(sid,p_purchase_invoice_id,p_cash_account_id,p_amount,p_payment_date,nullif(trim(p_reference),''),auth.uid(),tx) returning id into pid;
  update public.purchase_invoices set paid_amount=paid_amount+p_amount,status=case when paid_amount+p_amount>=amount then 'paid' else 'partially_paid' end where id=p_purchase_invoice_id;
  return pid;
end $$;
grant execute on function public.pay_purchase_invoice(uuid,uuid,numeric,timestamptz,text) to authenticated;

-- =========================================================
-- 14. VUES DE PILOTAGE
-- =========================================================
create or replace view public.stock_low_stock_v with (security_invoker=true) as
select p.school_id,p.id product_id,p.sku,p.name,p.unit,p.minimum_stock,p.maximum_stock,p.reorder_quantity,l.id location_id,l.name location_name,b.quantity
from public.products p
join public.stock_balances b on b.product_id=p.id
join public.stock_locations l on l.id=b.location_id
where p.is_active=true and b.quantity<=p.minimum_stock;

create or replace view public.purchase_order_status_v with (security_invoker=true) as
select po.id,po.school_id,po.order_number,po.supplier_id,s.name supplier_name,po.order_date,po.expected_date,po.status,
       po.total,coalesce(sum(pi.received_quantity*pi.unit_cost),0)::numeric(14,2) received_value,
       coalesce(sum((pi.quantity-pi.received_quantity)*pi.unit_cost),0)::numeric(14,2) remaining_value
from public.purchase_orders po
join public.suppliers s on s.id=po.supplier_id
left join public.purchase_items pi on pi.purchase_order_id=po.id
group by po.id,s.name;

-- Les vues récupèrent les RLS des tables sous-jacentes via security invoker en PG récent.
revoke all on public.stock_low_stock_v, public.purchase_order_status_v from anon;
grant select on public.stock_low_stock_v, public.purchase_order_status_v to authenticated;

-- Les RPC sensibles ne sont pas exécutables anonymement ni via PUBLIC.
revoke execute on function public.create_supplier(text,text,text,text,text,text,text) from public;
revoke execute on function public.create_stock_category(text,text) from public;
revoke execute on function public.create_stock_location(text,text) from public;
revoke execute on function public.create_product(text,text,uuid,text,numeric,numeric,numeric,text,text,numeric,boolean) from public;
revoke execute on function public.record_stock_movement(uuid,uuid,app.stock_movement_type,numeric,numeric,text) from public;
revoke execute on function public.create_stock_inventory(uuid,date,text) from public;
revoke execute on function public.set_stock_inventory_count(uuid,numeric) from public;
revoke execute on function public.finalize_stock_inventory(uuid) from public;
revoke execute on function public.create_purchase_request(text,date,text,text,jsonb) from public;
revoke execute on function public.add_purchase_request_item(uuid,uuid,numeric,numeric,text) from public;
revoke execute on function public.submit_purchase_request(uuid) from public;
revoke execute on function public.decide_purchase_request(uuid,app.approval_status,text) from public;
revoke execute on function public.create_purchase_order(text,uuid,date,date,uuid,uuid,jsonb) from public;
revoke execute on function public.add_purchase_order_item(uuid,uuid,numeric,numeric) from public;
revoke execute on function public.set_purchase_order_status(uuid,app.approval_status) from public;
revoke execute on function public.receive_purchase_order(uuid,uuid,text,timestamptz,jsonb,text) from public;
revoke execute on function public.create_stock_transfer(text,uuid,uuid,date,jsonb,text) from public;
revoke execute on function public.complete_stock_transfer(uuid) from public;
revoke execute on function public.create_purchase_invoice(uuid,uuid,text,date,date,numeric,text) from public;
revoke execute on function public.pay_purchase_invoice(uuid,uuid,numeric,timestamptz,text) from public;

commit;
