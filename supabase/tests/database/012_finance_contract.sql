-- SIGIA-AMINE
-- Etape 15 - finance contract tests
begin;

select plan(27);

select has_table('public','fee_types', 'fee_types exists');
select has_table('public','fee_schedules', 'fee_schedules exists');
select has_table('public','student_charges', 'student_charges exists');
select has_table('public','invoices', 'invoices exists');
select has_table('public','invoice_items', 'invoice_items exists');
select has_table('public','payments', 'payments exists');
select has_table('public','payment_allocations', 'payment_allocations exists');
select has_table('public','receipts', 'receipts exists');
select has_table('public','expenses', 'expenses exists');
select has_table('public','cash_accounts', 'cash_accounts exists');
select has_table('public','cash_transactions', 'cash_transactions exists');
select has_table('public','cash_closings', 'cash_closings exists');
select has_table('public','collection_reminders', 'collection_reminders exists');
select has_function('public','create_invoice', array['uuid','uuid','date','date','text','jsonb'], 'create_invoice RPC exists');
select has_function('public','record_payment', array['uuid','uuid','numeric','timestamptz','app.payment_method','text','text','jsonb','uuid'], 'record_payment RPC exists');
select has_function('public','approve_expense', array['uuid','uuid'], 'approve_expense RPC exists');
select has_function('public','get_finance_dashboard', array['uuid'], 'finance dashboard RPC exists');
select has_index('public','fee_types','ux_fee_types_school_lower_code', 'fee type code uniqueness index exists');
select has_index('public','payments','ix_payments_school_date', 'payment date index exists');
select has_index('public','expenses','ix_expenses_school_date_status', 'expense date/status index exists');
select has_index('public','cash_transactions','ix_cash_transactions_account_date', 'cash transaction index exists');
select policies_are('public','invoices', ARRAY['education_stage_boundary','invoices_select_scoped_v2'], 'invoice RLS is read-only through table API');
select policies_are('public','payments', ARRAY['education_stage_boundary','payments_select_scoped_v2'], 'payment RLS is read-only through table API');
select policies_are('public','cash_transactions', ARRAY['cash_transactions_select_scoped','education_stage_boundary'], 'cash transactions are read-only through table API');
select policies_are('public','expenses', ARRAY['education_stage_boundary','expenses_select_scoped'], 'expenses are read-only through table API');
select has_column('public','invoice_items','line_total', 'invoice item line total column exists');
select ok(exists(select 1 from pg_constraint where conrelid='public.cash_accounts'::regclass and conname='cash_accounts_type_ck' and contype='c'),'cash account types constrained');

select * from finish();
rollback;
