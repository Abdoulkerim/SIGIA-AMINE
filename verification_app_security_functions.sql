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
WHERE n.nspname = 'app'
  AND (
      (p.proname = 'has_permission'
       AND pg_get_function_identity_arguments(p.oid)
           = 'p_code text, p_school_id uuid')
      OR
      (p.proname = 'has_role_code'
       AND pg_get_function_identity_arguments(p.oid)
           = 'p_code text, p_school_id uuid')
      OR
      (p.proname = 'is_super_admin'
       AND pg_get_function_identity_arguments(p.oid) = '')
  )
ORDER BY p.proname;
