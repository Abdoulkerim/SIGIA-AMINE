$ErrorActionPreference = 'Stop'
Write-Host '=== SIGIA-AMINE — VALIDATION ÉTAPE 14 : VIE SCOLAIRE ===' -ForegroundColor Cyan
Write-Host '1/7 — Statut Supabase local' -ForegroundColor Yellow
npx supabase status
Write-Host '2/7 — Reset migrations + seed' -ForegroundColor Yellow
npx supabase db reset
Write-Host '3/7 — Tests database' -ForegroundColor Yellow
npx supabase test db --local
Write-Host '4/7 — Lint database' -ForegroundColor Yellow
npx supabase db lint --local
Write-Host '5/7 — Génération des types' -ForegroundColor Yellow
npx supabase gen types typescript --local > src/types/database.types.ts
Write-Host '6/7 — Typecheck' -ForegroundColor Yellow
npm run typecheck
Write-Host '7/7 — Build' -ForegroundColor Yellow
npm run build
Write-Host '=== ÉTAPE 14 — VALIDATION TECHNIQUE TERMINÉE ===' -ForegroundColor Green
Write-Host 'Lance ensuite : npm run dev' -ForegroundColor Green
