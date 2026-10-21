'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import type { Database } from '@/types/database.types'

export async function setTemporaryPassword(formData: FormData) {
  const parsed = z.object({ userId: z.string().uuid(), password: z.string().min(10).max(128) }).safeParse(Object.fromEntries(formData))
  if (!parsed.success) redirect('/administration-it/utilisateurs?error=Mot%20de%20passe%20invalide.')
  const context = await getCurrentUserContext()
  const allowed = context?.roles.some(({ code }) => ['it_admin', 'super_admin', 'founder'].includes(code ?? ''))
  if (!context || !allowed || !context.profile.school_id) redirect('/dashboard')
  const secret = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY
  const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL
  if (!secret || !url) redirect('/administration-it/utilisateurs?error=Configuration%20administrateur%20indisponible.')
  const admin = createSupabaseClient<Database>(url, secret, { auth: { autoRefreshToken: false, persistSession: false } })
  const { data: target } = await admin.from('users').select('id').eq('id', parsed.data.userId).eq('school_id', context.profile.school_id).maybeSingle()
  if (!target || target.id === context.profile.id) redirect('/administration-it/utilisateurs?error=Compte%20introuvable.')
  const { error } = await admin.auth.admin.updateUserById(target.id, { password: parsed.data.password })
  if (error) redirect(`/administration-it/utilisateurs/${target.id}?error=${encodeURIComponent(error.message)}`)
  revalidatePath('/administration-it/utilisateurs')
  redirect(`/administration-it/utilisateurs/${target.id}?updated=1`)
}
