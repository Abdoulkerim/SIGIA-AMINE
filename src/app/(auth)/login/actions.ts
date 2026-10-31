'use server'

import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import type { Database } from '@/types/database.types'

export async function signIn(formData: FormData) {
  const identifier = String(formData.get('identifier') ?? '').trim()
  const password = String(formData.get('password') ?? '')
  const next = String(formData.get('next') ?? '/')
  const space = String(formData.get('space') ?? '')

  if (!identifier || !password) {
    redirect(`/login?error=${encodeURIComponent('Nom d’utilisateur ou adresse e-mail et mot de passe obligatoires.')}`)
  }

  const supabase = await createClient()
  let email = identifier
  if (!identifier.includes('@')) {
    if (!/^[a-z0-9._-]{3,40}$/i.test(identifier)) {
      redirect(`/login?error=${encodeURIComponent('Nom d’utilisateur ou mot de passe invalide.')}`)
    }
    const secretKey = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY
    if (!secretKey) {
      redirect(`/login?error=${encodeURIComponent('La connexion par nom d’utilisateur nécessite SUPABASE_SECRET_KEY dans l’environnement serveur. Ajoutez cette variable puis redémarrez le service. Vous pouvez aussi vous connecter avec votre adresse e-mail.')}`)
    }
    const admin = createSupabaseClient<Database>(process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL!, secretKey, { auth: { autoRefreshToken: false, persistSession: false } })
    const username = identifier.toLowerCase()
    const { data: profileByUsername } = await admin.from('users').select('email').eq('username', username).maybeSingle()
    email = profileByUsername?.email ?? ''
    if (!email) {
      const { data: legacyProfiles } = await admin.from('users').select('email').ilike('email', `${username}@%`).limit(2)
      if (legacyProfiles?.length === 1) email = legacyProfiles[0].email ?? ''
    }
    if (!email) redirect(`/login?error=${encodeURIComponent('Nom d’utilisateur ou mot de passe invalide.')}`)
  }

  const { data, error } = await supabase.auth.signInWithPassword({ email, password })

  if (error || !data.user) {
    redirect(`/login?error=${encodeURIComponent('Nom d’utilisateur ou mot de passe invalide.')}`)
  }

  const { data: profile, error: profileError } = await supabase
  .from('users')
  .select('status, education_stage')
  .eq('id', data.user.id)
  .maybeSingle()

if (profileError) {
  console.error('[LOGIN] Erreur de lecture du profil :', {
    code: profileError.code,
    message: profileError.message,
  })

  await supabase.auth.signOut()
  const profileErrorMessage = profileError.code === '42703'
    ? 'La base de données doit être mise à jour. Contactez l’administrateur de SIGIA-AMINE.'
    : 'Impossible de vérifier votre profil. Contactez le support technique.'

  redirect(
    `/login?error=${encodeURIComponent(
      profileErrorMessage,
    )}`,
  )
}

if (!profile) {
  console.error('[LOGIN] Aucun profil trouvé pour cet utilisateur :', data.user.id)

  await supabase.auth.signOut()
  redirect(
    `/login?error=${encodeURIComponent(
      'Profil utilisateur introuvable. Contactez le support technique.',
    )}`,
  )
}

if (profile.status !== 'active') {
  console.error('[LOGIN] Statut de profil non actif :', profile.status)

  await supabase.auth.signOut()
  redirect(
    `/login?error=${encodeURIComponent(
      'Ce compte est désactivé. Contactez l’administrateur de l’établissement.',
    )}`,
  )
}

  const { data: assignedRoles } = await supabase
    .from('user_roles')
    .select('roles(code)')
    .eq('user_id', data.user.id)
    .eq('is_active', true)
  const roleCodes = (assignedRoles ?? []).map((assignment: any) => assignment.roles?.code)
  const canManageAccess = ['super_admin', 'founder', 'it_admin'].some((code) => roleCodes.includes(code))
  if (!profile.education_stage && !roleCodes.includes('parent') && !canManageAccess) {
    await supabase.auth.signOut()
    redirect(`/login?error=${encodeURIComponent('Aucun cycle scolaire n’est attribué à ce compte. Contactez l’administrateur.')}`)
  }

  const allowedSpaces = ['maternelle', 'primaire', 'secondaire', 'formation', 'parent']
  if (space && !allowedSpaces.includes(space)) {
    await supabase.auth.signOut()
    redirect(`/login?error=${encodeURIComponent('Espace de connexion invalide.')}`)
  }
  if (space) {
    if (space === 'parent' && !roleCodes.includes('parent')) {
      await supabase.auth.signOut()
      redirect(`/login?space=parent&error=${encodeURIComponent('Aucun accès Parent n’est attribué à ce compte. Contactez l’administrateur.')}`)
    }
    if (space !== 'parent' && roleCodes.includes('parent')) {
      await supabase.auth.signOut()
      redirect(`/login?space=${encodeURIComponent(space)}&error=${encodeURIComponent('Ce compte est configuré comme Parent. Choisissez l’espace Parent.')}`)
    }
  }
  if (space && profile.education_stage && space !== 'parent' && space !== profile.education_stage) {
    await supabase.auth.signOut()
    redirect(`/login?space=${encodeURIComponent(space)}&error=${encodeURIComponent('Ce compte n’est pas autorisé pour cet espace. Choisissez le cycle attribué à votre compte.')}`)
  }
  if (space === 'parent' && profile.education_stage) {
    await supabase.auth.signOut()
    redirect(`/login?space=parent&error=${encodeURIComponent('Cet espace est réservé aux comptes parent. Utilisez le cycle attribué à votre compte.')}`)
  }

  redirect(next.startsWith('/') ? next : '/')
}
