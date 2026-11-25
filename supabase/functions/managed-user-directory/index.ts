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
      .from('users').select('status,school_id').eq('id', callerId).maybeSingle()
    if (callerError) return errorResponse('Impossible de vérifier votre compte.', 500)
    if (caller?.status !== 'active') return errorResponse('Votre compte est inactif.', 403)

    const action = body.action
    if (action === 'invoice-students' || action === 'finance-directory') {
      if (!caller.school_id) return errorResponse('Aucune école n’est associée à ce compte.', 403)
      const { data: assignments, error: assignmentsError } = await ctx.supabaseAdmin
        .from('user_roles').select('school_id,roles(role_permissions(permissions(code)))')
        .eq('user_id', callerId).eq('is_active', true)
      if (assignmentsError) return errorResponse('Impossible de vérifier vos autorisations financières.', 500)
      const canAccessFinance = (assignments ?? []).some((assignment: any) =>
        (assignment.school_id === null || assignment.school_id === caller.school_id)
        && (assignment.roles?.role_permissions ?? []).some((item: any) =>
          action === 'invoice-students'
            ? item.permissions?.code === 'finance.manage'
            : ['finance.view', 'finance.manage'].includes(item.permissions?.code),
        ),
      )
      if (!canAccessFinance) return errorResponse(action === 'invoice-students'
        ? 'La permission « Gérer finance » est requise pour facturer.'
        : 'Une permission de consultation ou de gestion financière est requise.', 403)

      const { data: students, error: studentsError } = await ctx.supabaseAdmin.from('students')
        .select('id,student_number,first_name,last_name,status')
        .eq('school_id', caller.school_id)
        .order('last_name').order('first_name').limit(1000)
      if (studentsError) return errorResponse('Impossible de charger les élèves de cette école.', 500)
      const [{ data: years, error: yearsError }, { data: parents, error: parentsError }] = await Promise.all([
        ctx.supabaseAdmin.from('school_years')
          .select('id,is_current').eq('school_id', caller.school_id).order('start_date', { ascending: false }),
        ctx.supabaseAdmin.from('parents').select('id,first_name,last_name,phone')
          .eq('school_id', caller.school_id).order('last_name').order('first_name').limit(1000),
      ])
      if (yearsError || parentsError) return errorResponse('Impossible de charger les listes financières.', 500)
      const currentYear = (years ?? []).find((year: any) => year.is_current) ?? years?.[0]
      let classes: any[] = []
      let enrollments: any[] = []
      if (currentYear) {
        const [{ data: classRows, error: classError }, { data: enrollmentRows, error: enrollmentError }] = await Promise.all([
          ctx.supabaseAdmin.from('classes').select('id,name,code').eq('school_id', caller.school_id).eq('school_year_id', currentYear.id).order('name'),
          ctx.supabaseAdmin.from('enrollments').select('student_id,class_id,education_stage').eq('school_id', caller.school_id).eq('school_year_id', currentYear.id).eq('status', 'enrolled'),
        ])
        if (classError || enrollmentError) return errorResponse('Impossible de charger les classes et inscriptions de cette école.', 500)
        classes = classRows ?? []
        enrollments = enrollmentRows ?? []
      }
      return Response.json({ students: students ?? [], classes, enrollments, parents: parents ?? [] })
    }

    const { data: assignments, error: assignmentsError } = await ctx.supabaseAdmin
      .from('user_roles').select('roles(code)').eq('user_id', callerId).eq('is_active', true)
    if (assignmentsError) return errorResponse('Impossible de vérifier vos autorisations.', 500)
    if (!(assignments ?? []).some((assignment: any) => ['it_admin', 'super_admin'].includes(assignment.roles?.code))) {
      return errorResponse('Seul un Administrateur informatique ou système peut gérer et consulter les comptes.', 403)
    }

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

    if (action === 'set-password') {
      const userId = typeof body.userId === 'string' ? body.userId : ''
      const password = typeof body.password === 'string' ? body.password : ''
      if (!uuid.test(userId)) return errorResponse('Utilisateur invalide.', 400)
      if (password.length < 10 || password.length > 128) return errorResponse('Le mot de passe doit contenir entre 10 et 128 caractères.', 400)

      const { data: target, error: targetError } = await ctx.supabaseAdmin
        .from('users').select('id').eq('id', userId).maybeSingle()
      if (targetError) return errorResponse('Impossible de vérifier le compte ciblé.', 500)
      if (!target) return errorResponse('Compte introuvable.', 404)
      if (target.id === callerId) return errorResponse('Vous ne pouvez pas modifier votre propre mot de passe depuis cette page.', 403)

      const { error } = await ctx.supabaseAdmin.auth.admin.updateUserById(target.id, { password })
      if (error) return errorResponse(`Impossible de définir le mot de passe : ${error.message}`, 400)
      return Response.json({ updated: true })
    }

    const schoolId = typeof body.schoolId === 'string' ? body.schoolId : ''
    const userId = typeof body.userId === 'string' ? body.userId : ''
    if (!uuid.test(schoolId) || !uuid.test(userId)) return errorResponse('Utilisateur ou école invalide.', 400)

    const { data: target, error: targetError } = await ctx.supabaseAdmin.from('users')
      .select('id,school_id,education_stage,email').eq('id', userId).eq('school_id', schoolId).maybeSingle()
    if (targetError) return errorResponse('Impossible de vérifier le compte ciblé.', 500)
    if (!target) return errorResponse('Compte introuvable dans cette école.', 404)
    if (target.id === callerId) return errorResponse('Vous ne pouvez pas supprimer ou modifier votre propre compte.', 403)

    if (action === 'teacher-profiles') {
      const { data: roles, error: rolesError } = await ctx.supabaseAdmin.from('user_roles')
        .select('roles(code)').eq('user_id', userId).eq('school_id', schoolId).eq('is_active', true)
      if (rolesError) return errorResponse('Impossible de vérifier le rôle du compte.', 500)
      if (!(roles ?? []).some((row: any) => row.roles?.code === 'teacher')) return errorResponse('Ce compte ne possède pas le rôle enseignant dans cette école.', 403)
      const { data: employees, error } = await ctx.supabaseAdmin.from('employees')
        .select('id,first_name,last_name,employee_number,user_id,teacher_profiles!inner(employee_id)')
        .eq('school_id', schoolId).eq('status', 'active').order('last_name').order('first_name')
      if (error) return errorResponse('Impossible de charger les profils enseignants.', 500)
      return Response.json({ profiles: (employees ?? []).filter((employee: any) => !employee.user_id || employee.user_id === userId) })
    }

    if (action === 'link-teacher-profile') {
      const employeeId = typeof body.employeeId === 'string' ? body.employeeId : ''
      if (!uuid.test(employeeId)) return errorResponse('Profil enseignant invalide.', 400)
      const { data: roles, error: rolesError } = await ctx.supabaseAdmin.from('user_roles')
        .select('roles(code)').eq('user_id', userId).eq('school_id', schoolId).eq('is_active', true)
      if (rolesError) return errorResponse('Impossible de vérifier le rôle du compte.', 500)
      if (!(roles ?? []).some((row: any) => row.roles?.code === 'teacher')) return errorResponse('Ce compte ne possède pas le rôle enseignant dans cette école.', 403)
      const { data: employee, error: employeeError } = await ctx.supabaseAdmin.from('employees')
        .select('id,user_id,teacher_profiles!inner(employee_id)').eq('id', employeeId).eq('school_id', schoolId).eq('status', 'active').maybeSingle()
      if (employeeError) return errorResponse('Impossible de vérifier le profil enseignant.', 500)
      if (!employee) return errorResponse('Profil enseignant introuvable dans cette école.', 404)
      if (employee.user_id && employee.user_id !== userId) return errorResponse('Ce profil est déjà relié à un autre compte.', 409)
      // Use the validated RPC for both new links and corrections. A direct
      // UPDATE fires the education-stage trigger even when the link is unchanged.
      const { error } = await ctx.supabaseAdmin.rpc('set_teacher_profile_link', {
        p_actor_user_id: callerId,
        p_user_id: userId,
        p_school_id: schoolId,
        p_employee_id: employeeId,
      })
      if (error) return errorResponse(`Impossible de relier le profil : ${error.message}`, 400)
      return Response.json({ linked: true })
    }

    const selectedStage = typeof body.educationStage === 'string' ? body.educationStage : ''
    if (!stages.has(selectedStage) || (target.education_stage ?? 'parent') !== selectedStage) {
      return errorResponse('Le cycle du compte a changé. Actualisez la liste avant de recommencer.', 409)
    }

    if (action === 'update-stage') {
      const newStage = typeof body.newEducationStage === 'string' ? body.newEducationStage : ''
      if (!stages.has(newStage)) return errorResponse('Cycle invalide.', 400)
      // Keep the caller JWT so users.manage is visible to the education-stage trigger.
      const { data: updatedUser, error } = await ctx.supabase.from('users')
        .update({ education_stage: newStage === 'parent' ? null : newStage })
        .eq('id', userId).eq('school_id', schoolId).select('id').maybeSingle()
      if (error) return errorResponse(`Impossible de modifier le cycle : ${error.message}`, 400)
      if (!updatedUser) return errorResponse('Vous n’êtes pas autorisé à modifier le cycle de ce compte.', 403)
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
