#!/usr/bin/env bash
set -euo pipefail

echo '=== SIGIA-AMINE — VALIDATION ÉTAPE 7 : ADMISSIONS ==='
npx supabase status
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build

echo '=== ÉTAPE 7 VALIDÉE TECHNIQUEMENT ==='
echo 'Lance ensuite : npm run dev'
