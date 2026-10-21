-- SIGIA-AMINE — Test contract ÉTAPE 12 — Dossier élève complet

begin;

select plan(16);

select has_table('public', 'students', 'students existe');
select has_table('public', 'student_parents', 'student_parents existe');
select has_table('public', 'enrollments', 'enrollments existe');
select has_table('public', 'enrollment_history', 'enrollment_history existe');
select has_table('public', 'documents', 'documents existe');
select has_table('public', 'teacher_assignments', 'teacher_assignments existe');

select has_function('public', 'get_student_dossier', ARRAY['uuid'], 'RPC dossier élève existe');

select has_index('public', 'student_parents', 'idx_student_parents_parent_student', 'index parents -> élèves');
select has_index('public', 'authorized_pickup_persons', 'idx_authorized_pickup_student_active', 'index personnes autorisées');
select has_index('public', 'admission_applications', 'idx_admission_student_year', 'index admissions -> élève');
select has_index('public', 'enrollment_history', 'idx_enrollment_history_student_changed', 'index historique inscription');
select has_index('public', 'teacher_assignments', 'idx_teacher_assignments_teacher_class_year', 'index affectations enseignant');

select policies_are(
  'public',
  'students',
  ARRAY[
    'students_insert_staff',
    'students_select_scoped',
    'students_update_staff',
    'education_stage_boundary'
  ],
  'RLS students : policies attendues'
);

select policies_are(
  'public',
  'documents',
  ARRAY[
    'documents_select_scoped',
    'documents_insert_secure',
    'documents_update_secure',
    'documents_delete_secure',
    'education_stage_boundary'
  ],
  'RLS documents : policies attendues'
);

select policies_are(
  'public',
  'enrollment_history',
  ARRAY[
    'enrollment_history_secure',
    'enrollment_history_manage',
    'education_stage_boundary'
  ],
  'RLS historique inscription : policies attendues'
);

select 1 as ok \gset
select is(:ok, 1, 'contrat dossier élève chargé');

select * from finish();
rollback;
