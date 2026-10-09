-- SIGIA-AMINE — Migration 030
-- Étape 22 : Agriculture / Élevage / AGR
-- Renforcement opérationnel des activités économiques sans remplacer les tables
-- historiques : agriculture, élevage et AGR restent paramétrables et reliés
-- aux stocks/achats et, lorsque nécessaire, aux écritures financières.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- 01. PERMISSIONS
-- =========================================================
insert into public.permissions(code,name,module,action,description) values
  ('agriculture.view','Consulter agriculture','agriculture','view','Consulter campagnes, productions et indicateurs agricoles'),
  ('livestock.view','Consulter élevage','livestock','view','Consulter cheptel, événements et indicateurs élevage')
on conflict(code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('agriculture.view','agriculture.manage','stock.manage','reports.view','finance.view')
where r.code='agriculture_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('livestock.view','livestock.manage','stock.manage','reports.view','finance.view')
where r.code='livestock_manager' on conflict do nothing;

-- Fondateur/super-admin : déjà global dans le socle, on resécurise les permissions métier.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in
('agriculture.view','livestock.view')
where r.code in ('founder','super_admin') on conflict do nothing;

-- =========================================================
-- 02. EXTENSIONS DES TABLES EXISTANTES
-- =========================================================
alter table public.economic_activities add column if not exists description text;
alter table public.economic_activities add column if not exists start_date date;
alter table public.economic_activities add column if not exists end_date date;
alter table public.economic_activities add column if not exists budget_amount numeric(14,2) not null default 0 check(budget_amount>=0);
alter table public.economic_activities add column if not exists created_at timestamptz not null default now();
alter table public.economic_activities add column if not exists updated_at timestamptz not null default now();

alter table public.agriculture_expenses add column if not exists finance_expense_id uuid references public.expenses(id) on delete set null;
alter table public.livestock add column if not exists breed text;
alter table public.livestock add column if not exists quantity numeric(14,3) not null default 1 check(quantity>0);
alter table public.livestock add column if not exists unit text not null default 'head';
alter table public.livestock add column if not exists updated_at timestamptz not null default now();

alter table public.productions add column if not exists campaign_id uuid references public.agriculture_campaigns(id) on delete set null;
alter table public.productions add column if not exists livestock_id uuid references public.livestock(id) on delete set null;
alter table public.productions add column if not exists product_id uuid references public.products(id) on delete restrict;
alter table public.productions add column if not exists stock_location_id uuid references public.stock_locations(id) on delete restrict;
alter table public.productions add column if not exists stock_movement_id uuid unique references public.stock_movements(id) on delete restrict;

alter table public.sales add column if not exists cash_transaction_id uuid unique references public.cash_transactions(id) on delete restrict;
alter table public.sales add column if not exists activity_reference text;

-- =========================================================
-- 03. SITES / CHARGES / INTRANTS / LIGNES DE VENTE
-- =========================================================
create table if not exists public.economic_activity_sites(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  code text not null,
  name text not null,
  site_type text,
  location_description text,
  area numeric(14,3) check(area>=0),
  area_unit text,
  responsible_employee_id uuid references public.employees(id) on delete set null,
  status text not null default 'active' check(status in ('active','inactive','archived')),
  created_at timestamptz not null default now(),
  unique(school_id,code)
);

create table if not exists public.economic_activity_expenses(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  site_id uuid references public.economic_activity_sites(id) on delete set null,
  expense_date date not null default current_date,
  category text not null,
  amount numeric(14,2) not null check(amount>=0),
  description text,
  finance_expense_id uuid references public.expenses(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.economic_activity_inputs(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  activity_id uuid not null references public.economic_activities(id) on delete cascade,
  site_id uuid references public.economic_activity_sites(id) on delete set null,
  campaign_id uuid references public.agriculture_campaigns(id) on delete set null,
  livestock_id uuid references public.livestock(id) on delete set null,
  product_id uuid not null references public.products(id) on delete restrict,
  stock_location_id uuid not null references public.stock_locations(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  unit_cost numeric(14,2),
  input_date date not null default current_date,
  stock_movement_id uuid unique references public.stock_movements(id) on delete restrict,
  notes text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.sale_items(
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete restrict,
  production_id uuid references public.productions(id) on delete set null,
  stock_location_id uuid references public.stock_locations(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  unit text not null,
  unit_price numeric(14,2) not null check(unit_price>=0),
  line_total numeric(14,2) generated always as (quantity*unit_price) stored,
  stock_movement_id uuid unique references public.stock_movements(id) on delete restrict,
  notes text
);

-- =========================================================
-- 04. INDEXES / UPDATED_AT
-- =========================================================
create index if not exists ix_economic_activities_school_type on public.economic_activities(school_id,activity_type,status);
create index if not exists ix_activity_sites_activity on public.economic_activity_sites(activity_id,status);
create index if not exists ix_activity_expenses_activity_date on public.economic_activity_expenses(activity_id,expense_date desc);
create index if not exists ix_activity_inputs_activity_date on public.economic_activity_inputs(activity_id,input_date desc);
create index if not exists ix_activity_inputs_product on public.economic_activity_inputs(product_id,stock_location_id,input_date desc);
create index if not exists ix_sale_items_sale on public.sale_items(sale_id);
create index if not exists ix_sales_activity_date on public.sales(activity_id,sale_date desc);
create index if not exists ix_productions_activity_date on public.productions(activity_id,production_date desc);

create or replace function app.set_economic_activity_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end $$;

drop trigger if exists trg_economic_activity_updated_at on public.economic_activities;
create trigger trg_economic_activity_updated_at before update on public.economic_activities for each row execute function app.set_economic_activity_updated_at();

drop trigger if exists trg_livestock_updated_at on public.livestock;
create trigger trg_livestock_updated_at before update on public.livestock for each row execute function app.set_economic_activity_updated_at();

-- =========================================================
-- 05. HELPERS / INTÉGRITÉ MULTI-ÉCOLES
-- =========================================================
create or replace function app.activity_manage_permission(p_activity_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare sid uuid; atype text;
begin
  select school_id,activity_type into sid,atype from public.economic_activities where id=p_activity_id;
  if sid is null then return false; end if;
  if app.is_super_admin() then return true; end if;
  if atype='livestock' then
    return app.has_permission('livestock.manage',sid);
  end if;
  return app.has_permission('agriculture.manage',sid);
end $$;

create or replace function app.activity_view_permission(p_activity_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare sid uuid; atype text;
begin
  select school_id,activity_type into sid,atype from public.economic_activities where id=p_activity_id;
  if sid is null then return false; end if;
  if app.is_super_admin() then return true; end if;
  if atype='livestock' then
    return app.has_permission('livestock.view',sid) or app.has_permission('livestock.manage',sid) or app.has_permission('reports.view',sid) or app.has_role_code('direction',sid) or app.has_role_code('founder',sid);
  end if;
  return app.has_permission('agriculture.view',sid) or app.has_permission('agriculture.manage',sid) or app.has_permission('reports.view',sid) or app.has_role_code('direction',sid) or app.has_role_code('founder',sid);
end $$;

create or replace function app.validate_economic_activity_relation()
returns trigger language plpgsql as $$
declare a_school uuid; p_school uuid; l_school uuid; s_school uuid; c_activity uuid; livestock_activity uuid;
begin
  if tg_table_name='economic_activity_sites' then
    select school_id into a_school from public.economic_activities where id=new.activity_id;
    select school_id into p_school from public.employees where id=new.responsible_employee_id;
    if a_school is null or a_school<>new.school_id then raise exception 'ACTIVITY_SITE_CROSS_SCHOOL'; end if;
    if p_school is not null and p_school<>new.school_id then raise exception 'ACTIVITY_SITE_EMPLOYEE_CROSS_SCHOOL'; end if;
  elsif tg_table_name='economic_activity_expenses' then
    select school_id into a_school from public.economic_activities where id=new.activity_id;
    if a_school is null or a_school<>new.school_id then raise exception 'ACTIVITY_EXPENSE_CROSS_SCHOOL'; end if;
    if new.site_id is not null then select school_id,activity_id into s_school,c_activity from public.economic_activity_sites where id=new.site_id; if s_school<>new.school_id then raise exception 'ACTIVITY_EXPENSE_SITE_CROSS_SCHOOL'; end if; if c_activity<>new.activity_id then raise exception 'ACTIVITY_EXPENSE_SITE_MISMATCH'; end if; end if;
    if new.finance_expense_id is not null then select school_id into p_school from public.expenses where id=new.finance_expense_id; if p_school<>new.school_id then raise exception 'ACTIVITY_EXPENSE_FINANCE_CROSS_SCHOOL'; end if; end if;
  elsif tg_table_name='economic_activity_inputs' then
    select school_id into a_school from public.economic_activities where id=new.activity_id;
    select school_id into p_school from public.products where id=new.product_id;
    select school_id into l_school from public.stock_locations where id=new.stock_location_id;
    if a_school is null or a_school<>new.school_id or p_school<>new.school_id or l_school<>new.school_id then raise exception 'ACTIVITY_INPUT_CROSS_SCHOOL'; end if;
    if new.site_id is not null then select school_id,activity_id into s_school,c_activity from public.economic_activity_sites where id=new.site_id; if s_school<>new.school_id then raise exception 'ACTIVITY_INPUT_SITE_CROSS_SCHOOL'; end if; if c_activity<>new.activity_id then raise exception 'ACTIVITY_INPUT_SITE_MISMATCH'; end if; end if;
    if new.campaign_id is not null then select activity_id into c_activity from public.agriculture_campaigns where id=new.campaign_id; if c_activity<>new.activity_id then raise exception 'ACTIVITY_INPUT_CAMPAIGN_MISMATCH'; end if; end if;
    if new.livestock_id is not null then select activity_id into livestock_activity from public.livestock where id=new.livestock_id; if livestock_activity<>new.activity_id then raise exception 'ACTIVITY_INPUT_LIVESTOCK_MISMATCH'; end if; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_activity_site_integrity on public.economic_activity_sites;
create trigger trg_activity_site_integrity before insert or update on public.economic_activity_sites for each row execute function app.validate_economic_activity_relation();
drop trigger if exists trg_activity_expense_integrity on public.economic_activity_expenses;
create trigger trg_activity_expense_integrity before insert or update on public.economic_activity_expenses for each row execute function app.validate_economic_activity_relation();
drop trigger if exists trg_activity_input_integrity on public.economic_activity_inputs;
create trigger trg_activity_input_integrity before insert or update on public.economic_activity_inputs for each row execute function app.validate_economic_activity_relation();

-- Production : cohérence activité/campagne/élevage/stock.
create or replace function app.validate_production_integrity()
returns trigger language plpgsql as $$
declare sid uuid; csid uuid; ls_id uuid; a_id uuid;
begin
  select school_id into sid from public.economic_activities where id=new.activity_id;
  if sid is null then raise exception 'PRODUCTION_ACTIVITY_NOT_FOUND'; end if;
  if new.campaign_id is not null then
    select ea.school_id,ac.activity_id into csid,a_id from public.agriculture_campaigns ac join public.economic_activities ea on ea.id=ac.activity_id where ac.id=new.campaign_id;
    if csid<>sid or a_id<>new.activity_id then raise exception 'PRODUCTION_CAMPAIGN_MISMATCH'; end if;
  end if;
  if new.livestock_id is not null and (select activity_id from public.livestock where id=new.livestock_id)<>new.activity_id then raise exception 'PRODUCTION_LIVESTOCK_MISMATCH'; end if;
  if new.product_id is not null then
    select school_id into csid from public.products where id=new.product_id;
    if csid<>sid then raise exception 'PRODUCTION_PRODUCT_CROSS_SCHOOL'; end if;
    select school_id into ls_id from public.stock_locations where id=new.stock_location_id;
    if new.stock_location_id is null or ls_id<>sid then raise exception 'PRODUCTION_STOCK_LOCATION_INVALID'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_production_integrity on public.productions;
create trigger trg_production_integrity before insert or update on public.productions for each row execute function app.validate_production_integrity();

-- Sale lines : cohérence de l'activité et des produits.
create or replace function app.validate_sale_item_integrity()
returns trigger language plpgsql as $$
declare sid uuid; psid uuid; lsid uuid;
begin
  select school_id into sid from public.sales where id=new.sale_id;
  if sid is null then raise exception 'SALE_NOT_FOUND'; end if;
  if new.product_id is not null then select school_id into psid from public.products where id=new.product_id; if psid<>sid then raise exception 'SALE_PRODUCT_CROSS_SCHOOL'; end if; end if;
  if new.stock_location_id is not null then select school_id into lsid from public.stock_locations where id=new.stock_location_id; if lsid<>sid then raise exception 'SALE_LOCATION_CROSS_SCHOOL'; end if; end if;
  return new;
end $$;

drop trigger if exists trg_sale_item_integrity on public.sale_items;
create trigger trg_sale_item_integrity before insert or update on public.sale_items for each row execute function app.validate_sale_item_integrity();

-- =========================================================
-- 06. RLS
-- =========================================================
alter table public.economic_activity_sites enable row level security;
alter table public.economic_activity_expenses enable row level security;
alter table public.economic_activity_inputs enable row level security;
alter table public.sale_items enable row level security;

drop policy if exists economic_activity_sites_select on public.economic_activity_sites;
drop policy if exists economic_activity_sites_manage on public.economic_activity_sites;
create policy economic_activity_sites_select on public.economic_activity_sites for select using(app.activity_view_permission(activity_id));
create policy economic_activity_sites_manage on public.economic_activity_sites for all using(app.activity_manage_permission(activity_id)) with check(app.activity_manage_permission(activity_id));

drop policy if exists economic_activity_expenses_select on public.economic_activity_expenses;
drop policy if exists economic_activity_expenses_manage on public.economic_activity_expenses;
create policy economic_activity_expenses_select on public.economic_activity_expenses for select using(app.activity_view_permission(activity_id));
create policy economic_activity_expenses_manage on public.economic_activity_expenses for all using(app.activity_manage_permission(activity_id)) with check(app.activity_manage_permission(activity_id));

drop policy if exists economic_activity_inputs_select on public.economic_activity_inputs;
drop policy if exists economic_activity_inputs_manage on public.economic_activity_inputs;
create policy economic_activity_inputs_select on public.economic_activity_inputs for select using(app.activity_view_permission(activity_id));
create policy economic_activity_inputs_manage on public.economic_activity_inputs for all using(app.activity_manage_permission(activity_id));

drop policy if exists sale_items_select on public.sale_items;
drop policy if exists sale_items_manage on public.sale_items;
create policy sale_items_select on public.sale_items for select using(exists(select 1 from public.sales s where s.id=sale_id and (app.has_permission('agriculture.view',s.school_id) or app.has_permission('agriculture.manage',s.school_id) or app.has_permission('livestock.view',s.school_id) or app.has_permission('livestock.manage',s.school_id) or app.has_permission('reports.view',s.school_id) or app.has_role_code('direction',s.school_id) or app.has_role_code('founder',s.school_id) or app.is_super_admin())));
create policy sale_items_manage on public.sale_items for all using(exists(select 1 from public.sales s where s.id=sale_id and (app.has_permission('agriculture.manage',s.school_id) or app.has_permission('livestock.manage',s.school_id) or app.is_super_admin()))) with check(exists(select 1 from public.sales s where s.id=sale_id and (app.has_permission('agriculture.manage',s.school_id) or app.has_permission('livestock.manage',s.school_id) or app.is_super_admin())));

-- Accès lecture complémentaire pour un responsable élevage sur economic_activities.
drop policy if exists economic_activities_livestock_select on public.economic_activities;
create policy economic_activities_livestock_select on public.economic_activities for select using(activity_type='livestock' and (app.has_permission('livestock.view',school_id) or app.has_permission('livestock.manage',school_id) or app.has_permission('reports.view',school_id) or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()));

-- Améliore la visibilité des productions pour l'élevage sans donner la main en DML directe.
drop policy if exists productions_livestock_select on public.productions;
create policy productions_livestock_select on public.productions for select using(exists(select 1 from public.economic_activities e where e.id=activity_id and ((e.activity_type='livestock' and (app.has_permission('livestock.view',e.school_id) or app.has_permission('livestock.manage',e.school_id))) or (e.activity_type in ('agriculture','agr') and (app.has_permission('agriculture.view',e.school_id) or app.has_permission('agriculture.manage',e.school_id))) or app.has_permission('reports.view',e.school_id) or app.has_role_code('direction',e.school_id) or app.has_role_code('founder',e.school_id) or app.is_super_admin())));

-- =========================================================
-- 07. RPC — ACTIVITÉS / SITES / CAMPAGNES
-- =========================================================
create or replace function public.create_economic_activity(p_code text,p_name text,p_activity_type text,p_responsible_employee_id uuid default null,p_location text default null,p_description text default null,p_start_date date default null,p_end_date date default null,p_budget_amount numeric default 0)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; eschool uuid; aid uuid;
begin
  select school_id into sid from public.users where id=auth.uid();
  if sid is null then raise exception 'ACTIVITY_FORBIDDEN'; end if;
  if p_activity_type not in ('agriculture','livestock','agr') then raise exception 'ACTIVITY_TYPE_INVALID'; end if;
  if p_activity_type='livestock' then
    if not (app.has_permission('livestock.manage',sid) or app.is_super_admin()) then raise exception 'LIVESTOCK_FORBIDDEN'; end if;
  else
    if not (app.has_permission('agriculture.manage',sid) or app.is_super_admin()) then raise exception 'AGRICULTURE_FORBIDDEN'; end if;
  end if;
  if p_responsible_employee_id is not null then select school_id into eschool from public.employees where id=p_responsible_employee_id; if eschool<>sid then raise exception 'ACTIVITY_RESPONSIBLE_CROSS_SCHOOL'; end if; end if;
  if p_budget_amount<0 then raise exception 'ACTIVITY_BUDGET_INVALID'; end if;
  insert into public.economic_activities(school_id,code,name,activity_type,responsible_employee_id,location,description,start_date,end_date,budget_amount,status)
  values(sid,trim(p_code),trim(p_name),p_activity_type,p_responsible_employee_id,nullif(trim(p_location),''),nullif(trim(p_description),''),p_start_date,p_end_date,p_budget_amount,'active')
  returning id into aid;
  return aid;
end $$;

grant execute on function public.create_economic_activity(text,text,text,uuid,text,text,date,date,numeric) to authenticated;

create or replace function public.create_economic_activity_site(p_activity_id uuid,p_code text,p_name text,p_site_type text default null,p_location_description text default null,p_area numeric default null,p_area_unit text default null,p_responsible_employee_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; aid uuid; eschool uuid; x uuid;
begin
  if not app.activity_manage_permission(p_activity_id) then raise exception 'ACTIVITY_SITE_FORBIDDEN'; end if;
  select school_id into sid from public.economic_activities where id=p_activity_id;
  if p_area is not null and p_area<0 then raise exception 'ACTIVITY_SITE_AREA_INVALID'; end if;
  if p_responsible_employee_id is not null then select school_id into eschool from public.employees where id=p_responsible_employee_id; if eschool<>sid then raise exception 'ACTIVITY_SITE_RESPONSIBLE_CROSS_SCHOOL'; end if; end if;
  insert into public.economic_activity_sites(school_id,activity_id,code,name,site_type,location_description,area,area_unit,responsible_employee_id)
  values(sid,p_activity_id,trim(p_code),trim(p_name),nullif(trim(p_site_type),''),nullif(trim(p_location_description),''),p_area,nullif(trim(p_area_unit),''),p_responsible_employee_id)
  returning id into x;
  return x;
end $$;

grant execute on function public.create_economic_activity_site(uuid,text,text,text,text,numeric,text,uuid) to authenticated;

create or replace function public.create_agriculture_campaign(p_activity_id uuid,p_crop text,p_start_date date default null,p_end_date date default null,p_area numeric default null,p_area_unit text default null,p_expected_yield numeric default null,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare x uuid;
begin
  if not app.activity_manage_permission(p_activity_id) then raise exception 'AGRICULTURE_CAMPAIGN_FORBIDDEN'; end if;
  if (select activity_type from public.economic_activities where id=p_activity_id) not in ('agriculture','agr') then raise exception 'AGRICULTURE_ACTIVITY_REQUIRED'; end if;
  if p_area is not null and p_area<0 then raise exception 'CAMPAIGN_AREA_INVALID'; end if;
  if p_expected_yield is not null and p_expected_yield<0 then raise exception 'CAMPAIGN_YIELD_INVALID'; end if;
  insert into public.agriculture_campaigns(activity_id,crop,start_date,end_date,area,area_unit,expected_yield,notes)
  values(p_activity_id,trim(p_crop),p_start_date,p_end_date,p_area,nullif(trim(p_area_unit),''),p_expected_yield,nullif(trim(p_notes),''))
  returning id into x;
  return x;
end $$;

grant execute on function public.create_agriculture_campaign(uuid,text,date,date,numeric,text,numeric,text) to authenticated;

-- =========================================================
-- 08. RPC — INTRANTS / PRODUCTION
-- =========================================================
create or replace function public.record_activity_input(p_activity_id uuid,p_product_id uuid,p_stock_location_id uuid,p_quantity numeric,p_unit_cost numeric default null,p_site_id uuid default null,p_campaign_id uuid default null,p_livestock_id uuid default null,p_input_date date default current_date,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; ps uuid; ls uuid; mid uuid; iid uuid; sm uuid;
begin
  if not app.activity_manage_permission(p_activity_id) then raise exception 'ACTIVITY_INPUT_FORBIDDEN'; end if;
  select school_id into sid from public.economic_activities where id=p_activity_id;
  select school_id into ps from public.products where id=p_product_id;
  select school_id into ls from public.stock_locations where id=p_stock_location_id;
  if ps<>sid or ls<>sid then raise exception 'ACTIVITY_INPUT_STOCK_CROSS_SCHOOL'; end if;
  if p_quantity<=0 then raise exception 'ACTIVITY_INPUT_QUANTITY_INVALID'; end if;
  if p_unit_cost is not null and p_unit_cost<0 then raise exception 'ACTIVITY_INPUT_COST_INVALID'; end if;
  sm:=public.record_stock_movement(p_product_id,p_stock_location_id,'issue'::app.stock_movement_type,p_quantity,p_unit_cost,p_notes);
  insert into public.economic_activity_inputs(school_id,activity_id,site_id,campaign_id,livestock_id,product_id,stock_location_id,quantity,unit_cost,input_date,stock_movement_id,notes,created_by)
  values(sid,p_activity_id,p_site_id,p_campaign_id,p_livestock_id,p_product_id,p_stock_location_id,p_quantity,p_unit_cost,p_input_date,sm,nullif(trim(p_notes),''),auth.uid())
  returning id into iid;
  return iid;
end $$;

grant execute on function public.record_activity_input(uuid,uuid,uuid,numeric,numeric,uuid,uuid,uuid,date,text) to authenticated;

create or replace function public.record_production(p_activity_id uuid,p_product_name text,p_quantity numeric,p_unit text,p_unit_cost numeric default 0,p_product_id uuid default null,p_stock_location_id uuid default null,p_campaign_id uuid default null,p_livestock_id uuid default null,p_production_date date default current_date,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; ps uuid; ls uuid; pid uuid; sm uuid;
begin
  if not app.activity_manage_permission(p_activity_id) then raise exception 'PRODUCTION_FORBIDDEN'; end if;
  select school_id into sid from public.economic_activities where id=p_activity_id;
  if p_quantity<0 or p_unit_cost<0 then raise exception 'PRODUCTION_VALUES_INVALID'; end if;
  if p_product_id is not null then
    if p_stock_location_id is null then raise exception 'PRODUCTION_LOCATION_REQUIRED'; end if;
    select school_id into ps from public.products where id=p_product_id;
    select school_id into ls from public.stock_locations where id=p_stock_location_id;
    if ps<>sid or ls<>sid then raise exception 'PRODUCTION_STOCK_CROSS_SCHOOL'; end if;
    sm:=public.record_stock_movement(p_product_id,p_stock_location_id,'production_in'::app.stock_movement_type,p_quantity,p_unit_cost,'Production: '||trim(p_product_name));
  end if;
  insert into public.productions(activity_id,production_date,product_name,quantity,unit,unit_cost,notes,product_id,stock_location_id,stock_movement_id,campaign_id,livestock_id)
  values(p_activity_id,p_production_date,trim(p_product_name),p_quantity,trim(p_unit),p_unit_cost,nullif(trim(p_notes),''),p_product_id,p_stock_location_id,sm,p_campaign_id,p_livestock_id)
  returning id into pid;
  return pid;
end $$;

grant execute on function public.record_production(uuid,text,numeric,text,numeric,uuid,uuid,uuid,uuid,date,text) to authenticated;

-- =========================================================
-- 09. RPC — DÉPENSES / ÉLEVAGE
-- =========================================================
create or replace function public.record_economic_activity_expense(p_activity_id uuid,p_category text,p_amount numeric,p_expense_date date default current_date,p_description text default null,p_site_id uuid default null,p_finance_expense_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; fs uuid; x uuid;
begin
  if not app.activity_manage_permission(p_activity_id) then raise exception 'ACTIVITY_EXPENSE_FORBIDDEN'; end if;
  select school_id into sid from public.economic_activities where id=p_activity_id;
  if p_amount<0 then raise exception 'ACTIVITY_EXPENSE_AMOUNT_INVALID'; end if;
  if p_finance_expense_id is not null then select school_id into fs from public.expenses where id=p_finance_expense_id; if fs<>sid then raise exception 'ACTIVITY_EXPENSE_FINANCE_CROSS_SCHOOL'; end if; end if;
  insert into public.economic_activity_expenses(school_id,activity_id,site_id,expense_date,category,amount,description,finance_expense_id,created_by)
  values(sid,p_activity_id,p_site_id,p_expense_date,trim(p_category),p_amount,nullif(trim(p_description),''),p_finance_expense_id,auth.uid())
  returning id into x;
  return x;
end $$;

grant execute on function public.record_economic_activity_expense(uuid,text,numeric,date,text,uuid,uuid) to authenticated;

create or replace function public.create_livestock(p_activity_id uuid,p_animal_type text,p_tag_number text default null,p_breed text default null,p_quantity numeric default 1,p_unit text default 'head',p_sex text default null,p_birth_date date default null,p_acquisition_date date default null,p_acquisition_cost numeric default 0,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare x uuid;
begin
  if not app.activity_manage_permission(p_activity_id) then raise exception 'LIVESTOCK_FORBIDDEN'; end if;
  if (select activity_type from public.economic_activities where id=p_activity_id)<>'livestock' then raise exception 'LIVESTOCK_ACTIVITY_REQUIRED'; end if;
  if p_quantity<=0 or p_acquisition_cost<0 then raise exception 'LIVESTOCK_VALUES_INVALID'; end if;
  insert into public.livestock(activity_id,animal_type,tag_number,breed,quantity,unit,acquisition_date,acquisition_cost,status,sex,birth_date,notes)
  values(p_activity_id,trim(p_animal_type),nullif(trim(p_tag_number),''),nullif(trim(p_breed),''),p_quantity,trim(p_unit),p_acquisition_date,p_acquisition_cost,'active',nullif(trim(p_sex),''),p_birth_date,nullif(trim(p_notes),''))
  returning id into x;
  return x;
end $$;

grant execute on function public.create_livestock(uuid,text,text,text,numeric,text,text,date,date,numeric,text) to authenticated;

create or replace function public.record_livestock_event(p_livestock_id uuid,p_event_type text,p_event_date date default current_date,p_quantity numeric default null,p_amount numeric default null,p_description text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare x uuid; aid uuid;
begin
  select activity_id into aid from public.livestock where id=p_livestock_id;
  if aid is null or not app.activity_manage_permission(aid) then raise exception 'LIVESTOCK_EVENT_FORBIDDEN'; end if;
  if p_quantity is not null and p_quantity<0 then raise exception 'LIVESTOCK_EVENT_QUANTITY_INVALID'; end if;
  if p_amount is not null and p_amount<0 then raise exception 'LIVESTOCK_EVENT_AMOUNT_INVALID'; end if;
  insert into public.livestock_events(livestock_id,event_date,event_type,quantity,amount,description)
  values(p_livestock_id,p_event_date,trim(p_event_type),p_quantity,p_amount,nullif(trim(p_description),''))
  returning id into x;
  return x;
end $$;

grant execute on function public.record_livestock_event(uuid,text,date,numeric,numeric,text) to authenticated;

-- =========================================================
-- 10. RPC — VENTES
-- =========================================================
create or replace function public.record_activity_sale(p_sale_number text,p_activity_id uuid default null,p_sale_date date default current_date,p_customer_name text default null,p_payment_method app.payment_method default null,p_description text default null,p_items jsonb default '[]'::jsonb,p_cash_transaction_id uuid default null,p_activity_reference text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; aid uuid; stype text; saleid uuid; item jsonb; product_id uuid; production_id uuid; location_id uuid; qty numeric; unit text; price numeric; total numeric:=0; sm uuid; cs uuid;
begin
  select school_id,activity_type into sid,stype from public.economic_activities where id=p_activity_id;
  if p_activity_id is not null and not app.activity_manage_permission(p_activity_id) then raise exception 'SALE_FORBIDDEN'; end if;
  if p_activity_id is null then
    select school_id into sid from public.users where id=auth.uid();
    if sid is null or not (app.has_permission('agriculture.manage',sid) or app.has_permission('livestock.manage',sid) or app.is_super_admin()) then raise exception 'SALE_FORBIDDEN'; end if;
  end if;
  if p_cash_transaction_id is not null then select school_id into cs from public.cash_transactions where id=p_cash_transaction_id; if cs<>sid then raise exception 'SALE_CASH_CROSS_SCHOOL'; end if; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'SALE_ITEMS_EMPTY'; end if;
  insert into public.sales(school_id,activity_id,sale_number,sale_date,customer_name,amount,payment_method,description,cash_transaction_id,activity_reference)
  values(sid,p_activity_id,trim(p_sale_number),p_sale_date,nullif(trim(p_customer_name),''),0,p_payment_method,nullif(trim(p_description),''),p_cash_transaction_id,nullif(trim(p_activity_reference),'')) returning id into saleid;
  for item in select value from jsonb_array_elements(p_items) loop
    product_id:=nullif(item->>'product_id','')::uuid;
    production_id:=nullif(item->>'production_id','')::uuid;
    location_id:=nullif(item->>'stock_location_id','')::uuid;
    qty:=(item->>'quantity')::numeric;
    unit:=coalesce(nullif(trim(item->>'unit'),''),'unit');
    price:=(item->>'unit_price')::numeric;
    if qty is null or qty<=0 or price is null or price<0 then raise exception 'SALE_ITEM_INVALID'; end if;
    if product_id is not null then
      if location_id is null then raise exception 'SALE_LOCATION_REQUIRED'; end if;
      sm:=public.record_stock_movement(product_id,location_id,'sale'::app.stock_movement_type,qty,price,'Vente: '||trim(p_sale_number));
    end if;
    insert into public.sale_items(sale_id,product_id,production_id,stock_location_id,quantity,unit,unit_price,stock_movement_id,notes)
    values(saleid,product_id,production_id,location_id,qty,unit,price,sm,nullif(trim(item->>'notes'),''));
    total:=total+(qty*price);
  end loop;
  update public.sales set amount=round(total,2) where id=saleid;
  return saleid;
end $$;

grant execute on function public.record_activity_sale(text,uuid,date,text,app.payment_method,text,jsonb,uuid,text) to authenticated;

-- =========================================================
-- 11. DASHBOARD / PERFORMANCE
-- =========================================================
create or replace function public.get_economic_activities_dashboard()
returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid; allow boolean; result jsonb;
begin
  select school_id into sid from public.users where id=auth.uid();
  if sid is null then raise exception 'DASHBOARD_FORBIDDEN'; end if;
  allow:=app.is_super_admin() or app.has_permission('reports.view',sid) or app.has_permission('agriculture.view',sid) or app.has_permission('agriculture.manage',sid) or app.has_permission('livestock.view',sid) or app.has_permission('livestock.manage',sid);
  if not allow then raise exception 'DASHBOARD_FORBIDDEN'; end if;
  select jsonb_build_object(
    'activities',(select count(*) from public.economic_activities where school_id=sid and status='active'),
    'agriculture',(select count(*) from public.economic_activities where school_id=sid and activity_type='agriculture' and status='active'),
    'livestock',(select count(*) from public.economic_activities where school_id=sid and activity_type='livestock' and status='active'),
    'agr',(select count(*) from public.economic_activities where school_id=sid and activity_type='agr' and status='active'),
    'campaigns',(select count(*) from public.agriculture_campaigns ac join public.economic_activities ea on ea.id=ac.activity_id where ea.school_id=sid),
    'livestock_units',(select coalesce(sum(quantity),0) from public.livestock l join public.economic_activities ea on ea.id=l.activity_id where ea.school_id=sid and l.status='active'),
    'productions',(select coalesce(sum(quantity),0) from public.productions p join public.economic_activities ea on ea.id=p.activity_id where ea.school_id=sid),
    'revenue',(select coalesce(sum(amount),0) from public.sales where school_id=sid),
    'expenses',(select coalesce(sum(amount),0) from public.economic_activity_expenses where school_id=sid),
    'agri_expenses',(select coalesce(sum(ae.amount),0) from public.agriculture_expenses ae join public.agriculture_campaigns ac on ac.id=ae.campaign_id join public.economic_activities ea on ea.id=ac.activity_id where ea.school_id=sid),
    'result',(select coalesce(sum(amount),0) from public.sales where school_id=sid) - (select coalesce(sum(amount),0) from public.economic_activity_expenses where school_id=sid) - (select coalesce(sum(ae.amount),0) from public.agriculture_expenses ae join public.agriculture_campaigns ac on ac.id=ae.campaign_id join public.economic_activities ea on ea.id=ac.activity_id where ea.school_id=sid)
  ) into result;
  return result;
end $$;

grant execute on function public.get_economic_activities_dashboard() to authenticated;

create or replace function public.get_economic_activity_performance(p_activity_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid; revenue numeric:=0; expenses numeric:=0; agri_expenses numeric:=0;
begin
  if not app.activity_view_permission(p_activity_id) then raise exception 'ACTIVITY_PERFORMANCE_FORBIDDEN'; end if;
  select school_id into sid from public.economic_activities where id=p_activity_id;
  select coalesce(sum(amount),0) into revenue from public.sales where activity_id=p_activity_id;
  select coalesce(sum(amount),0) into expenses from public.economic_activity_expenses where activity_id=p_activity_id;
  select coalesce(sum(ae.amount),0) into agri_expenses from public.agriculture_expenses ae join public.agriculture_campaigns ac on ac.id=ae.campaign_id where ac.activity_id=p_activity_id;
  return jsonb_build_object('activity_id',p_activity_id,'revenue',revenue,'expenses',expenses+agri_expenses,'result',revenue-expenses-agri_expenses,'school_id',sid);
end $$;

grant execute on function public.get_economic_activity_performance(uuid) to authenticated;

-- =========================================================
-- 12. MUTATIONS DIRECTES BLOQUÉES
-- =========================================================
revoke insert,update,delete on public.economic_activities from authenticated;
revoke insert,update,delete on public.agriculture_campaigns from authenticated;
revoke insert,update,delete on public.agriculture_expenses from authenticated;
revoke insert,update,delete on public.livestock from authenticated;
revoke insert,update,delete on public.livestock_events from authenticated;
revoke insert,update,delete on public.productions from authenticated;
revoke insert,update,delete on public.sales from authenticated;
revoke insert,update,delete on public.economic_activity_sites from authenticated;
revoke insert,update,delete on public.economic_activity_expenses from authenticated;
revoke insert,update,delete on public.economic_activity_inputs from authenticated;
revoke insert,update,delete on public.sale_items from authenticated;

revoke execute on function public.create_economic_activity(text,text,text,uuid,text,text,date,date,numeric) from public;
revoke execute on function public.create_economic_activity_site(uuid,text,text,text,text,numeric,text,uuid) from public;
revoke execute on function public.create_agriculture_campaign(uuid,text,date,date,numeric,text,numeric,text) from public;
revoke execute on function public.record_activity_input(uuid,uuid,uuid,numeric,numeric,uuid,uuid,uuid,date,text) from public;
revoke execute on function public.record_production(uuid,text,numeric,text,numeric,uuid,uuid,uuid,uuid,date,text) from public;
revoke execute on function public.record_economic_activity_expense(uuid,text,numeric,date,text,uuid,uuid) from public;
revoke execute on function public.create_livestock(uuid,text,text,text,numeric,text,text,date,date,numeric,text) from public;
revoke execute on function public.record_livestock_event(uuid,text,date,numeric,numeric,text) from public;
revoke execute on function public.record_activity_sale(text,uuid,date,text,app.payment_method,text,jsonb,uuid,text) from public;
revoke execute on function public.get_economic_activities_dashboard() from public;
revoke execute on function public.get_economic_activity_performance(uuid) from public;

commit;
