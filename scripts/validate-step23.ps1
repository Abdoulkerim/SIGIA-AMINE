$ErrorActionPreference = 'Stop'
Write-Host 'STEP 23 - Documents / Communication' -ForegroundColor Cyan
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host 'STEP 23 validation complete.' -ForegroundColor Green
