-- SIGIA-AMINE — contrat structurel Étape 7 Admissions
begin;
select plan(12);

select has_table('public', 'admission_applications', 'admission_applications existe');
select has_column('public', 'admission_applications', 'candidate_first_name', 'candidate_first_name existe');
select has_column('public', 'admission_applications', 'candidate_last_name', 'candidate_last_name existe');
select has_column('public', 'admission_applications', 'desired_level_label', 'desired_level_label existe');
select has_column('public', 'admission_applications', 'primary_parent_id', 'primary_parent_id existe');
select has_column('public', 'admission_applications', 'updated_at', 'updated_at existe');
select has_index('public', 'admission_applications', 'idx_admission_school_status_created', 'index statut admission existe');
select has_index('public', 'admission_applications', 'idx_admission_school_year_status', 'index année admission existe');
select has_index('public', 'admission_applications', 'idx_admission_candidate_name', 'index recherche candidat existe');
select has_function('app', 'validate_admission_status_transition', ARRAY[]::text[], 'fonction transition admission existe');
select has_function('app', 'validate_admission_cross_school', ARRAY[]::text[], 'fonction cross-school admission existe');
select has_function('app', 'validate_admission_review_fields', ARRAY[]::text[], 'fonction review admission existe');

select * from finish();
rollback;
