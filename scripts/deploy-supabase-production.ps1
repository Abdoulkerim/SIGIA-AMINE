param(
  [Parameter(Mandatory = $true)] [string]$ProjectRef,
  [switch]$IncludeSeed
)

$ErrorActionPreference = 'Stop'

Write-Host '== SIGIA-AMINE / Supabase production deployment =='
Write-Host "Project: $ProjectRef"

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI introuvable.'
}

Write-Host '1) Link project'
supabase link --project-ref $ProjectRef

Write-Host '2) Push migrations'
if ($IncludeSeed) {
  supabase db push --include-seed
} else {
  supabase db push
}

Write-Host '3) Deploy Edge Functions'
supabase functions deploy --project-ref $ProjectRef

Write-Host ''
Write-Host 'Production database/functions deployed.'
Write-Host 'Configure OPENAI_API_KEY separately with Supabase secrets set or Dashboard before validating the IA.'
