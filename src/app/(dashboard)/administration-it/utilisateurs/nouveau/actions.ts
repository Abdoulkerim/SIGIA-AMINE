'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'
import type { Database } from '@/types/database.types'

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
  const schoolId = context?.profile.school_id
  if (!context || !isAdmin || !schoolId) redirect(formUrl('Accès refusé ou établissement manquant.'))

  const serviceKey = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!serviceKey) redirect(formUrl('La création de comptes nécessite une clé secrète Supabase configurée côté serveur.'))

  const supabase = await createClient()
  const { data: role, error: roleError } = await supabase.from('roles').select('id,code').eq('id', parsed.data.roleId).maybeSingle()
  if (roleError || !role) redirect(formUrl('Le rôle sélectionné est introuvable.'))
  const isPrivilegedManager = context.roles.some(({ code }) => ['super_admin','founder'].includes(code ?? ''))
  if (!isPrivilegedManager && ['super_admin','founder','it_admin'].includes(role.code)) redirect(formUrl('Seul un super administrateur ou le fondateur peut attribuer ce rôle.'))

  const supabaseUrl = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL!
  const admin = createSupabaseClient<Database>(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } })
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: parsed.data.email, password: parsed.data.password, email_confirm: true,
    user_metadata: { first_name: parsed.data.firstName, last_name: parsed.data.lastName, username: parsed.data.username },
  })
  if (createError || !created.user) redirect(formUrl(createError?.message ?? 'Impossible de créer le compte.'))

  const userId = created.user.id
  const [profileResult, roleResult] = await Promise.all([
    admin.from('users').insert({ id: userId, school_id: schoolId, first_name: parsed.data.firstName, last_name: parsed.data.lastName, username: parsed.data.username, email: parsed.data.email, status: 'active', education_stage: parsed.data.educationStage === 'parent' ? null : parsed.data.educationStage }),
    admin.from('user_roles').insert({ user_id: userId, role_id: parsed.data.roleId, school_id: schoolId, is_active: true }),
  ])
  if (profileResult.error || roleResult.error) {
    await admin.auth.admin.deleteUser(userId)
    redirect(formUrl(`Création annulée : ${profileResult.error?.message ?? roleResult.error?.message ?? 'erreur inconnue'}`))
  }

  revalidatePath('/administration-it/utilisateurs')
  revalidatePath('/administration-it/acces')
  revalidatePath('/administration-it')
  redirect('/administration-it/utilisateurs?created=1')
}
