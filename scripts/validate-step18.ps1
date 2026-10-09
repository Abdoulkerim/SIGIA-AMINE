$ErrorActionPreference = 'Stop'
Write-Host '=== SIGIA-AMINE — Validation Étape 18 ===' -ForegroundColor Cyan

Write-Host '1/6 — Supabase DB reset'
npx supabase db reset

Write-Host '2/6 — Tests DB'
npx supabase test db --local

Write-Host '3/6 — DB lint'
npx supabase db lint --local

Write-Host '4/6 — Génération des types'
npx supabase gen types typescript --local > src/types/database.types.ts

Write-Host '5/6 — Typecheck'
npm run typecheck

Write-Host '6/6 — Build'
npm run build

Write-Host 'Validation Étape 18 terminée avec succès.' -ForegroundColor Green
