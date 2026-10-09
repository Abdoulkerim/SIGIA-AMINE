#!/usr/bin/env bash
set -euo pipefail
npx supabase db reset --local
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
