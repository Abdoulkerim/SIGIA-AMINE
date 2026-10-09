-- SIGIA-AMINE
-- Migration 025: catering workflows
-- Étape 17 — Restauration
-- Périmètre : types de repas, menus, service, présence, consommations,
-- intégration stock cuisine, coûts et tableau de bord.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- 01. PERMISSIONS
-- =========================================================
insert into public.permissions(code,name,module,action,description)
values
  ('catering.view','Consulter restauration','catering','view','Consulter menus, services, présences, consommations et indicateurs'),
  ('catering.manage','Gérer restauration','catering','manage','Gérer menus, services, présences et consommations')
on conflict (code) do update
set name=excluded.name,module=excluded.module,action=excluded.action,description=excluded.description;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r join public.permissions p on p.code='catering.view'
where r.code in ('super_admin','founder','direction','boarding_manager','catering_manager','accountant')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r join public.permissions p on p.code='catering.manage'
where r.code in ('super_admin','founder','direction','boarding_manager','catering_manager')
on conflict do nothing;

-- =========================================================
-- 02. QUALITÉ / EXTENSIONS DES TABLES EXISTANTES
-- =========================================================
alter table public.meal_types add column if not exists is_active boolean not null default true;
alter table public.meal_types add column if not exists sort_order integer not null default 0;
alter table public.meal_types add column if not exists created_at timestamptz not null default now();
alter table public.meal_types add column if not exists updated_at timestamptz not null default now();

alter table public.menus add column if not exists status text not null default 'draft';
alter table public.menus add column if not exists published_at timestamptz;
alter table public.menus add column if not exists updated_at timestamptz not null default now();

alter table public.menu_items add column if not exists planned_quantity numeric(12,3);
alter table public.menu_items add column if not exists planned_unit text;
alter table public.menu_items add column if not exists notes text;
alter table public.menu_items add column if not exists updated_at timestamptz not null default now();

alter table public.meal_service_records add column if not exists served_at timestamptz;
alter table public.meal_service_records add column if not exists recorded_by uuid references public.users(id) on delete set null;
alter table public.meal_service_records add column if not exists status text not null default 'recorded';

alter table public.meal_attendance add column if not exists recorded_by uuid references public.users(id) on delete set null;
alter table public.meal_attendance add column if not exists notes text;
alter table public.meal_attendance add column if not exists updated_at timestamptz not null default now();

alter table public.meal_types drop constraint if exists meal_types_code_ck;
alter table public.meal_types add constraint meal_types_code_ck check(length(trim(code)) between 1 and 40);
alter table public.meal_types drop constraint if exists meal_types_name_ck;
alter table public.meal_types add constraint meal_types_name_ck check(length(trim(name)) between 1 and 100);
alter table public.menus drop constraint if exists menus_status_ck;
alter table public.menus add constraint menus_status_ck check(status in ('draft','published','closed'));
alter table public.menu_items drop constraint if exists menu_items_estimated_cost_ck;
alter table public.menu_items add constraint menu_items_estimated_cost_ck check(estimated_cost>=0);
alter table public.menu_items drop constraint if exists menu_items_planned_qty_ck;
alter table public.menu_items add constraint menu_items_planned_qty_ck check(planned_quantity is null or planned_quantity>0);
alter table public.menu_items drop constraint if exists menu_items_planned_unit_ck;
alter table public.menu_items add constraint menu_items_planned_unit_ck check(planned_quantity is null or length(trim(coalesce(planned_unit,''))) between 1 and 30);
alter table public.meal_service_records drop constraint if exists meal_service_records_qty_ck;
alter table public.meal_service_records add constraint meal_service_records_qty_ck check(served_quantity>=0);
alter table public.meal_service_records drop constraint if exists meal_service_records_cost_ck;
alter table public.meal_service_records add constraint meal_service_records_cost_ck check(actual_cost>=0);
alter table public.meal_service_records drop constraint if exists meal_service_records_status_ck;
alter table public.meal_service_records add constraint meal_service_records_status_ck check(status in ('recorded','closed'));
alter table public.meal_attendance drop constraint if exists meal_attendance_qty_ck;
alter table public.meal_attendance add constraint meal_attendance_qty_ck check(quantity>=0);

create unique index if not exists ux_meal_types_school_lower_code on public.meal_types(school_id,lower(trim(code)));
create index if not exists ix_meal_types_school_active_order on public.meal_types(school_id,is_active,sort_order);
create index if not exists ix_menus_school_date_status on public.menus(school_id,menu_date,status);
create unique index if not exists ux_menu_items_menu_meal_type on public.menu_items(menu_id,meal_type_id);
create index if not exists ix_menu_items_meal on public.menu_items(meal_type_id);
create unique index if not exists ux_meal_service_menu_item on public.meal_service_records(menu_item_id);
create index if not exists ix_meal_service_school_status on public.meal_service_records(school_id,status);
create index if not exists ix_meal_attendance_school_date_meal on public.meal_attendance(school_id,meal_date,meal_type_id);
create index if not exists ix_meal_attendance_student_date on public.meal_attendance(student_id,meal_date desc);

-- =========================================================
-- 03. LIEN MENUS -> STOCK / CONSOMMATION
-- =========================================================
create table if not exists public.catering_menu_ingredients(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  planned_quantity numeric(14,3) not null check(planned_quantity>0),
  unit text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(menu_item_id,product_id)
);

create table if not exists public.catering_consumptions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  location_id uuid not null references public.stock_locations(id) on delete restrict,
  stock_movement_id uuid not null unique references public.stock_movements(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  unit_cost numeric(14,2) not null default 0 check(unit_cost>=0),
  total_cost numeric(14,2) generated always as (quantity*unit_cost) stored,
  consumed_at timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  notes text
);

create table if not exists public.catering_purchase_links(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete restrict,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null check(quantity>0),
  created_at timestamptz not null default now(),
  unique(menu_item_id,purchase_order_id,product_id)
);

create index if not exists ix_catering_ingredients_school_menu on public.catering_menu_ingredients(school_id,menu_item_id);
create index if not exists ix_catering_ingredients_product on public.catering_menu_ingredients(product_id);
create index if not exists ix_catering_consumptions_school_date on public.catering_consumptions(school_id,consumed_at desc);
create index if not exists ix_catering_consumptions_product on public.catering_consumptions(product_id,consumed_at desc);
create index if not exists ix_catering_purchase_links_menu on public.catering_purchase_links(menu_item_id);

-- =========================================================
-- 04. TRIGGERS UPDATED_AT
-- =========================================================
drop trigger if exists trg_meal_types_updated_at on public.meal_types;
create trigger trg_meal_types_updated_at before update on public.meal_types for each row execute function app.set_updated_at();
drop trigger if exists trg_menus_updated_at on public.menus;
create trigger trg_menus_updated_at before update on public.menus for each row execute function app.set_updated_at();
drop trigger if exists trg_menu_items_updated_at on public.menu_items;
create trigger trg_menu_items_updated_at before update on public.menu_items for each row execute function app.set_updated_at();
drop trigger if exists trg_meal_attendance_updated_at on public.meal_attendance;
create trigger trg_meal_attendance_updated_at before update on public.meal_attendance for each row execute function app.set_updated_at();
drop trigger if exists trg_catering_menu_ingredients_updated_at on public.catering_menu_ingredients;
create trigger trg_catering_menu_ingredients_updated_at before update on public.catering_menu_ingredients for each row execute function app.set_updated_at();

-- =========================================================
-- 05. HELPERS
-- =========================================================
create or replace function app.catering_has_manage(p_school_id uuid)
returns boolean
language sql stable security definer set search_path=''
as $$
  select app.is_super_admin()
      or app.has_permission('catering.manage',p_school_id)
      or app.has_role_code('direction',p_school_id)
      or app.has_role_code('founder',p_school_id);
$$;

create or replace function app.catering_has_view(p_school_id uuid)
returns boolean
language sql stable security definer set search_path=''
as $$
  select app.is_super_admin()
      or app.has_permission('catering.view',p_school_id)
      or app.has_permission('catering.manage',p_school_id)
      or app.has_permission('boarding.manage',p_school_id)
      or app.has_role_code('direction',p_school_id)
      or app.has_role_code('founder',p_school_id);
$$;

revoke all on function app.catering_has_manage(uuid) from public;
revoke all on function app.catering_has_view(uuid) from public;
grant execute on function app.catering_has_manage(uuid) to authenticated;
grant execute on function app.catering_has_view(uuid) to authenticated;

-- =========================================================
-- 06. RPC : TYPES DE REPAS / MENUS
-- =========================================================
create or replace function public.create_meal_type(p_school_id uuid,p_code text,p_name text,p_sort_order integer default 0)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid;
begin
  if not app.catering_has_manage(p_school_id) then raise exception 'CATERING_FORBIDDEN'; end if;
  if length(trim(p_code))=0 or length(trim(p_name))=0 then raise exception 'CATERING_INVALID_MEAL_TYPE'; end if;
  insert into public.meal_types(school_id,code,name,sort_order,is_active) values(p_school_id,trim(p_code),trim(p_name),p_sort_order,true) returning id into v_id;
  return v_id;
end $$;

create or replace function public.set_meal_type_active(p_meal_type_id uuid,p_is_active boolean)
returns void
language plpgsql security definer set search_path=''
as $$
declare v_school uuid;
begin
  select school_id into v_school from public.meal_types where id=p_meal_type_id;
  if v_school is null then raise exception 'CATERING_MEAL_TYPE_NOT_FOUND'; end if;
  if not app.catering_has_manage(v_school) then raise exception 'CATERING_FORBIDDEN'; end if;
  update public.meal_types set is_active=p_is_active where id=p_meal_type_id;
end $$;

create or replace function public.create_catering_menu(p_school_id uuid,p_menu_date date,p_notes text default null)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid;
begin
  if not app.catering_has_manage(p_school_id) then raise exception 'CATERING_FORBIDDEN'; end if;
  insert into public.menus(school_id,menu_date,notes,created_by,status)
  values(p_school_id,p_menu_date,nullif(trim(p_notes),''),auth.uid(),'draft')
  on conflict(school_id,menu_date) do update set notes=excluded.notes, updated_at=now()
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.upsert_catering_menu_item(
  p_menu_id uuid,p_meal_type_id uuid,p_description text,p_estimated_cost numeric,p_planned_quantity numeric,p_planned_unit text,p_notes text default null)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_school uuid; v_menu_status text; v_mt_school uuid;
begin
  select school_id,status into v_school,v_menu_status from public.menus where id=p_menu_id;
  if v_school is null then raise exception 'CATERING_MENU_NOT_FOUND'; end if;
  if not app.catering_has_manage(v_school) then raise exception 'CATERING_FORBIDDEN'; end if;
  if v_menu_status<>'draft' then raise exception 'CATERING_MENU_LOCKED'; end if;
  select school_id into v_mt_school from public.meal_types where id=p_meal_type_id and is_active;
  if v_mt_school is null or v_mt_school<>v_school then raise exception 'CATERING_MEAL_TYPE_INVALID'; end if;
  if length(trim(p_description))=0 then raise exception 'CATERING_DESCRIPTION_REQUIRED'; end if;
  if p_estimated_cost is null or p_estimated_cost<0 then raise exception 'CATERING_COST_INVALID'; end if;
  insert into public.menu_items(menu_id,meal_type_id,description,estimated_cost,planned_quantity,planned_unit,notes)
  values(p_menu_id,p_meal_type_id,trim(p_description),p_estimated_cost,p_planned_quantity,nullif(trim(p_planned_unit),''),nullif(trim(p_notes),''))
  on conflict(menu_id,meal_type_id) do update set description=excluded.description,estimated_cost=excluded.estimated_cost,planned_quantity=excluded.planned_quantity,planned_unit=excluded.planned_unit,notes=excluded.notes,updated_at=now()
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.publish_catering_menu(p_menu_id uuid)
returns void
language plpgsql security definer set search_path=''
as $$
declare v_school uuid; v_status text; v_count bigint;
begin
  select school_id,status into v_school,v_status from public.menus where id=p_menu_id;
  if v_school is null then raise exception 'CATERING_MENU_NOT_FOUND'; end if;
  if not app.catering_has_manage(v_school) then raise exception 'CATERING_FORBIDDEN'; end if;
  if v_status='closed' then raise exception 'CATERING_MENU_CLOSED'; end if;
  select count(*) into v_count from public.menu_items where menu_id=p_menu_id;
  if v_count=0 then raise exception 'CATERING_MENU_EMPTY'; end if;
  update public.menus set status='published',published_at=coalesce(published_at,now()),updated_at=now() where id=p_menu_id;
end $$;

create or replace function public.close_catering_menu(p_menu_id uuid)
returns void
language plpgsql security definer set search_path=''
as $$
declare v_school uuid; v_status text;
begin
  select school_id,status into v_school,v_status from public.menus where id=p_menu_id;
  if v_school is null then raise exception 'CATERING_MENU_NOT_FOUND'; end if;
  if not app.catering_has_manage(v_school) then raise exception 'CATERING_FORBIDDEN'; end if;
  if v_status<>'published' then raise exception 'CATERING_MENU_NOT_PUBLISHED'; end if;
  update public.menus set status='closed',updated_at=now() where id=p_menu_id;
end $$;

-- =========================================================
-- 07. RPC : INGREDIENTS / SERVICES / PRÉSENCE
-- =========================================================
create or replace function public.upsert_catering_ingredient(p_menu_item_id uuid,p_product_id uuid,p_planned_quantity numeric,p_unit text,p_notes text default null)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_school uuid; v_product_school uuid; v_menu_status text;
begin
  select m.school_id,m.status into v_school,v_menu_status from public.menu_items mi join public.menus m on m.id=mi.menu_id where mi.id=p_menu_item_id;
  if v_school is null then raise exception 'CATERING_MENU_ITEM_NOT_FOUND'; end if;
  if not app.catering_has_manage(v_school) then raise exception 'CATERING_FORBIDDEN'; end if;
  if v_menu_status<>'draft' then raise exception 'CATERING_MENU_LOCKED'; end if;
  select school_id into v_product_school from public.products where id=p_product_id and is_active;
  if v_product_school is null or v_product_school<>v_school then raise exception 'CATERING_PRODUCT_INVALID'; end if;
  if p_planned_quantity is null or p_planned_quantity<=0 or length(trim(p_unit))=0 then raise exception 'CATERING_INGREDIENT_INVALID'; end if;
  insert into public.catering_menu_ingredients(school_id,menu_item_id,product_id,planned_quantity,unit,notes)
  values(v_school,p_menu_item_id,p_product_id,p_planned_quantity,trim(p_unit),nullif(trim(p_notes),''))
  on conflict(menu_item_id,product_id) do update set planned_quantity=excluded.planned_quantity,unit=excluded.unit,notes=excluded.notes,updated_at=now()
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.record_catering_service(p_menu_item_id uuid,p_served_quantity numeric,p_unit text,p_actual_cost numeric,p_notes text default null)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_school uuid; v_menu_status text;
begin
  select m.school_id,m.status into v_school,v_menu_status from public.menu_items mi join public.menus m on m.id=mi.menu_id where mi.id=p_menu_item_id;
  if v_school is null then raise exception 'CATERING_MENU_ITEM_NOT_FOUND'; end if;
  if not app.catering_has_manage(v_school) then raise exception 'CATERING_FORBIDDEN'; end if;
  if v_menu_status='draft' then raise exception 'CATERING_MENU_NOT_PUBLISHED'; end if;
  if p_served_quantity<0 or p_actual_cost<0 then raise exception 'CATERING_SERVICE_INVALID'; end if;
  insert into public.meal_service_records(school_id,menu_item_id,served_quantity,unit,actual_cost,notes,served_at,recorded_by,status)
  values(v_school,p_menu_item_id,p_served_quantity,nullif(trim(p_unit),''),p_actual_cost,nullif(trim(p_notes),''),now(),auth.uid(),'recorded')
  on conflict(menu_item_id) do update set served_quantity=excluded.served_quantity,unit=excluded.unit,actual_cost=excluded.actual_cost,notes=excluded.notes,served_at=excluded.served_at,recorded_by=excluded.recorded_by,status='recorded'
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.set_meal_attendance(p_student_id uuid,p_meal_type_id uuid,p_meal_date date,p_served boolean,p_quantity numeric default 1,p_notes text default null)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_school uuid; v_mt_school uuid; v_menu_school uuid;
begin
  select school_id into v_school from public.students where id=p_student_id;
  select school_id into v_mt_school from public.meal_types where id=p_meal_type_id and is_active;
  select school_id into v_menu_school from public.menus where school_id=v_school and menu_date=p_meal_date;
  if v_school is null or v_mt_school is null or v_mt_school<>v_school or v_menu_school is null then raise exception 'CATERING_ATTENDANCE_CONTEXT_INVALID'; end if;
  if not (app.catering_has_manage(v_school) or app.has_permission('attendance.manage',v_school) or app.has_permission('boarding.manage',v_school)) then raise exception 'CATERING_FORBIDDEN'; end if;
  if p_quantity<0 then raise exception 'CATERING_ATTENDANCE_QUANTITY_INVALID'; end if;
  insert into public.meal_attendance(school_id,student_id,meal_type_id,meal_date,served,quantity,recorded_by,notes)
  values(v_school,p_student_id,p_meal_type_id,p_meal_date,p_served,p_quantity,auth.uid(),nullif(trim(p_notes),''))
  on conflict(student_id,meal_type_id,meal_date) do update set served=excluded.served,quantity=excluded.quantity,recorded_by=excluded.recorded_by,notes=excluded.notes,updated_at=now()
  returning id into v_id;
  return v_id;
end $$;

-- =========================================================
-- 08. RPC : CONSOMMATION STOCK CUISINE
-- =========================================================
create or replace function public.consume_catering_stock(p_menu_item_id uuid,p_product_id uuid,p_location_id uuid,p_quantity numeric,p_unit_cost numeric default 0,p_notes text default null)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_school uuid; v_product_school uuid; v_location_school uuid; v_movement_id uuid; v_balance numeric; v_item_school uuid;
begin
  select m.school_id into v_school from public.menu_items mi join public.menus m on m.id=mi.menu_id where mi.id=p_menu_item_id;
  select school_id into v_product_school from public.products where id=p_product_id and is_active;
  select school_id into v_location_school from public.stock_locations where id=p_location_id;
  select school_id into v_item_school from public.products where id=p_product_id;
  if v_school is null or v_product_school is null or v_product_school<>v_school or v_location_school is null or v_location_school<>v_school then raise exception 'CATERING_STOCK_CONTEXT_INVALID'; end if;
  if not (app.catering_has_manage(v_school) or app.has_permission('stock.manage',v_school)) then raise exception 'CATERING_STOCK_FORBIDDEN'; end if;
  if p_quantity<=0 or p_unit_cost<0 then raise exception 'CATERING_STOCK_QUANTITY_INVALID'; end if;
  select quantity into v_balance from public.stock_balances where product_id=p_product_id and location_id=p_location_id for update;
  if coalesce(v_balance,0)<p_quantity then raise exception 'CATERING_STOCK_INSUFFICIENT'; end if;
  insert into public.stock_movements(school_id,product_id,location_id,movement_type,quantity,unit_cost,reference_type,reference_id,created_by,notes)
  values(v_school,p_product_id,p_location_id,'issue',p_quantity,p_unit_cost,'catering_menu_item',p_menu_item_id,auth.uid(),nullif(trim(p_notes),''))
  returning id into v_movement_id;
  insert into public.catering_consumptions(school_id,menu_item_id,product_id,location_id,stock_movement_id,quantity,unit_cost,created_by,notes)
  values(v_school,p_menu_item_id,p_product_id,p_location_id,v_movement_id,p_quantity,p_unit_cost,auth.uid(),nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end $$;

-- =========================================================
-- 09. RPC : LIEN ACHATS -> MENU
-- =========================================================
create or replace function public.link_catering_purchase(p_menu_item_id uuid,p_purchase_order_id uuid,p_product_id uuid,p_quantity numeric)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_school uuid; v_po_school uuid; v_product_school uuid; v_menu_school uuid;
begin
  select m.school_id into v_menu_school from public.menu_items mi join public.menus m on m.id=mi.menu_id where mi.id=p_menu_item_id;
  select school_id into v_po_school from public.purchase_orders where id=p_purchase_order_id;
  select school_id into v_product_school from public.products where id=p_product_id;
  if v_menu_school is null or v_po_school is null or v_product_school is null or v_menu_school<>v_po_school or v_menu_school<>v_product_school then raise exception 'CATERING_PURCHASE_CONTEXT_INVALID'; end if;
  if not (app.catering_has_manage(v_menu_school) or app.has_permission('purchases.manage',v_menu_school)) then raise exception 'CATERING_PURCHASE_FORBIDDEN'; end if;
  if p_quantity<=0 then raise exception 'CATERING_PURCHASE_QUANTITY_INVALID'; end if;
  insert into public.catering_purchase_links(school_id,menu_item_id,purchase_order_id,product_id,quantity)
  values(v_menu_school,p_menu_item_id,p_purchase_order_id,p_product_id,p_quantity)
  on conflict(menu_item_id,purchase_order_id,product_id) do update set quantity=excluded.quantity
  returning id into v_id;
  return v_id;
end $$;

-- =========================================================
-- 10. RPC : TABLEAU DE BORD RESTAURATION
-- =========================================================
create or replace function public.get_catering_dashboard(p_school_id uuid,p_date date default current_date)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare result jsonb; v_menus bigint; v_published bigint; v_meals bigint; v_served bigint; v_cost numeric; v_attendance bigint; v_consumption numeric;
begin
  if not (app.is_super_admin() or app.has_permission('catering.view',p_school_id) or app.has_permission('catering.manage',p_school_id) or app.has_permission('boarding.manage',p_school_id) or app.has_role_code('direction',p_school_id) or app.has_role_code('founder',p_school_id)) then raise exception 'CATERING_FORBIDDEN'; end if;
  select count(*) into v_menus from public.menus where school_id=p_school_id and menu_date=p_date;
  select count(*) into v_published from public.menus where school_id=p_school_id and menu_date=p_date and status='published';
  select count(*) into v_meals from public.menu_items mi join public.menus m on m.id=mi.menu_id where m.school_id=p_school_id and m.menu_date=p_date;
  select coalesce(sum(served_quantity),0) into v_served from public.meal_service_records ms join public.menu_items mi on mi.id=ms.menu_item_id join public.menus m on m.id=mi.menu_id where m.school_id=p_school_id and m.menu_date=p_date;
  select coalesce(sum(actual_cost),0) into v_cost from public.meal_service_records ms join public.menu_items mi on mi.id=ms.menu_item_id join public.menus m on m.id=mi.menu_id where m.school_id=p_school_id and m.menu_date=p_date;
  select count(*) into v_attendance from public.meal_attendance where school_id=p_school_id and meal_date=p_date and served;
  select coalesce(sum(cc.total_cost),0) into v_consumption from public.catering_consumptions cc where cc.school_id=p_school_id and cc.consumed_at::date=p_date;
  result:=jsonb_build_object('menus',v_menus,'published_menus',v_published,'meal_items',v_meals,'served_quantity',v_served,'service_cost',v_cost,'meal_attendance',v_attendance,'stock_consumption_cost',v_consumption);
  return result;
end $$;

-- =========================================================
-- 11. LECTURE : PARENTS / ÉLÈVES ET PERSONNEL AUTORISÉ
-- =========================================================
alter table public.meal_types enable row level security;
alter table public.menus enable row level security;
alter table public.meal_service_records enable row level security;
alter table public.meal_attendance enable row level security;
alter table public.catering_menu_ingredients enable row level security;
alter table public.catering_consumptions enable row level security;
alter table public.catering_purchase_links enable row level security;
alter table public.menu_items enable row level security;

-- menu_items existait avec des politiques génériques ; on les remplace pour n'exposer que les lignes autorisées.
drop policy if exists menu_items_secure on public.menu_items;
drop policy if exists menu_items_manage on public.menu_items;

drop policy if exists meal_types_select_secure on public.meal_types;
drop policy if exists meal_types_manage_secure on public.meal_types;
drop policy if exists menus_select_secure on public.menus;
drop policy if exists menus_manage_secure on public.menus;
drop policy if exists menus_insert_secure on public.menus;
drop policy if exists menus_update_secure on public.menus;
drop policy if exists menus_delete_secure on public.menus;
drop policy if exists meal_service_records_select_secure on public.meal_service_records;
drop policy if exists meal_service_records_manage_secure on public.meal_service_records;
drop policy if exists meal_service_records_insert_secure on public.meal_service_records;
drop policy if exists meal_service_records_update_secure on public.meal_service_records;
drop policy if exists meal_service_records_delete_secure on public.meal_service_records;
drop policy if exists meal_attendance_select_secure on public.meal_attendance;
drop policy if exists meal_attendance_manage_secure on public.meal_attendance;
drop policy if exists meal_attendance_insert_secure on public.meal_attendance;
drop policy if exists meal_attendance_update_secure on public.meal_attendance;
drop policy if exists meal_attendance_delete_secure on public.meal_attendance;
drop policy if exists catering_ingredients_select_secure on public.catering_menu_ingredients;
drop policy if exists catering_consumptions_select_secure on public.catering_consumptions;
drop policy if exists catering_purchase_links_select_secure on public.catering_purchase_links;

create policy meal_types_select_secure on public.meal_types for select using(app.catering_has_view(school_id));
create policy menus_select_secure on public.menus for select using(app.catering_has_view(school_id));
create policy menu_items_select_secure on public.menu_items for select using(exists(select 1 from public.menus m where m.id=menu_id and app.catering_has_view(m.school_id)));
create policy meal_service_records_select_secure on public.meal_service_records for select using(app.catering_has_view(school_id));
create policy meal_attendance_select_secure on public.meal_attendance for select using(app.catering_has_view(school_id) or app.is_parent_of_student(student_id) or app.is_self_student(student_id));
create policy catering_ingredients_select_secure on public.catering_menu_ingredients for select using(app.catering_has_view(school_id));
create policy catering_consumptions_select_secure on public.catering_consumptions for select using(app.catering_has_view(school_id) or app.has_permission('stock.manage',school_id));
create policy catering_purchase_links_select_secure on public.catering_purchase_links for select using(app.catering_has_view(school_id) or app.has_permission('purchases.manage',school_id));

-- Toutes les écritures passent par RPC.
revoke insert,update,delete on public.meal_types from authenticated;
revoke insert,update,delete on public.menus from authenticated;
revoke insert,update,delete on public.menu_items from authenticated;
revoke insert,update,delete on public.meal_service_records from authenticated;
revoke insert,update,delete on public.meal_attendance from authenticated;
revoke insert,update,delete on public.catering_menu_ingredients from authenticated;
revoke insert,update,delete on public.catering_consumptions from authenticated;
revoke insert,update,delete on public.catering_purchase_links from authenticated;

grant select on public.meal_types,public.menus,public.menu_items,public.meal_service_records,public.meal_attendance,public.catering_menu_ingredients,public.catering_consumptions,public.catering_purchase_links to authenticated;

-- Exécution contrôlée des RPC.
revoke all on function public.create_meal_type(uuid,text,text,integer) from public;
revoke all on function public.set_meal_type_active(uuid,boolean) from public;
revoke all on function public.create_catering_menu(uuid,date,text) from public;
revoke all on function public.upsert_catering_menu_item(uuid,uuid,text,numeric,numeric,text,text) from public;
revoke all on function public.publish_catering_menu(uuid) from public;
revoke all on function public.close_catering_menu(uuid) from public;
revoke all on function public.upsert_catering_ingredient(uuid,uuid,numeric,text,text) from public;
revoke all on function public.record_catering_service(uuid,numeric,text,numeric,text) from public;
revoke all on function public.set_meal_attendance(uuid,uuid,date,boolean,numeric,text) from public;
revoke all on function public.consume_catering_stock(uuid,uuid,uuid,numeric,numeric,text) from public;
revoke all on function public.link_catering_purchase(uuid,uuid,uuid,numeric) from public;
revoke all on function public.get_catering_dashboard(uuid,date) from public;

grant execute on function public.create_meal_type(uuid,text,text,integer) to authenticated;
grant execute on function public.set_meal_type_active(uuid,boolean) to authenticated;
grant execute on function public.create_catering_menu(uuid,date,text) to authenticated;
grant execute on function public.upsert_catering_menu_item(uuid,uuid,text,numeric,numeric,text,text) to authenticated;
grant execute on function public.publish_catering_menu(uuid) to authenticated;
grant execute on function public.close_catering_menu(uuid) to authenticated;
grant execute on function public.upsert_catering_ingredient(uuid,uuid,numeric,text,text) to authenticated;
grant execute on function public.record_catering_service(uuid,numeric,text,numeric,text) to authenticated;
grant execute on function public.set_meal_attendance(uuid,uuid,date,boolean,numeric,text) to authenticated;
grant execute on function public.consume_catering_stock(uuid,uuid,uuid,numeric,numeric,text) to authenticated;
grant execute on function public.link_catering_purchase(uuid,uuid,uuid,numeric) to authenticated;
grant execute on function public.get_catering_dashboard(uuid,date) to authenticated;

comment on table public.catering_menu_ingredients is 'Produits et quantités prévisionnelles nécessaires à un repas.';
comment on table public.catering_consumptions is 'Consommations cuisine reliées à un mouvement de stock de type issue.';
comment on table public.catering_purchase_links is 'Lien entre besoins de restauration et commandes d’achat existantes.';
comment on function public.get_catering_dashboard(uuid,date) is 'Tableau de bord sécurisé de la restauration.';

commit;

-- Dossier élève : sous-dossier restauration sécurisé.
create or replace function public.get_student_catering(p_student_id uuid)
returns jsonb
language sql stable security invoker set search_path=public,app
as $$
select jsonb_build_object(
  'attendance',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'meal_date',a.meal_date,'served',a.served,'quantity',a.quantity,'meal_type',mt.name,'notes',a.notes) order by a.meal_date desc) from public.meal_attendance a join public.meal_types mt on mt.id=a.meal_type_id where a.student_id=p_student_id),'[]'::jsonb)
);
$$;
revoke all on function public.get_student_catering(uuid) from public;
grant execute on function public.get_student_catering(uuid) to authenticated;
comment on function public.get_student_catering(uuid) is 'Sous-dossier restauration de l’élève. Les RLS de meal_attendance restent applicables.';
