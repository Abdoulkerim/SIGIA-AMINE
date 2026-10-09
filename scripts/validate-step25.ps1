$ErrorActionPreference = 'Stop'
Write-Host '=== SIGIA-AMINE — Validation Étape 25 IA ==='
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host 'Validation Étape 25 terminée. Pour le test fonctionnel local :'
Write-Host 'supabase functions serve ai-assistant --env-file supabase/functions/.env'
