import { withSupabase } from 'npm:@supabase/server@1'

const allowedStages = new Set(['maternelle', 'primaire', 'secondaire', 'formation', 'autre', 'parent'])
const allowedCreators = new Set(['it_admin', 'super_admin', 'founder'])
const protectedRoles = new Set(['super_admin', 'founder', 'it_admin'])

function jsonError(message: string, status: number) {
  return Response.json({ error: message }, { status })
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (request, ctx) => {
    if (request.method !== 'POST') return jsonError('Méthode non autorisée.', 405)

    let input: Record<string, unknown>
    try {
      input = await request.json()
    } catch {
      return jsonError('Requête invalide.', 400)
    }

    const firstName = typeof input.firstName === 'string' ? input.firstName.trim() : ''
    const lastName = typeof input.lastName === 'string' ? input.lastName.trim() : ''
    const username = typeof input.username === 'string' ? input.username.trim().toLowerCase() : ''
    const email = typeof input.email === 'string' ? input.email.trim() : ''
    const password = typeof input.password === 'string' ? input.password : ''
    const roleId = typeof input.roleId === 'string' ? input.roleId : ''
    const educationStage = typeof input.educationStage === 'string' ? input.educationStage : ''

    if (!firstName || firstName.length > 100 || !lastName || lastName.length > 100 ||
      !/^[a-z0-9._-]{3,40}$/.test(username) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254 ||
      password.length < 10 || password.length > 128 || !/^[0-9a-f-]{36}$/i.test(roleId) || !allowedStages.has(educationStage)) {
      return jsonError('Vérifiez les champs saisis. Le mot de passe doit contenir au moins 10 caractères.', 400)
    }

    const userId = ctx.userClaims?.sub
    if (!userId) return jsonError('Session invalide. Reconnectez-vous.', 401)

    const { data: profile, error: profileLookupError } = await ctx.supabaseAdmin
      .from('users').select('school_id,status').eq('id', userId).maybeSingle()
    if (profileLookupError) return jsonError('Impossible de vérifier le profil administrateur.', 500)
    if (!profile || profile.status !== 'active' || !profile.school_id) return jsonError('Accès refusé ou établissement manquant.', 403)

    const { data: assignments, error: assignmentsError } = await ctx.supabaseAdmin
      .from('user_roles').select('school_id,roles(code)').eq('user_id', userId).eq('is_active', true)
    if (assignmentsError) return jsonError('Impossible de vérifier les droits administrateur.', 500)
    const creatorRoles = (assignments ?? [])
      .filter((assignment: any) => {
        const code = assignment.roles?.code as string | undefined
        return assignment.school_id === profile.school_id ||
          (assignment.school_id === null && (code === 'super_admin' || code === 'founder'))
      })
      .map((assignment: any) => assignment.roles?.code as string | undefined)
    if (!creatorRoles.some((code) => allowedCreators.has(code ?? ''))) return jsonError('Vous ne pouvez pas créer des comptes.', 403)

    const { data: role, error: roleError } = await ctx.supabaseAdmin
      .from('roles').select('id,code').eq('id', roleId).maybeSingle()
    if (roleError) return jsonError('Impossible de vérifier le rôle sélectionné.', 500)
    if (!role) return jsonError('Le rôle sélectionné est introuvable.', 400)
    if (!creatorRoles.some((code) => code === 'super_admin' || code === 'founder') && protectedRoles.has(role.code)) {
      return jsonError('Seul un super administrateur ou le fondateur peut attribuer ce rôle.', 403)
    }

    const { data: created, error: createError } = await ctx.supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { first_name: firstName, last_name: lastName, username },
    })
    if (createError || !created.user) return jsonError(createError?.message ?? 'Impossible de créer le compte.', 400)

    const newUserId = created.user.id
    const newProfile = await ctx.supabaseAdmin.from('users').insert({
      id: newUserId,
      school_id: profile.school_id,
      first_name: firstName,
      last_name: lastName,
      username,
      email,
      status: 'active',
      education_stage: educationStage === 'parent' ? null : educationStage,
    })
    const newRole = newProfile.error
      ? { error: null }
      : await ctx.supabaseAdmin.from('user_roles').insert({
          user_id: newUserId,
          role_id: roleId,
          school_id: profile.school_id,
          is_active: true,
        })

    if (newProfile.error || newRole.error) {
      await ctx.supabaseAdmin.from('user_roles').delete().eq('user_id', newUserId)
      await ctx.supabaseAdmin.from('users').delete().eq('id', newUserId)
      await ctx.supabaseAdmin.auth.admin.deleteUser(newUserId)
      return jsonError(`Création annulée : ${newProfile.error?.message ?? newRole.error?.message ?? 'erreur inconnue'}`, 400)
    }

    return Response.json({ userId: newUserId }, { status: 201 })
  }),
}
