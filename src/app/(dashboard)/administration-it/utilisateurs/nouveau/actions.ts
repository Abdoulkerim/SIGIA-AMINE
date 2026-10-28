'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { FunctionsHttpError } from '@supabase/supabase-js'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

const schema = z.object({
  firstName: z.string().trim().min(1).max(100), lastName: z.string().trim().min(1).max(100),
  username: z.string().trim().toLowerCase().regex(/^[a-z0-9._-]{3,40}$/, 'Nom d’utilisateur invalide.'),
  email: z.string().trim().email().max(254), password: z.string().min(10).max(128),
  roleId: z.string().uuid(), educationStage: z.enum(['maternelle','primaire','secondaire','formation','autre','parent']),
})

function formUrl(error: string) { return `/administration-it/utilisateurs/nouveau?error=${encodeURIComponent(error)}` }

export async function createManagedUser(formData: FormData) {
  const parsed = schema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) redirect(formUrl('Vérifiez les champs saisis. Le mot de passe doit contenir au moins 10 caractères.'))

  const context = await getCurrentUserContext()
  const isAdmin = context?.roles.some(({ code }) => ['it_admin','super_admin','founder'].includes(code ?? ''))
  if (!context || !isAdmin || !context.profile.school_id) redirect(formUrl('Accès refusé ou établissement manquant.'))

  const supabase = await createClient()
  const { error } = await supabase.functions.invoke('managed-create-user', { body: parsed.data })
  if (error) {
    let message = 'La fonction Supabase de création de comptes est indisponible. Déployez managed-create-user puis réessayez.'
    if (error instanceof FunctionsHttpError) {
      try {
        const result = await error.context.json()
        if (typeof result?.error === 'string') message = result.error
      } catch {
        // Preserve an actionable fallback when the function response is not JSON.
      }
    }
    redirect(formUrl(message))
  }

  revalidatePath('/administration-it/utilisateurs')
  revalidatePath('/administration-it/acces')
  revalidatePath('/administration-it')
  redirect('/administration-it/utilisateurs?created=1')
}
