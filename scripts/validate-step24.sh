#!/usr/bin/env bash
set -euo pipefail
echo 'SIGIA-AMINE - Validation Etape 24 - Statistiques / Dashboards'
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
echo 'Etape 24 : validation technique locale terminée.'
