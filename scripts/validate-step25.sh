#!/usr/bin/env bash
set -euo pipefail
echo '=== SIGIA-AMINE — Validation Étape 25 IA ==='
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
echo 'Validation Étape 25 terminée.'
