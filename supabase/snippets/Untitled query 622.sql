
SELECT
    to_regclass('public.subject_level_assignments')
        AS expected_table,
    to_regclass('public.subject_level_assignments_legacy')
        AS legacy_table;
