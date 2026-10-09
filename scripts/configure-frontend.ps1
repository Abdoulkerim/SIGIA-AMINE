Write-Host 'Installation des dépendances frontend SIGIA-AMINE...' -ForegroundColor Cyan
npm install next@latest react@latest react-dom@latest @supabase/ssr @supabase/supabase-js zod
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
npm install --save-dev typescript @types/node @types/react @types/react-dom
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

npm pkg set scripts.dev='next dev' scripts.build='next build' scripts.start='next start' scripts.typecheck='tsc --noEmit' scripts.'supabase:types'='supabase gen types typescript --local > src/types/database.types.ts' scripts.'supabase:bootstrap-admin'='node scripts/bootstrap-admin.mjs'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '✅ Dépendances et scripts frontend configurés.' -ForegroundColor Green
