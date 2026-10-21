-- SIGIA-AMINE — Étape 18 : Personnel / RH / Paie
begin;
select plan(52);

select has_table('public','employees','employees existe');
select has_table('public','employee_contracts','employee_contracts existe');
select has_table('public','employee_attendance','employee_attendance existe');
select has_table('public','employee_leaves','employee_leaves existe');
select has_table('public','employee_skills','employee_skills existe');
select has_table('public','employee_trainings','employee_trainings existe');
select has_table('public','payroll_periods','payroll_periods existe');
select has_table('public','payroll_items','payroll_items existe');

select has_column('public','employees','employee_number','numero employe');
select has_column('public','employees','job_title','fonction');
select has_column('public','employees','department','service');
select has_column('public','employees','hire_date','date embauche');
select has_column('public','employee_contracts','salary','salaire contractuel');
select has_column('public','employee_attendance','attendance_date','date presence');
select has_column('public','employee_leaves','status','statut conge');
select has_column('public','employee_skills','skill_name','competence');
select has_column('public','employee_trainings','title','formation');
select has_column('public','payroll_periods','status','statut paie');
select has_column('public','payroll_items','net_salary','net paie');
select has_column('public','payroll_items','paid_at','date paiement');

select has_function('public','create_employee',array['text','text','text','text','text','text','date','app.gender_type','date','text','text','text','text'],'RPC creation employe');
select has_function('public','create_employee_contract',array['uuid','text','date','date','numeric','uuid','text'],'RPC contrat');
select has_function('public','record_employee_attendance',array['uuid','date','app.attendance_status','time','time','text'],'RPC presence personnel');
select has_function('public','request_employee_leave',array['uuid','text','date','date','text'],'RPC demande conge');
select has_function('public','decide_employee_leave',array['uuid','app.approval_status','text'],'RPC decision conge');
select has_function('public','add_employee_skill',array['uuid','text','text','date','text'],'RPC competence');
select has_function('public','add_employee_training',array['uuid','text','text','date','date','text','text','text'],'RPC formation');
select has_function('public','create_payroll_period',array['text','date','date'],'RPC periode paie');
select has_function('public','generate_payroll',array['uuid'],'RPC generation paie');
select has_function('public','update_payroll_item',array['uuid','numeric','numeric','numeric','text'],'RPC modification ligne paie');
select has_function('public','approve_payroll',array['uuid'],'RPC validation paie');
select has_function('public','mark_payroll_item_paid',array['uuid'],'RPC paiement paie');
select has_function('public','close_payroll',array['uuid'],'RPC cloture paie');
select has_function('public','get_hr_dashboard',array['uuid','date'],'dashboard RH');
select has_function('public','get_employee_dossier',array['uuid'],'dossier employe');

select has_index('public','employee_contracts','idx_employee_contracts_employee_dates','index contrats dates');
select has_index('public','employee_attendance','idx_employee_attendance_school_date_employee','index presence personnel');
select has_index('public','employee_leaves','idx_employee_leaves_school_dates_status','index conges');
select has_index('public','payroll_periods','idx_payroll_periods_school_dates','index periodes paie');
select has_index('public','payroll_items','idx_payroll_items_period_employee_status','index lignes paie');

select policies_are('public','payroll_periods',array['education_stage_boundary','payroll_periods_select_026'],'RLS periodes paie');
select policies_are('public','payroll_items',array['payroll_items_select_026'],'RLS lignes paie');
select policies_are('public','employee_leaves',array['education_stage_boundary','employee_leaves_select_026'],'RLS conges');
select policies_are('public','employee_attendance',array['education_stage_boundary','employee_attendance_select_026'],'RLS presence personnel');

select ok((select not exists(
  select 1 from information_schema.role_table_grants
  where grantee='anon' and table_schema='public' and table_name='payroll_items' and privilege_type='SELECT'
)),'anon ne lit pas la paie');
select ok((select not exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and table_name='employees' and privilege_type='INSERT')),'pas d insertion directe employes');
select ok((select not exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and table_name='employee_contracts' and privilege_type='INSERT')),'pas d insertion directe contrats');
select ok((select not exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and table_name='employee_attendance' and privilege_type='INSERT')),'pas d insertion directe presence');
select ok((select not exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and table_name='employee_leaves' and privilege_type='INSERT')),'pas d insertion directe conges');
select ok((select not exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and table_name='payroll_periods' and privilege_type='INSERT')),'pas d insertion directe periodes paie');
select ok((select not exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and table_name='payroll_items' and privilege_type='INSERT')),'pas d insertion directe lignes paie');
select has_column('public','employee_leaves','decision_note','note de decision conge');

select * from finish();
rollback;
