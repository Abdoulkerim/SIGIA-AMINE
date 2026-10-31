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
  roleId: z.string().uuid(), schoolId: z.string().uuid(),
  educationStage: z.enum(['maternelle','primaire','secondaire','formation','autre','parent']),
})

function formUrl(error: string) { return `/administration-it/utilisateurs/nouveau?error=${encodeURIComponent(error)}` }

export async function createManagedUser(formData: FormData) {
  const parsed = schema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) {
    const missingField = parsed.error.issues[0]?.path[0]
    const message = missingField === 'roleId'
      ? 'Sélectionnez un rôle et ses permissions avant de créer le compte.'
      : missingField === 'schoolId'
        ? 'Sélectionnez une école avant de créer le compte. Actualisez la page si le champ École est absent.'
        : missingField === 'educationStage'
          ? 'Sélectionnez le cycle auquel le compte aura accès.'
          : missingField === 'password'
            ? 'Le mot de passe doit contenir au moins 10 caractères.'
            : missingField === 'username'
              ? 'Le nom d’utilisateur doit contenir 3 à 40 lettres, chiffres, points, tirets ou tirets bas.'
              : 'Vérifiez le prénom, le nom et l’adresse e-mail.'
    redirect(formUrl(message))
  }

  const context = await getCurrentUserContext()
  if (!context?.roles.some(({ code }) => code === 'it_admin')) redirect(formUrl('Seul un Administrateur informatique peut créer des comptes.'))

  const supabase = await createClient()
  const { error } = await supabase.functions.invoke('managed-create-user', { body: parsed.data })
  if (error) {
    let message = 'La fonction Supabase de création de comptes est indisponible. Déployez managed-create-user puis réessayez.'
    if (error instanceof FunctionsHttpError) {
      try {
        const result = await error.context.json()
        if (typeof result?.error === 'string') message = result.error
      } catch { /* Garder un message exploitable si la réponse n'est pas JSON. */ }
    }
    redirect(formUrl(message))
  }

  revalidatePath('/administration-it/utilisateurs')
  revalidatePath('/administration-it/acces')
  revalidatePath('/administration-it')
  redirect(`/administration-it/utilisateurs?schoolId=${parsed.data.schoolId}&created=1`)
}
