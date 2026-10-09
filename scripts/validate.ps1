$ErrorActionPreference = "Stop"
Write-Host "[1/4] Supabase local start"
npx supabase start
Write-Host "[2/4] Database reset from migrations"
npx supabase db reset
Write-Host "[3/4] Database tests"
npx supabase test db
Write-Host "[4/4] Database lint"
npx supabase db lint
Write-Host "SIGIA-AMINE VALIDATION OK" -ForegroundColor Green
