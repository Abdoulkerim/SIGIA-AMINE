
-- Vérifier les tables qui concernent les matières et les niveaux.
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
      table_name ILIKE '%subject%level%'
      OR table_name ILIKE '%level%subject%'
      OR table_name ILIKE '%subject%class%'
  )
ORDER BY table_name, ordinal_position;
