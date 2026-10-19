SELECT
    p.proname AS fonction,
    pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'get_dashboard_direction',
      'get_dashboard_activities'
  )
ORDER BY p.proname;