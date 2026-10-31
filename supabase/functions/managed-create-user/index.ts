import { withSupabase } from 'npm:@supabase/server@1'

const allowedStages = new Set(['maternelle', 'primaire', 'secondaire', 'formation', 'autre', 'parent'])
const allowedCreators = new Set(['it_admin'])
const protectedRoles = new Set(['super_admin', 'founder', 'it_admin'])

function jsonError(message: string, status: number) {
  return Response.json({ error: message }, { status })
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (request, ctx) => {
    if (request.method !== 'POST') return jsonError('MÃ©thode non autorisÃ©e.', 405)

    let input: Record<string, unknown>
    try {
      input = await request.json()
    } catch {
      return jsonError('RequÃªte invalide.', 400)
    }

    const firstName = typeof input.firstName === 'string' ? input.firstName.trim() : ''
    const lastName = typeof input.lastName === 'string' ? input.lastName.trim() : ''
    const username = typeof input.username === 'string' ? input.username.trim().toLowerCase() : ''
    const email = typeof input.email === 'string' ? input.email.trim() : ''
    const password = typeof input.password === 'string' ? input.password : ''
    const roleId = typeof input.roleId === 'string' ? input.roleId : ''
    const educationStage = typeof input.educationStage === 'string' ? input.educationStage : ''
    const requestedSchoolId = typeof input.schoolId === 'string' ? input.schoolId.trim() : ''

    if (!firstName || firstName.length > 100 || !lastName || lastName.length > 100) return jsonError('Vérifiez le prénom et le nom.', 400)
    if (!/^[a-z0-9._-]{3,40}$/.test(username)) return jsonError('Nom d’utilisateur invalide.', 400)
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) return jsonError('Saisissez une adresse e-mail valide.', 400)
    if (password.length < 10 || password.length > 128) return jsonError('Le mot de passe doit contenir entre 10 et 128 caractères.', 400)
    if (!/^[0-9a-f-]{36}$/i.test(roleId)) return jsonError('Sélectionnez un rôle et ses permissions avant de créer le compte.', 400)
    if (!allowedStages.has(educationStage)) return jsonError('Sélectionnez un cycle valide.', 400)

    const userId = ctx.userClaims?.id
    if (!userId) return jsonError('Session invalide. Reconnectez-vous.', 401)

    const { data: profile, error: profileLookupError } = await ctx.supabaseAdmin
      .from('users').select('status,school_id').eq('id', userId).maybeSingle()
    if (profileLookupError) return jsonError('Impossible de vÃ©rifier le profil administrateur.', 500)
    if (!profile || profile.status !== 'active') return jsonError('Accès refusé.', 403)

    const schoolId = requestedSchoolId || profile.school_id || ''
    if (!/^[0-9a-f-]{36}$/i.test(schoolId)) return jsonError('Aucune école sélectionnée ou rattachée au compte administrateur.', 400)

    const { data: assignments, error: assignmentsError } = await ctx.supabaseAdmin
      .from('user_roles').select('roles(code)').eq('user_id', userId).eq('is_active', true)
    if (assignmentsError) return jsonError('Impossible de vÃ©rifier les droits administrateur.', 500)
    const creatorRoles = (assignments ?? []).map((assignment: any) => assignment.roles?.code as string | undefined)
    if (!creatorRoles.some((code) => allowedCreators.has(code ?? ''))) return jsonError('Seul un Administrateur informatique peut créer des comptes.', 403)

    const { data: school, error: schoolError } = await ctx.supabaseAdmin.from('schools').select('id,is_active').eq('id', schoolId).maybeSingle()
    if (schoolError) return jsonError('Impossible de vérifier l’école sélectionnée.', 500)
    if (!school || !school.is_active) return jsonError('L’école sélectionnée est introuvable ou inactive.', 400)

    const { data: role, error: roleError } = await ctx.supabaseAdmin
      .from('roles').select('id,code').eq('id', roleId).maybeSingle()
    if (roleError) return jsonError('Impossible de vÃ©rifier le rÃ´le sÃ©lectionnÃ©.', 500)
    if (!role) return jsonError('Le rÃ´le sÃ©lectionnÃ© est introuvable.', 400)
    if (protectedRoles.has(role.code)) {
      return jsonError('Seul un super administrateur ou le fondateur peut attribuer ce rÃ´le.', 403)
    }

    const { data: created, error: createError } = await ctx.supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { first_name: firstName, last_name: lastName, username },
    })
    if (createError || !created.user) return jsonError(createError?.message ?? 'Impossible de crÃ©er le compte.', 400)

    const newUserId = created.user.id
    const newProfile = await ctx.supabaseAdmin.from('users').insert({
      id: newUserId,
      school_id: schoolId,
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
          school_id: schoolId,
          is_active: true,
        })

    if (newProfile.error || newRole.error) {
      await ctx.supabaseAdmin.from('user_roles').delete().eq('user_id', newUserId)
      await ctx.supabaseAdmin.from('users').delete().eq('id', newUserId)
      await ctx.supabaseAdmin.auth.admin.deleteUser(newUserId)
      return jsonError(`CrÃ©ation annulÃ©e : ${newProfile.error?.message ?? newRole.error?.message ?? 'erreur inconnue'}`, 400)
    }

    return Response.json({ userId: newUserId }, { status: 201 })
  }),
}
