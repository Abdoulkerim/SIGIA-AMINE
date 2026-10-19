SELECT
    schemaname,
    tablename,
    policyname,
    roles,
    cmd,
    qual AS using_expression,
    with_check AS check_expression
FROM pg_policies
WHERE
    concat_ws(' ', qual, with_check) ~*
    '(has_permission|has_role_code|is_super_admin)'
ORDER BY schemaname, tablename, policyname;
