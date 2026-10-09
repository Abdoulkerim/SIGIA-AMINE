begin;
select plan(11);

select has_table('public','enrollments','table enrollments existe');
select has_column('public','enrollments','registration_number','registration_number existe');
select has_column('public','enrollments','requested_level_id','requested_level_id existe');
select has_column('public','enrollments','source_admission_id','source_admission_id existe');
select has_function('public', 'prepare_enrollment_from_admission', ARRAY['uuid','app.relationship_type'], 'RPC admission -> inscription existe');
select has_function('public', 'create_reenrollment_draft', ARRAY['uuid','uuid','app.residence_type'], 'RPC réinscription existe');
select has_function('public', 'finalize_enrollment', ARRAY['uuid','uuid'], 'RPC finalisation inscription existe');
select has_index('public','enrollments','uq_enrollments_school_registration_number','index numéro inscription existe');
select has_index('public','enrollments','uq_enrollments_school_source_admission','index source admission existe');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='enrollments' and policyname='enrollments_select_016'),'policy lecture inscriptions existe');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='enrollments' and policyname='enrollments_insert_016'),'policy création inscriptions existe');

select * from finish();
rollback;
