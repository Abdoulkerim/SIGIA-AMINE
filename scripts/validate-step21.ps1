$ErrorActionPreference = "Stop"
Write-Host "=== SIGIA-AMINE Étape 21 — Wushu ==="
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host "Étape 21 — validation technique terminée."
