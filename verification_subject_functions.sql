SELECT
    p.proname AS function_name,
    has_function_privilege(
        'anon', p.oid, 'EXECUTE'
    ) AS anon_can_execute,
    has_function_privilege(
        'authenticated', p.oid, 'EXECUTE'
    ) AS authenticated_can_execute
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'create_subject',
    'update_subject',
    'set_subject_active',
    'assign_subject_to_class',
    'set_subject_class_active'
  )
ORDER BY p.proname;
