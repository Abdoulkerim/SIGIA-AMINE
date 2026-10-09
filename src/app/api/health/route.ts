import { NextResponse } from 'next/server'

export async function GET() {
  const required = [
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
  ] as const

  const missing = required.filter((name) => !process.env[name])
  const ok = missing.length === 0

  return NextResponse.json(
    {
      ok,
      service: 'SIGIA-AMINE',
      environment: process.env.NODE_ENV === 'production' ? 'production' : 'non-production',
    },
    {
      status: ok ? 200 : 503,
      headers: { 'Cache-Control': 'no-store' },
    },
  )
}
