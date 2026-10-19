
SELECT
    dependent_ns.nspname AS dependent_schema,
    dependent.proname AS dependent_function,
    referenced.proname AS referenced_function
FROM pg_depend d
JOIN pg_proc dependent ON dependent.oid = d.objid
JOIN pg_namespace dependent_ns
    ON dependent_ns.oid = dependent.pronamespace
JOIN pg_proc referenced ON referenced.oid = d.refobjid
JOIN pg_namespace referenced_ns
    ON referenced_ns.oid = referenced.pronamespace
WHERE referenced_ns.nspname = 'public'
  AND referenced.proname IN (
      'assign_subject_to_level',
      'set_subject_level_active'
  )
  AND dependent.oid <> referenced.oid;
