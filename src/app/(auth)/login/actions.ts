'use server'

import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export async function signIn(formData: FormData) {
  const email = String(formData.get('email') ?? '').trim()
  const password = String(formData.get('password') ?? '')
  const next = String(formData.get('next') ?? '/')

  if (!email || !password) {
    redirect(`/login?error=${encodeURIComponent('Email et mot de passe sont obligatoires.')}`)
  }

  const supabase = await createClient()
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })

  if (error || !data.user) {
    redirect(`/login?error=${encodeURIComponent('Identifiants invalides ou compte non configuré.')}`)
  }

  const { data: profile } = await supabase
    .from('users')
    .select('status')
    .eq('id', data.user.id)
    .maybeSingle()

  if (profile?.status !== 'active') {
    await supabase.auth.signOut()
    redirect(`/login?error=${encodeURIComponent('Ce compte est désactivé. Contactez l’administrateur de l’établissement.')}`)
  }

  redirect(next.startsWith('/') ? next : '/')
}
