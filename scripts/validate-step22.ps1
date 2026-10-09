$ErrorActionPreference = 'Stop'
Write-Host 'SIGIA-AMINE — Validation Étape 22' -ForegroundColor Cyan
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host 'Étape 22 : validation technique terminée.' -ForegroundColor Green
