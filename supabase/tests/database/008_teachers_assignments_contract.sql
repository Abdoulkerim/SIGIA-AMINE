-- SIGIA-AMINE — Test contract ÉTAPE 11 — Enseignants / Affectations

begin;

select plan(24);

select has_table('public', 'employees', 'employees existe');
select has_table('public', 'teacher_profiles', 'teacher_profiles existe');
select has_table('public', 'teacher_assignments', 'teacher_assignments existe');

select has_column('public', 'employees', 'employee_number', 'employee_number');
select has_column('public', 'employees', 'school_id', 'employees.school_id');
select has_column('public', 'teacher_profiles', 'employee_id', 'teacher_profiles.employee_id');
select has_column('public', 'teacher_assignments', 'school_year_id', 'teacher_assignments.school_year_id');
select has_column('public', 'teacher_assignments', 'teacher_id', 'teacher_assignments.teacher_id');
select has_column('public', 'teacher_assignments', 'class_id', 'teacher_assignments.class_id');
select has_column('public', 'teacher_assignments', 'subject_id', 'teacher_assignments.subject_id');
select has_column('public', 'teacher_assignments', 'weekly_hours', 'teacher_assignments.weekly_hours');
select has_column('public', 'teacher_assignments', 'is_primary', 'teacher_assignments.is_primary');

select has_function('public', 'create_teacher', ARRAY['text','text','text','app.gender_type','date','text','text','text','text','text','date','text','text','text','text'], 'RPC create_teacher existe');
select has_function('app', 'employee_is_teacher', ARRAY['uuid'], 'helper employee_is_teacher existe');
select has_function('app', 'teacher_assignment_belongs_to_user', ARRAY['uuid','uuid'], 'helper teacher_assignment_belongs_to_user existe');
select has_function('public', 'update_teacher', ARRAY['uuid','text','text','text','app.gender_type','date','text','text','text','text','text','date','text','text','text','text'], 'RPC update_teacher existe');
select has_function('public', 'set_teacher_active', ARRAY['uuid','boolean'], 'RPC set_teacher_active existe');
select has_function('public', 'assign_teacher', ARRAY['uuid','uuid','uuid','uuid','numeric','boolean'], 'RPC assign_teacher existe');
select has_function('public', 'set_teacher_assignment_active', ARRAY['uuid','boolean'], 'RPC set_teacher_assignment_active existe');

select has_index('public', 'employees', 'uq_employees_school_number_ci', 'unicité numéro employé');
select has_index('public', 'teacher_assignments', 'uq_teacher_primary_assignment', 'unicité affectation principale');
select has_index('public', 'teacher_assignments', 'idx_teacher_assignments_school_year_teacher_active', 'index enseignant année');
select has_index('public', 'teacher_assignments', 'idx_teacher_assignments_school_year_class_active', 'index classe année');
select has_index('public', 'teacher_assignments', 'idx_teacher_assignments_school_year_subject_active', 'index matière année');

select * from finish();
rollback;
