'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

const schema = z.object({
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  username: z.string().trim().toLowerCase().regex(/^[a-z0-9._-]{3,40}$/),
  password: z.string().max(128).optional(),
})

export async function updateOwnAccount(formData: FormData) {
  const parsed = schema.safeParse(Object.fromEntries(formData))
  if (!parsed.success || (parsed.data.password && parsed.data.password.length < 10)) {
    redirect('/mon-compte?error=Vérifiez%20les%20champs.%20Le%20mot%20de%20passe%20doit%20contenir%2010%20caractères%20minimum.')
  }
  const context = await getCurrentUserContext()
  if (!context) redirect('/login')
  const supabase = await createClient()
  const { error: profileError } = await supabase.from('users').update({
    first_name: parsed.data.firstName,
    last_name: parsed.data.lastName,
    username: parsed.data.username,
  }).eq('id', context.profile.id)
  if (profileError) {
    const message = profileError.code === '23505' ? 'Cet identifiant est déjà utilisé.' : 'Impossible de mettre à jour le profil.'
    redirect(`/mon-compte?error=${encodeURIComponent(message)}`)
  }
  const authUpdate: { data: { first_name: string; last_name: string; username: string }; password?: string } = {
    data: { first_name: parsed.data.firstName, last_name: parsed.data.lastName, username: parsed.data.username },
  }
  if (parsed.data.password) authUpdate.password = parsed.data.password
  const { error: authError } = await supabase.auth.updateUser(authUpdate)
  if (authError) redirect(`/mon-compte?error=${encodeURIComponent(authError.message)}`)
  revalidatePath('/mon-compte')
  revalidatePath('/dashboard')
  redirect('/mon-compte?updated=1')
}
