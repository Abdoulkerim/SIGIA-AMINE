-- Contrat Étape 19 — Stocks / Achats
-- Ces assertions vérifient l'existence des objets structurels et des protections critiques.

begin;
select plan(33);

select has_table('public','purchase_requests','purchase_requests');
select has_table('public','purchase_request_items','purchase_request_items');
select has_table('public','purchase_receipts','purchase_receipts');
select has_table('public','purchase_receipt_items','purchase_receipt_items');
select has_table('public','stock_transfers','stock_transfers');
select has_table('public','stock_transfer_items','stock_transfer_items');
select has_table('public','purchase_invoices','purchase_invoices');
select has_table('public','purchase_invoice_payments','purchase_invoice_payments');

select has_function('public','create_product', array['text','text','uuid','text','numeric','numeric','numeric','text','text','numeric','boolean'], 'create_product RPC exists');
select has_function('public','record_stock_movement', array['uuid','uuid','app.stock_movement_type','numeric','numeric','text'], 'record_stock_movement RPC exists');
select has_function('public','create_stock_inventory', array['uuid','date','text'], 'create_stock_inventory RPC exists');
select has_function('public','finalize_stock_inventory', array['uuid'], 'finalize_stock_inventory RPC exists');
select has_function('public','create_purchase_request', array['text','date','text','text','jsonb'], 'create_purchase_request RPC exists');
select has_function('public','create_purchase_order', array['text','uuid','date','date','uuid','uuid','jsonb'], 'create_purchase_order RPC exists');
select has_function('public','receive_purchase_order', array['uuid','uuid','text','timestamptz','jsonb','text'], 'receive_purchase_order RPC exists');
select has_function('public','create_stock_transfer', array['text','uuid','uuid','date','jsonb','text'], 'create_stock_transfer RPC exists');
select has_function('public','complete_stock_transfer', array['uuid'], 'complete_stock_transfer RPC exists');
select has_function('public','create_purchase_invoice', array['uuid','uuid','text','date','date','numeric','text'], 'create_purchase_invoice RPC exists');
select has_function('public','pay_purchase_invoice', array['uuid','uuid','numeric','timestamptz','text'], 'pay_purchase_invoice RPC exists');

select ok((select data_type from information_schema.columns where table_schema='public' and table_name='products' and column_name='reorder_quantity')='numeric','products.reorder_quantity is numeric');
select ok((select data_type from information_schema.columns where table_schema='public' and table_name='purchase_items' and column_name='received_quantity')='numeric','purchase_items.received_quantity is numeric');
select ok((select check_clause like '%received_quantity%quantity%' from information_schema.check_constraints where constraint_name='purchase_items_received_check'),'purchase_items receipt bound exists');

select has_index('public','products','uq_products_school_barcode','barcode index exists');
select has_index('public','stock_movements','ix_stock_movements_product_location_date','stock movement index exists');
select has_index('public','purchase_invoices','ix_purchase_invoices_school_status','purchase invoice index exists');

-- Les tables sensibles doivent être RLS.
select ok((select relrowsecurity from pg_class where oid='public.purchase_requests'::regclass),'purchase_requests RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.purchase_receipts'::regclass),'purchase_receipts RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.stock_transfers'::regclass),'stock_transfers RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.purchase_invoices'::regclass),'purchase_invoices RLS enabled');

-- Grants : authenticated ne doit pas écrire directement dans les tables sensibles.
select ok(not has_table_privilege('authenticated','public.products','insert'),'authenticated cannot insert products directly');
select ok(not has_table_privilege('authenticated','public.stock_movements','insert'),'authenticated cannot insert stock movements directly');
select ok(not has_table_privilege('authenticated','public.purchase_orders','insert'),'authenticated cannot insert purchase orders directly');
select ok(not has_table_privilege('authenticated','public.purchase_invoices','insert'),'authenticated cannot insert purchase invoices directly');

select * from finish();
rollback;
