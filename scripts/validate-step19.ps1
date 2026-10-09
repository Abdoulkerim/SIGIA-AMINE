$ErrorActionPreference = "Stop"
Write-Host "=== SIGIA-AMINE / Étape 19 — validation ===" -ForegroundColor Cyan
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host "Validation Étape 19 terminée." -ForegroundColor Green
