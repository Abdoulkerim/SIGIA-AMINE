import process from 'node:process'

const required = [
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
]

const forbiddenPublicPatterns = [
  /^NEXT_PUBLIC_.*(SECRET|SERVICE|PASSWORD|TOKEN|PRIVATE|OPENAI)/i,
]

const missing = required.filter((name) => !process.env[name])
const publicSecretLike = Object.keys(process.env).filter((name) =>
  forbiddenPublicPatterns.some((pattern) => pattern.test(name)),
)

if (missing.length || publicSecretLike.length) {
  console.error('Production preflight failed.')
  if (missing.length) console.error('Missing:', missing.join(', '))
  if (publicSecretLike.length) console.error('Potentially unsafe NEXT_PUBLIC variables:', publicSecretLike.join(', '))
  process.exit(1)
}

console.log('Production preflight OK.')
console.log('Supabase URL:', process.env.NEXT_PUBLIC_SUPABASE_URL)
console.log('Publishable key present: yes')
