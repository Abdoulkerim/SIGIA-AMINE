#!/usr/bin/env bash
set -euo pipefail
npx supabase start
npx supabase db reset
npx supabase test db
npx supabase db lint
echo "SIGIA-AMINE VALIDATION OK"
