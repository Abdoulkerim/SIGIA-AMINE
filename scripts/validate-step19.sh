#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '=== SIGIA-AMINE / Étape 19 — validation ==='
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
printf '%s\n' 'Validation Étape 19 terminée.'
