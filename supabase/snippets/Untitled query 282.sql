
-- 1. Vérifier les colonnes de la table historique
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'subject_level_assignments_legacy'
ORDER BY ordinal_position;

-- 2. Vérifier les contraintes et les clés de cette table
SELECT
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.subject_level_assignments_legacy'::regclass
ORDER BY conname;
