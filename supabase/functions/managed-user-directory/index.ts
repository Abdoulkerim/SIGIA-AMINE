import { withSupabase } from 'npm:@supabase/server@1'

const stages = new Set(['maternelle', 'primaire', 'secondaire', 'formation', 'autre', 'parent'])
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function errorResponse(message: string, status: number) {
  return Response.json({ error: message }, { status })
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (request, ctx) => {
    if (request.method !== 'POST') return errorResponse('Méthode non autorisée.', 405)

    let body: Record<string, unknown>
    try {
      body = await request.json()
    } catch {
      return errorResponse('Requête invalide.', 400)
    }

    const callerId = ctx.userClaims?.id
    if (!callerId) return errorResponse('Session invalide. Reconnectez-vous.', 401)

    const { data: caller, error: callerError } = await ctx.supabaseAdmin
      .from('users').select('status').eq('id', callerId).maybeSingle()
    if (callerError) return errorResponse('Impossible de vérifier votre compte.', 500)
    if (caller?.status !== 'active') return errorResponse('Votre compte est inactif.', 403)

    const { data: assignments, error: assignmentsError } = await ctx.supabaseAdmin
      .from('user_roles').select('roles(code)').eq('user_id', callerId).eq('is_active', true)
    if (assignmentsError) return errorResponse('Impossible de vérifier vos autorisations.', 500)
    if (!(assignments ?? []).some((assignment: any) => assignment.roles?.code === 'it_admin')) {
      return errorResponse('Seul un Administrateur informatique peut gérer et consulter les comptes.', 403)
    }

    const action = body.action
    if (action === 'list') {
      const { data: schools, error: schoolsError } = await ctx.supabaseAdmin
        .from('schools').select('id,name,code,is_active').order('name')
      if (schoolsError) return errorResponse('Impossible de charger les écoles.', 500)

      const schoolId = typeof body.schoolId === 'string' ? body.schoolId : ''
      const stage = typeof body.educationStage === 'string' ? body.educationStage : 'all'
      const status = typeof body.status === 'string' ? body.status : 'all'
      if (schoolId && !uuid.test(schoolId)) return errorResponse('École invalide.', 400)
      if (stage !== 'all' && !stages.has(stage)) return errorResponse('Cycle invalide.', 400)
      if (!['all', 'active', 'inactive', 'suspended'].includes(status)) return errorResponse('État invalide.', 400)

      let users: any[] = []
      if (schoolId) {
        let query = ctx.supabaseAdmin.from('users')
          .select('id,school_id,first_name,last_name,username,email,status,last_login,created_at,education_stage')
          .eq('school_id', schoolId)
          .order('last_name').order('first_name').limit(500)
        if (stage === 'parent') query = query.is('education_stage', null)
        else if (stage !== 'all') query = query.eq('education_stage', stage)
        if (status !== 'all') query = query.eq('status', status)
        const { data, error } = await query
        if (error) return errorResponse('Impossible de charger les comptes de cette école.', 500)
        users = data ?? []

        if (users.length) {
          const { data: roles, error: rolesError } = await ctx.supabaseAdmin.from('user_roles')
            .select('user_id,roles(name,code)').eq('school_id', schoolId).eq('is_active', true)
            .in('user_id', users.map((user) => user.id))
          if (rolesError) return errorResponse('Impossible de charger les rôles.', 500)
          users = users.map((user) => ({
            ...user,
            roles: (roles ?? []).filter((row: any) => row.user_id === user.id).map((row: any) => row.roles?.name).filter(Boolean),
          }))
        }
      }

      return Response.json({ schools: schools ?? [], users })
    }

    const schoolId = typeof body.schoolId === 'string' ? body.schoolId : ''
    const userId = typeof body.userId === 'string' ? body.userId : ''
    if (!uuid.test(schoolId) || !uuid.test(userId)) return errorResponse('Utilisateur ou école invalide.', 400)

    const { data: target, error: targetError } = await ctx.supabaseAdmin.from('users')
      .select('id,school_id,education_stage,email').eq('id', userId).eq('school_id', schoolId).maybeSingle()
    if (targetError) return errorResponse('Impossible de vérifier le compte ciblé.', 500)
    if (!target) return errorResponse('Compte introuvable dans cette école.', 404)
    if (target.id === callerId) return errorResponse('Vous ne pouvez pas supprimer ou modifier votre propre compte.', 403)

    const selectedStage = typeof body.educationStage === 'string' ? body.educationStage : ''
    if (!stages.has(selectedStage) || (target.education_stage ?? 'parent') !== selectedStage) {
      return errorResponse('Le cycle du compte a changé. Actualisez la liste avant de recommencer.', 409)
    }

    if (action === 'update-stage') {
      const newStage = typeof body.newEducationStage === 'string' ? body.newEducationStage : ''
      if (!stages.has(newStage)) return errorResponse('Cycle invalide.', 400)
      const { error } = await ctx.supabaseAdmin.from('users')
        .update({ education_stage: newStage === 'parent' ? null : newStage })
        .eq('id', userId).eq('school_id', schoolId)
      if (error) return errorResponse(`Impossible de modifier le cycle : ${error.message}`, 400)
      return Response.json({ updated: true })
    }

    if (action === 'delete') {
      if (body.confirmation !== 'SUPPRIMER') return errorResponse('Confirmation de suppression invalide.', 400)
      const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
      if (error) return errorResponse(`Suppression refusée : ${error.message}`, 409)
      return Response.json({ deleted: true })
    }

    return errorResponse('Action inconnue.', 400)
  }),
}
