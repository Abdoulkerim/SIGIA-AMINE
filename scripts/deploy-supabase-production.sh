#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${1:-}"
INCLUDE_SEED="${2:-false}"
if [[ -z "$PROJECT_REF" ]]; then
  echo "Usage: ./scripts/deploy-supabase-production.sh <project-ref> [true|false]" >&2
  exit 2
fi

command -v supabase >/dev/null 2>&1 || { echo 'Supabase CLI introuvable.' >&2; exit 1; }

úmero=0
supabase link --project-ref "$PROJECT_REF"
if [[ "$INCLUDE_SEED" == "true" ]]; then
  supabase db push --include-seed
else
  supabase db push
fi
supabase functions deploy --project-ref "$PROJECT_REF"
echo 'Production database/functions deployed.'
