-- SIGIA-AMINE — Test contract ÉTAPE 9 — Niveaux / Classes

begin;

select plan(19);

select has_table('public', 'levels', 'levels existe');
select has_table('public', 'classes', 'classes existe');

select has_column('public', 'levels', 'school_id', 'levels.school_id');
select has_column('public', 'levels', 'code', 'levels.code');
select has_column('public', 'levels', 'name', 'levels.name');
select has_column('public', 'levels', 'education_cycle', 'levels.education_cycle');

select has_column('public', 'classes', 'school_id', 'classes.school_id');
select has_column('public', 'classes', 'school_year_id', 'classes.school_year_id');
select has_column('public', 'classes', 'level_id', 'classes.level_id');
select has_column('public', 'classes', 'capacity', 'classes.capacity');
select has_column('public', 'classes', 'section', 'classes.section');

select has_function('public', 'create_level', ARRAY['text','text','text','integer'], 'RPC create_level existe');
select has_function('public', 'update_level', ARRAY['uuid','text','text','text','integer'], 'RPC update_level existe');
select has_function('public', 'set_level_active', ARRAY['uuid','boolean'], 'RPC set_level_active existe');
select has_function('public', 'create_class', ARRAY['uuid','uuid','text','text','text','text','integer'], 'RPC create_class existe');
select has_function('public', 'update_class', ARRAY['uuid','uuid','uuid','text','text','text','text','integer'], 'RPC update_class existe');
select has_function('public', 'set_class_active', ARRAY['uuid','boolean'], 'RPC set_class_active existe');

select has_index('public', 'levels', 'uq_levels_school_code_ci', 'unicité code niveau');
select has_index('public', 'classes', 'uq_classes_school_year_code_ci', 'unicité code classe');

select * from finish();
rollback;
