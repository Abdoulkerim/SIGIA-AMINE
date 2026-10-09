#!/usr/bin/env bash
set -euo pipefail
printf '\n=== SIGIA-AMINE — Validation Étape 18 ===\n'
printf '1/6 — Supabase DB reset\n'; npx supabase db reset
printf '2/6 — Tests DB\n'; npx supabase test db --local
printf '3/6 — DB lint\n'; npx supabase db lint --local
printf '4/6 — Génération des types\n'; npx supabase gen types typescript --local > src/types/database.types.ts
printf '5/6 — Typecheck\n'; npm run typecheck
printf '6/6 — Build\n'; npm run build
printf 'Validation Étape 18 terminée avec succès.\n'
