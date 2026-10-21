-- SIGIA-AMINE
-- Étape 16 — Internat : tests contractuels
begin;

select plan(36);

select has_table('public','boarding_buildings','boarding_buildings exists');
select has_table('public','boarding_dormitories','boarding_dormitories exists');
select has_table('public','boarding_rooms','boarding_rooms exists');
select has_table('public','boarding_beds','boarding_beds exists');
select has_table('public','boarding_assignments','boarding_assignments exists');
select has_table('public','boarding_movements','boarding_movements exists');
select has_table('public','boarding_attendance','boarding_attendance exists');

select has_function('public','create_boarding_building',array['uuid','text','text','text'],'building RPC exists');
select has_function('public','create_boarding_dormitory',array['uuid','text','app.gender_type','uuid'],'dormitory RPC exists');
select has_function('public','create_boarding_room',array['uuid','text','integer','text','text'],'room RPC exists');
select has_function('public','create_boarding_bed',array['uuid','text','text'],'bed RPC exists');
select has_function('public','assign_boarding_bed',array['uuid','uuid','date','date','text'],'assignment RPC exists');
select has_function('public','close_boarding_assignment',array['uuid','date','text'],'close assignment RPC exists');
select has_function('public','record_boarding_movement',array['uuid','text','timestamptz','text','text','text','text'],'movement RPC exists');
select has_function('public','set_boarding_attendance',array['uuid','date','app.attendance_status','text'],'attendance RPC exists');
select has_function('public','get_boarding_dashboard',array['uuid'],'dashboard RPC exists');
select has_function('public','get_student_boarding',array['uuid'],'student boarding RPC exists');

select has_index('public','boarding_buildings','ux_boarding_buildings_school_lower_code','case-insensitive building code uniqueness');
select has_index('public','boarding_dormitories','ux_boarding_dormitories_building_lower_name','dormitory name uniqueness');
select has_index('public','boarding_rooms','ux_boarding_rooms_dormitory_lower_name','room name uniqueness');
select has_index('public','boarding_beds','ux_boarding_beds_room_lower_number','bed number uniqueness');
select has_index('public','boarding_assignments','uq_active_boarding_student','one active boarding assignment per student');
select has_index('public','boarding_assignments','uq_active_boarding_bed','one active boarding assignment per bed');

select ok(exists(select 1 from pg_constraint where conrelid='public.boarding_rooms'::regclass and conname='boarding_rooms_status_ck' and contype='c'),'room status constrained');
select ok(exists(select 1 from pg_constraint where conrelid='public.boarding_beds'::regclass and conname='boarding_beds_status_ck' and contype='c'),'bed status constrained');
select ok(exists(select 1 from pg_constraint where conrelid='public.boarding_assignments'::regclass and conname='boarding_assignments_status_ck' and contype='c'),'assignment status constrained');

select policies_are('public','boarding_buildings',array['boarding_buildings_select_secure','education_stage_boundary'],'building RLS is read-only through table API');
select policies_are('public','boarding_dormitories',array['boarding_dormitories_select_secure'],'dormitory RLS is read-only through table API');
select policies_are('public','boarding_rooms',array['boarding_rooms_select_secure'],'room RLS is read-only through table API');
select policies_are('public','boarding_beds',array['boarding_beds_select_secure'],'bed RLS is read-only through table API');
select policies_are('public','boarding_assignments',array['boarding_assignments_select_secure','education_stage_boundary'],'assignment RLS is read-only through table API');
select policies_are('public','boarding_movements',array['boarding_movements_select_secure','education_stage_boundary'],'movement RLS is read-only through table API');
select policies_are('public','boarding_attendance',array['boarding_attendance_select_secure','education_stage_boundary'],'attendance RLS is read-only through table API');

select ok((select not exists(
  select 1 from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and table_name='boarding_assignments' and privilege_type='INSERT'
)),'authenticated cannot insert boarding assignments directly');
select ok((select not exists(
  select 1 from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and table_name='boarding_movements' and privilege_type='INSERT'
)),'authenticated cannot insert boarding movements directly');
select ok((select not exists(
  select 1 from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and table_name='boarding_attendance' and privilege_type='INSERT'
)),'authenticated cannot insert boarding attendance directly');

select * from finish();
rollback;
