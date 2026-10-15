'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const statusSchema = z.enum(['active', 'inactive', 'suspended'])
const protectedRoleCodes = new Set(['super_admin', 'founder', 'it_admin'])

function accessUrl(userId?: string, error?: string, updated?: string) {
  const params = new URLSearchParams()
  if (userId) params.set('userId', userId)
  if (error) params.set('error', error)
  if (updated) params.set('updated', updated)
  const query = params.toString()
  return `/administration-it/acces${query ? `?${query}` : ''}`
}

async function getAccessManager() {
  const context = await getCurrentUserContext()
  const canManage = context?.roles.some(({ code }) => ['it_admin', 'super_admin', 'founder'].includes(code ?? ''))
  if (!context || !canManage || !context.profile.school_id) return null
  return { context, schoolId: context.profile.school_id, supabase: await createClient() }
}

async function ensureTargetUser(supabase: Awaited<ReturnType<typeof createClient>>, userId: string, schoolId: string) {
  const { data } = await supabase.from('users').select('id').eq('id', userId).eq('school_id', schoolId).maybeSingle()
  return data
}

function invalidateAccessPages() {
  revalidatePath('/administration-it')
  revalidatePath('/administration-it/acces')
  revalidatePath('/administration-it/utilisateurs')
}

export async function assignUserRole(formData: FormData) {
  const target = uuid.safeParse(formData.get('userId'))
  const role = uuid.safeParse(formData.get('roleId'))
  if (!target.success || !role.success) redirect(accessUrl(undefined, 'Utilisateur ou rôle invalide.'))

  const manager = await getAccessManager()
  if (!manager) redirect(accessUrl(target.data, 'Accès non autorisé.'))
  const { context, schoolId, supabase } = manager
  if (target.data === context.profile.id) redirect(accessUrl(target.data, 'Pour éviter de perdre votre propre accès, vous ne pouvez pas modifier vos rôles ici.'))

  const [user, { data: selectedRole, error: roleError }] = await Promise.all([
    ensureTargetUser(supabase, target.data, schoolId),
    supabase.from('roles').select('id,code').eq('id', role.data).maybeSingle(),
  ])
  if (!user) redirect(accessUrl(target.data, 'Utilisateur introuvable dans cet établissement.'))
  if (roleError || !selectedRole) redirect(accessUrl(target.data, 'Rôle introuvable.'))

  const isPrivilegedManager = context.roles.some(({ code }) => ['super_admin', 'founder'].includes(code ?? ''))
  if (!isPrivilegedManager && protectedRoleCodes.has(selectedRole.code)) {
    redirect(accessUrl(target.data, 'Seuls un super administrateur ou le fondateur peuvent attribuer ce rôle.'))
  }

  const { error } = await supabase.from('user_roles').upsert({
    user_id: target.data,
    role_id: role.data,
    school_id: schoolId,
    is_active: true,
  }, { onConflict: 'user_id,role_id,school_id' })
  if (error) redirect(accessUrl(target.data, `Attribution refusée : ${error.message}`))

  invalidateAccessPages()
  redirect(accessUrl(target.data, undefined, 'role'))
}

export async function revokeUserRole(formData: FormData) {
  const target = uuid.safeParse(formData.get('userId'))
  const role = uuid.safeParse(formData.get('roleId'))
  if (!target.success || !role.success) redirect(accessUrl(undefined, 'Utilisateur ou rôle invalide.'))

  const manager = await getAccessManager()
  if (!manager) redirect(accessUrl(target.data, 'Accès non autorisé.'))
  const { context, schoolId, supabase } = manager
  if (target.data === context.profile.id) redirect(accessUrl(target.data, 'Pour éviter de perdre votre propre accès, vous ne pouvez pas modifier vos rôles ici.'))
  if (!await ensureTargetUser(supabase, target.data, schoolId)) redirect(accessUrl(target.data, 'Utilisateur introuvable dans cet établissement.'))

  const { error } = await supabase.from('user_roles')
    .update({ is_active: false })
    .eq('user_id', target.data)
    .eq('role_id', role.data)
    .eq('school_id', schoolId)
  if (error) redirect(accessUrl(target.data, `Retrait refusé : ${error.message}`))

  invalidateAccessPages()
  redirect(accessUrl(target.data, undefined, 'role'))
}

export async function updateUserLoginAccess(formData: FormData) {
  const target = uuid.safeParse(formData.get('userId'))
  const status = statusSchema.safeParse(formData.get('status'))
  if (!target.success || !status.success) redirect(accessUrl(undefined, 'Utilisateur ou état d’accès invalide.'))

  const manager = await getAccessManager()
  if (!manager) redirect(accessUrl(target.data, 'Accès non autorisé.'))
  const { context, schoolId, supabase } = manager
  if (target.data === context.profile.id) redirect(accessUrl(target.data, 'Vous ne pouvez pas suspendre votre propre accès.'))
  if (!await ensureTargetUser(supabase, target.data, schoolId)) redirect(accessUrl(target.data, 'Utilisateur introuvable dans cet établissement.'))

  const { error } = await supabase.from('users').update({ status: status.data }).eq('id', target.data).eq('school_id', schoolId)
  if (error) redirect(accessUrl(target.data, `Modification refusée : ${error.message}`))

  invalidateAccessPages()
  redirect(accessUrl(target.data, undefined, 'status'))
}
