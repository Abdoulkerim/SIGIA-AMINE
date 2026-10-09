Write-Host 'Génération des types TypeScript depuis Supabase local...' -ForegroundColor Cyan
npx supabase gen types typescript --local > src/types/database.types.ts
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host '✅ src/types/database.types.ts a été généré.' -ForegroundColor Green
