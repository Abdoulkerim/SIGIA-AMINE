$ErrorActionPreference='Stop'
Write-Host 'SIGIA-AMINE — validation Étape 17 — Restauration'
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host 'Validation build/typecheck terminée. Lance npm run dev pour le test fonctionnel.'
