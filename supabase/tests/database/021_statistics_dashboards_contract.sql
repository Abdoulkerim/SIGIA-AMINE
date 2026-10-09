-- STEP 24 — contrat Statistiques / Dashboards
begin;
select plan(29);

select ok(exists(select 1 from public.permissions where code='dashboard.direction'),'permission dashboard.direction');
select ok(exists(select 1 from public.permissions where code='dashboard.pedagogy'),'permission dashboard.pedagogy');
select ok(exists(select 1 from public.permissions where code='dashboard.finance'),'permission dashboard.finance');
select ok(exists(select 1 from public.permissions where code='dashboard.boarding'),'permission dashboard.boarding');
select ok(exists(select 1 from public.permissions where code='dashboard.activities'),'permission dashboard.activities');

select ok(to_regprocedure('public.get_available_dashboards(uuid)') is not null,'rpc get_available_dashboards existe');
select ok(to_regprocedure('public.get_dashboard_direction(uuid)') is not null,'rpc get_dashboard_direction existe');
select ok(to_regprocedure('public.get_dashboard_pedagogy(uuid)') is not null,'rpc get_dashboard_pedagogy existe');
select ok(to_regprocedure('public.get_dashboard_finance(uuid)') is not null,'rpc get_dashboard_finance existe');
select ok(to_regprocedure('public.get_dashboard_boarding(uuid)') is not null,'rpc get_dashboard_boarding existe');
select ok(to_regprocedure('public.get_dashboard_activities(uuid)') is not null,'rpc get_dashboard_activities existe');

select ok(has_function_privilege('public.get_dashboard_direction(uuid)','execute'),'direction dashboard executable par le rôle de test');
select ok(has_function_privilege('public.get_dashboard_pedagogy(uuid)','execute'),'pedagogy dashboard executable par le rôle de test');
select ok(has_function_privilege('public.get_dashboard_finance(uuid)','execute'),'finance dashboard executable par le rôle de test');
select ok(has_function_privilege('public.get_dashboard_boarding(uuid)','execute'),'boarding dashboard executable par le rôle de test');
select ok(has_function_privilege('public.get_dashboard_activities(uuid)','execute'),'activities dashboard executable par le rôle de test');

select ok(not has_function_privilege('anon','public.get_dashboard_direction(uuid)','execute'),'anon ne peut pas exécuter direction dashboard');
select ok(not has_function_privilege('anon','public.get_dashboard_pedagogy(uuid)','execute'),'anon ne peut pas exécuter pedagogy dashboard');
select ok(not has_function_privilege('anon','public.get_dashboard_finance(uuid)','execute'),'anon ne peut pas exécuter finance dashboard');
select ok(not has_function_privilege('anon','public.get_dashboard_boarding(uuid)','execute'),'anon ne peut pas exécuter boarding dashboard');
select ok(not has_function_privilege('anon','public.get_dashboard_activities(uuid)','execute'),'anon ne peut pas exécuter activities dashboard');

select ok(exists(select 1 from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where r.code='direction' and p.code='dashboard.direction'),'direction reçoit dashboard.direction');
select ok(exists(select 1 from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where r.code='accountant' and p.code='dashboard.finance'),'comptable reçoit dashboard.finance');
select ok(exists(select 1 from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where r.code='boarding_manager' and p.code='dashboard.boarding'),'internat reçoit dashboard.boarding');
select ok(exists(select 1 from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where r.code='teacher' and p.code='dashboard.pedagogy'),'enseignant reçoit dashboard.pedagogy');

select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='ix_report_cards_dashboard_school_year_status'),'index report cards dashboard');
select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='ix_attendance_sessions_dashboard_school_date'),'index attendance sessions dashboard');
select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='ix_payments_dashboard_school_date_status'),'index payments dashboard');
select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='ix_boarding_assignments_dashboard_school_status'),'index boarding dashboard');

select * from finish();
rollback;
