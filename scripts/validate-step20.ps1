$ErrorActionPreference = 'Stop'
Write-Host "== SIGIA-AMINE Etape 20 : validation ==" -ForegroundColor Cyan
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
Write-Host "Etape 20 validee techniquement : lancer npm run dev pour les tests fonctionnels." -ForegroundColor Green
