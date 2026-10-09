$ErrorActionPreference = 'Stop'
Write-Host 'SIGIA-AMINE — validation Etape 16 / Internat'
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host 'Validation technique Etape 16 terminee avec succes.'
