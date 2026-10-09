$ErrorActionPreference = 'Stop'
Write-Host '=== SIGIA-AMINE — VALIDATION ÉTAPE 7 : ADMISSIONS ===' -ForegroundColor Cyan

Write-Host '1/6 — Statut Supabase local' -ForegroundColor Yellow
npx supabase status

Write-Host '2/6 — Reconstruction base locale (migrations + seed)' -ForegroundColor Yellow
npx supabase db reset

Write-Host '3/6 — Tests pgTAP' -ForegroundColor Yellow
npx supabase test db --local

Write-Host '4/6 — Lint PostgreSQL' -ForegroundColor Yellow
npx supabase db lint --local

Write-Host '5/6 — Génération des types TypeScript' -ForegroundColor Yellow
npx supabase gen types typescript --local > src/types/database.types.ts

Write-Host '6/6 — Contrôles frontend' -ForegroundColor Yellow
npm run typecheck
npm run build

Write-Host '=== ÉTAPE 7 VALIDÉE TECHNIQUEMENT ===' -ForegroundColor Green
Write-Host 'Lance ensuite : npm run dev' -ForegroundColor Green
