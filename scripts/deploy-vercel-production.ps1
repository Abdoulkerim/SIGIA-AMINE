param(
  [string]$ProjectName = 'sigia-amine'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  throw 'Vercel CLI introuvable.'
}

Write-Host 'Vercel production deployment: prefer GitHub -> Vercel integration for repeatability.'
vercel deploy --prod --yes --name $ProjectName
