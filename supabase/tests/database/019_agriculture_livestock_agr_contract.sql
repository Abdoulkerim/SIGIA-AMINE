-- SIGIA-AMINE — Contrat Étape 22 Agriculture / Élevage / AGR
-- À exécuter via: npx supabase test db --local

begin;
select plan(25);

select has_table('public','economic_activities','economic_activities existe');
select has_table('public','agriculture_campaigns','agriculture_campaigns existe');
select has_table('public','agriculture_expenses','agriculture_expenses existe');
select has_table('public','livestock','livestock existe');
select has_table('public','livestock_events','livestock_events existe');
select has_table('public','productions','productions existe');
select has_table('public','sales','sales existe');
select has_table('public','economic_activity_sites','economic_activity_sites existe');
select has_table('public','economic_activity_expenses','economic_activity_expenses existe');
select has_table('public','economic_activity_inputs','economic_activity_inputs existe');
select has_table('public','sale_items','sale_items existe');

select has_function('public','create_economic_activity','create_economic_activity existe');
select has_function('public','create_economic_activity_site','create_economic_activity_site existe');
select has_function('public','create_agriculture_campaign','create_agriculture_campaign existe');
select has_function('public','record_activity_input','record_activity_input existe');
select has_function('public','record_production','record_production existe');
select has_function('public','record_economic_activity_expense','record_economic_activity_expense existe');
select has_function('public','create_livestock','create_livestock existe');
select has_function('public','record_livestock_event','record_livestock_event existe');
select has_function('public','record_activity_sale','record_activity_sale existe');
select has_function('public','get_economic_activities_dashboard','dashboard économique existe');
select has_function('public','get_economic_activity_performance','performance activité existe');

select has_column('public','productions','product_id','productions -> stock product_id');
select has_column('public','sales','cash_transaction_id','sales -> finance cash transaction');
select has_column('public','livestock','quantity','livestock quantité');

select * from finish();
rollback;
