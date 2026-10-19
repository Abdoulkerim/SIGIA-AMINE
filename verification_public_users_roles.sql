SELECT
    table_name,
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('users', 'user_roles')
  AND grantee = 'PUBLIC'
ORDER BY table_name, privilege_type;
