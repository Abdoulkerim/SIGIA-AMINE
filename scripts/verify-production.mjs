import process from 'node:process'

const baseUrl = process.argv[2] || process.env.PRODUCTION_APP_URL
if (!baseUrl) {
  console.error('Usage: node scripts/verify-production.mjs https://app.example.com')
  process.exit(2)
}

const url = new URL('/api/health', baseUrl).toString()
const response = await fetch(url, {
  headers: { accept: 'application/json' },
})

let body = null
try { body = await response.json() } catch {}

console.log('Health URL:', url)
console.log('HTTP status:', response.status)
console.log('Body:', JSON.stringify(body))

if (!response.ok || !body?.ok) process.exit(1)
console.log('Production smoke test OK.')
