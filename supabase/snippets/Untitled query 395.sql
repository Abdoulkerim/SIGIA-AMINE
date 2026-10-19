SELECT
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'assign_subject_to_level',
      'set_subject_level_active',
      'assign_subject_to_class',
      'set_subject_class_active'
  )
ORDER BY p.proname;