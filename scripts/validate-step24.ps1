$ErrorActionPreference = 'Stop'
Write-Host 'SIGIA-AMINE - Validation Etape 24 - Statistiques / Dashboards' -ForegroundColor Cyan
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host 'Etape 24 : validation technique locale terminée.' -ForegroundColor Green
