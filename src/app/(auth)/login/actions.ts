'use server'

import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export async function signIn(formData: FormData) {
  const email = String(formData.get('email') ?? '').trim()
  const password = String(formData.get('password') ?? '')
  const next = String(formData.get('next') ?? '/')
  const space = String(formData.get('space') ?? '')

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
    .select('status,education_stage')
    .eq('id', data.user.id)
    .maybeSingle()

  if (profile?.status !== 'active') {
    await supabase.auth.signOut()
    redirect(`/login?error=${encodeURIComponent('Ce compte est désactivé. Contactez l’administrateur de l’établissement.')}`)
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
