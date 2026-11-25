'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const statusSchema = z.enum(['active', 'inactive', 'suspended'])
const educationStageSchema = z.enum(['maternelle', 'primaire', 'secondaire', 'formation', 'autre', 'parent'])
const accessibleStageSchema = z.enum(['maternelle', 'primaire', 'secondaire', 'formation', 'autre'])
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

export async function saveUserPermissionOverrides(formData: FormData) {
  const target = uuid.safeParse(formData.get('userId'))
  if (!target.success) redirect(accessUrl(undefined, 'Utilisateur invalide.'))
  const manager = await getAccessManager()
  if (!manager) redirect(accessUrl(target.data, 'Accès non autorisé.'))
  const { context, schoolId, supabase } = manager
  if (target.data === context.profile.id) redirect(accessUrl(target.data, 'Vous ne pouvez pas modifier vos propres permissions.'))
  if (!await ensureTargetUser(supabase, target.data, schoolId)) redirect(accessUrl(target.data, 'Utilisateur introuvable dans cet établissement.'))

  const granted: string[] = []
  const denied: string[] = []
  for (const value of formData.getAll('permissionOverride')) {
    if (typeof value !== 'string') redirect(accessUrl(target.data, 'Permission invalide.'))
    const [permissionId, effect, extra] = value.split(':')
    if (!uuid.safeParse(permissionId).success || extra !== undefined || typeof effect !== 'string' || !['inherit', 'grant', 'deny'].includes(effect)) {
      redirect(accessUrl(target.data, 'Permission invalide.'))
    }
    if (effect === 'grant') granted.push(permissionId)
    if (effect === 'deny') denied.push(permissionId)
  }

  const { error } = await (supabase as any).rpc('set_user_permission_overrides', {
    p_user_id: target.data,
    p_school_id: schoolId,
    p_granted_permission_ids: granted,
    p_denied_permission_ids: denied,
  })
  if (error) redirect(accessUrl(target.data, `Modification des permissions refusée : ${error.message}`))
  invalidateAccessPages()
  redirect(accessUrl(target.data, undefined, 'permissions'))
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

export async function updateUserEducationStage(formData: FormData) {
  const target = uuid.safeParse(formData.get('userId'))
  const stage = educationStageSchema.safeParse(formData.get('educationStage'))
  if (!target.success || !stage.success) redirect(accessUrl(undefined, 'Utilisateur ou cycle scolaire invalide.'))

  const manager = await getAccessManager()
  if (!manager) redirect(accessUrl(target.data, 'Accès non autorisé.'))
  const { context, schoolId, supabase } = manager
  const isOwnAccount = target.data === context.profile.id
  const { data: targetUser } = await supabase.from('users')
    .select('id,education_stage')
    .eq('id', target.data)
    .eq('school_id', schoolId)
    .maybeSingle()
  if (!targetUser) redirect(accessUrl(target.data, 'Utilisateur introuvable dans cet établissement.'))
  if (isOwnAccount && targetUser.education_stage !== null) {
    redirect(accessUrl(target.data, 'Le cycle de votre compte ne peut être modifié par vous-meme.'))
  }
  if (isOwnAccount && stage.data === 'parent') {
    redirect(accessUrl(target.data, 'Attribuez un cycle scolaire à votre compte fondateur.'))
  }

  let update = supabase.from('users')
    .update({ education_stage: stage.data === 'parent' ? null : stage.data })
    .eq('id', target.data)
    .eq('school_id', schoolId)
  if (isOwnAccount) update = update.is('education_stage', null)
  const { data: updatedUser, error } = await update.select('id').maybeSingle()
  if (error) redirect(accessUrl(target.data, 'Modification du cycle refusée : ' + error.message))
  if (!updatedUser) redirect(accessUrl(target.data, 'Le cycle a deja ete attribué ou le compte est introuvable.'))

  invalidateAccessPages()
  redirect(accessUrl(target.data, undefined, 'stage'))
}

export async function updateUserAccessibleStages(formData: FormData) {
  const target = uuid.safeParse(formData.get('userId'))
  if (!target.success) redirect(accessUrl(undefined, 'Utilisateur invalide.'))

  const manager = await getAccessManager()
  if (!manager) redirect(accessUrl(target.data, 'Accès non autorisé.'))
  const { schoolId, supabase } = manager
  if (!await ensureTargetUser(supabase, target.data, schoolId)) {
    redirect(accessUrl(target.data, 'Utilisateur introuvable dans cet établissement.'))
  }

  const stages: string[] = []
  for (const value of formData.getAll('accessibleStages')) {
    if (typeof value !== 'string') continue
    const parsed = accessibleStageSchema.safeParse(value)
    if (parsed.success) stages.push(parsed.data)
  }

  if (!stages.length) redirect(accessUrl(target.data, 'Sélectionnez au moins un cycle accessible.'))

  const { error: deleteError } = await supabase
    .from('user_access_stages')
    .delete()
    .eq('user_id', target.data)
    .eq('school_id', schoolId)
  if (deleteError) redirect(accessUrl(target.data, 'Modification des cycles refusée : ' + deleteError.message))

  const { error: insertError } = await supabase
    .from('user_access_stages')
    .insert(stages.map((educationStage) => ({
      user_id: target.data,
      school_id: schoolId,
      education_stage: educationStage,
    })))
  if (insertError) redirect(accessUrl(target.data, 'Modification des cycles refusée : ' + insertError.message))

  invalidateAccessPages()
  redirect(accessUrl(target.data, undefined, 'stage'))
}
