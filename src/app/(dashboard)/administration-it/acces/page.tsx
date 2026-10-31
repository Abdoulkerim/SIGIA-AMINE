import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { assignUserRole, revokeUserRole, updateUserEducationStage, updateUserLoginAccess } from '../access-actions'

const educationStages: Record<string, string> = {
  maternelle: 'Maternelle',
  primaire: 'Primaire',
  secondaire: 'Secondaire',
  formation: 'Centre de formation',
  autre: 'Autre',
}

const pageByPermission: Record<string, { label: string; href: string }[]> = {
  'users.manage': [{ label: 'Utilisateurs', href: '/administration-it/utilisateurs' }],
  'users.roles.manage': [{ label: 'AccÃ¨s utilisateurs', href: '/administration-it/acces' }, { label: 'RÃ´les et permissions', href: '/administration-it/roles' }],
  'audit.view': [{ label: 'Journal dâ€™audit', href: '/administration-it/audit' }],
  'settings.manage': [{ label: 'ParamÃ¨tres Ã©tablissement', href: '/administration-it/parametres' }],
  'students.view': [{ label: 'Ã‰lÃ¨ves', href: '/administration/eleves' }],
  'students.manage': [{ label: 'Ã‰lÃ¨ves', href: '/administration/eleves' }],
  'parents.view': [{ label: 'Parents', href: '/administration/parents' }],
  'parents.manage': [{ label: 'Parents', href: '/administration/parents' }],
  'enrollments.manage': [{ label: 'Admissions', href: '/administration/admissions' }, { label: 'Inscriptions', href: '/administration/inscriptions' }],
  'classes.manage': [{ label: 'Niveaux et classes', href: '/administration/classes' }],
  'subjects.manage': [{ label: 'MatiÃ¨res', href: '/pedagogie/matieres' }],
  'teachers.manage': [{ label: 'Enseignants', href: '/personnel/enseignants' }],
  'timetable.manage': [{ label: 'Emploi du temps', href: '/pedagogie/emploi-du-temps' }],
  'assessments.manage': [{ label: 'Ã‰valuations', href: '/pedagogie/evaluations' }],
  'grades.enter': [{ label: 'Saisie des notes', href: '/pedagogie/evaluations' }],
  'grades.publish': [{ label: 'Publication des notes', href: '/pedagogie/bulletins' }],
  'report_cards.generate': [{ label: 'Bulletins', href: '/pedagogie/bulletins' }],
  'attendance.manage': [{ label: 'PrÃ©sences', href: '/vie-scolaire/presences' }],
  'discipline.manage': [{ label: 'Discipline', href: '/vie-scolaire/discipline' }],
  'finance.view': [{ label: 'Finance', href: '/finance' }],
  'finance.manage': [{ label: 'Factures et paiements', href: '/finance/factures' }],
  'expenses.manage': [{ label: 'DÃ©penses', href: '/finance/depenses' }],
  'cash.manage': [{ label: 'Caisse', href: '/finance/caisse' }],
  'boarding.manage': [{ label: 'Internat', href: '/internat' }],
  'catering.manage': [{ label: 'Restauration', href: '/restauration' }],
  'tahfiz.manage': [{ label: 'Tahfiz', href: '/tahfiz-arabe/tahfiz' }],
  'arabic.manage': [{ label: 'Arabe', href: '/tahfiz-arabe/arabe' }],
  'wushu.manage': [{ label: 'Wushu', href: '/wushu' }],
  'hr.manage': [{ label: 'Personnel et RH', href: '/personnel' }],
  'stock.manage': [{ label: 'Stocks', href: '/stocks' }],
  'purchases.manage': [{ label: 'Achats', href: '/stocks/commandes' }],
  'agriculture.manage': [{ label: 'Agriculture', href: '/activites/agriculture' }],
  'livestock.manage': [{ label: 'Ã‰levage', href: '/activites/elevage' }],
  'communication.manage': [{ label: 'Communication', href: '/communication' }],
  'documents.view': [{ label: 'Documents', href: '/documents' }],
  'documents.manage': [{ label: 'Gestion documentaire', href: '/documents' }],
  'reports.view': [{ label: 'Statistiques', href: '/statistiques' }],
  'ai.use': [{ label: 'Assistant IA', href: '/ia' }],
}

export default async function UserAccessPage({ searchParams }: { searchParams: Promise<{ userId?: string; error?: string; updated?: string }> }) {
  const params = await searchParams
  const context = await getCurrentUserContext()
  if (!context?.roles.some(({ code }) => code === 'it_admin')) return <main className="page"><p className="error">Seul un Administrateur informatique peut gérer les accès utilisateurs.</p></main>
  if (!context.profile.school_id) return <main className="page"><p className="empty">Aucun établissement associé à ce compte.</p></main>

  const schoolId = context.profile.school_id
  const supabase = await createClient()
  const [{ data: users, error: usersError }, { data: roles, error: rolesError }] = await Promise.all([
    supabase.from('users').select('id,first_name,last_name,email,status,education_stage').eq('school_id', schoolId).order('last_name').limit(300),
    supabase.from('roles').select('id,name,code,description,role_permissions(permissions(code,name,module,action))').order('name'),
  ])

  const selectedUser = (users ?? []).find((user) => user.id === params.userId)
    ?? (users ?? []).find((user) => user.id !== context.profile.id)
    ?? users?.[0]
  const isOwnAccount = selectedUser?.id === context.profile.id
  const canSetOwnInitialStage = isOwnAccount && selectedUser?.education_stage === null

  const { data: assignments, error: assignmentsError } = selectedUser
    ? await supabase.from('user_roles')
        .select('id,role_id,is_active,roles(id,name,code,role_permissions(permissions(code,name,module,action)))')
        .eq('user_id', selectedUser.id)
        .eq('school_id', schoolId)
        .order('created_at')
    : { data: [], error: null }

  const isPrivilegedManager = context.roles.some(({ code }) => ['super_admin', 'founder'].includes(code ?? ''))
  const assignableRoles = (roles ?? []).filter((role) => isPrivilegedManager || !['super_admin', 'founder', 'it_admin'].includes(role.code))
  const permissions = new Map<string, { code: string; name: string; module: string }>()
  for (const assignment of assignments ?? []) {
    if (!assignment.is_active) continue
    const role = assignment.roles as any
    for (const item of role?.role_permissions ?? []) {
      const permission = item.permissions
      if (permission?.code) permissions.set(permission.code, permission)
    }
  }
  const accessiblePages = new Map<string, { label: string; href: string }>()
  if (selectedUser?.status === 'active') {
    for (const permission of permissions.values()) {
      for (const page of pageByPermission[permission.code] ?? []) accessiblePages.set(page.href, page)
    }
  }

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">AccÃ¨s utilisateurs</h1><p className="page-subtitle">Attribuez les rÃ´les, contrÃ´lez lâ€™accÃ¨s Ã  la connexion et consultez les pages ouvertes Ã  chaque compte.</p></div><span className="badge">ContrÃ´le dâ€™accÃ¨s</span></div>
      {params.error ? <p className="error">{params.error}</p> : null}
      {params.updated === 'role' ? <p className="success">Les rÃ´les de lâ€™utilisateur ont Ã©tÃ© mis Ã  jour.</p> : null}
      {params.updated === 'status' ? <p className="success">Lâ€™accÃ¨s Ã  la connexion a Ã©tÃ© mis Ã  jour.</p> : null}
      {params.updated === 'stage' ? <p className="success">Le cycle scolaire de lâ€™utilisateur a Ã©tÃ© mis Ã  jour.</p> : null}
      {usersError ? <p className="error">Impossible de charger les utilisateurs : {usersError.message}</p> : null}
      {rolesError ? <p className="error">Impossible de charger les rÃ´les : {rolesError.message}</p> : null}

      <section className="it-access-layout">
        <aside className="card it-access-user-list">
          <h2>Utilisateurs</h2>
          <div className="it-access-users">
            {(users ?? []).map((user) => (
              <Link className={`it-access-user${selectedUser?.id === user.id ? ' is-selected' : ''}`} href={`/administration-it/acces?userId=${user.id}`} key={user.id}>
                <span className="it-access-user-avatar" aria-hidden="true">{user.first_name?.[0]}{user.last_name?.[0]}</span>
                <span className="it-access-user-copy"><strong>{user.first_name} {user.last_name}</strong><small>{user.email ?? 'Sans e-mail'}</small></span>
                <span className="badge">{user.education_stage ? educationStages[user.education_stage] ?? user.education_stage : 'Sans cycle'}</span>
                <span className={`it-user-status status-${user.status}`}>{user.status === 'active' ? 'Actif' : user.status === 'suspended' ? 'Suspendu' : 'Inactif'}</span>
              </Link>
            ))}
          </div>
          {!users?.length ? <p className="empty">Aucun utilisateur.</p> : null}
        </aside>

        {selectedUser ? (
          <div className="it-access-details">
            <section className="card">
              <div className="it-access-profile">
                <div><h2>{selectedUser.first_name} {selectedUser.last_name}</h2><p className="page-subtitle">{selectedUser.email ?? 'Adresse e-mail non renseignÃ©e'}</p></div>
                <span className={`it-user-status status-${selectedUser.status}`}>{selectedUser.status === 'active' ? 'Connexion autorisÃ©e' : selectedUser.status === 'suspended' ? 'Connexion suspendue' : 'Compte inactif'}</span>
              </div>
              {isOwnAccount && !canSetOwnInitialStage ? (
                <p className="error" style={{ marginTop: 16 }}>Votre propre compte est protÃ©gÃ© : son cycle dÃ©jÃ  attribuÃ© ne peut pas Ãªtre modifiÃ© ici.</p>
              ) : (
                <>
                  {!isOwnAccount ? (
                    <form action={updateUserLoginAccess} className="it-access-status-form">
                      <input type="hidden" name="userId" value={selectedUser.id} />
                      <label className="field" style={{ margin: 0 }}><span className="label">AccÃ¨s Ã  la connexion</span><select className="select" name="status" defaultValue={selectedUser.status}><option value="active">Autorise</option><option value="suspended">Suspendu</option><option value="inactive">DÃ©sactivÃ©</option></select></label>
                      <button className="button button-primary" type="submit">Enregistrer lâ€™accÃ¨s</button>
                    </form>
                  ) : null}
                  <form action={updateUserEducationStage} className="it-access-status-form" style={{ marginTop: 14 }}>
                    <input type="hidden" name="userId" value={selectedUser.id} />
                    <label className="field" style={{ margin: 0, flex: 1 }}><span className="label">DonnÃ©es accessibles</span><select className="select" name="educationStage" required defaultValue={canSetOwnInitialStage ? '' : selectedUser.education_stage ?? ''}><option value="" disabled>Choisir le cycle autorisÃ©</option>{Object.entries(educationStages).map(([value, label]) => <option value={value} key={value}>{label}</option>)}{!isOwnAccount ? <option value="parent">Parent â€” enfants rattachÃ©s uniquement</option> : null}</select></label>
                    <button className="button button-primary" type="submit">Enregistrer le cycle</button>
                  </form>
                  {canSetOwnInitialStage
                    ? <p className="page-subtitle" style={{ marginTop: 8 }}>Attribuez le cycle initial de votre compte. Vous pourrez ensuite demander Ã  un autre administrateur de le modifier.</p>
                    : <p className="page-subtitle" style={{ marginTop: 8 }}>Un compte ordinaire est limitÃ© Ã  un seul cycle. Les parents voient uniquement les dossiers de leurs enfants.</p>}
                </>
              )}
            </section>

            <section className="card">
              <h2 style={{ marginTop: 0 }}>RÃ´les et privilÃ¨ges</h2>
              {assignmentsError ? <p className="error">Impossible de charger les rÃ´les de cet utilisateur : {assignmentsError.message}</p> : null}
              {selectedUser.id !== context.profile.id ? (
                <form action={assignUserRole} className="it-access-status-form">
                  <input type="hidden" name="userId" value={selectedUser.id} />
                  <label className="field" style={{ margin: 0, flex: 1 }}><span className="label">Ajouter ou rÃ©activer un rÃ´le</span><select className="select" name="roleId" required defaultValue=""><option value="" disabled>Choisir un rÃ´leâ€¦</option>{assignableRoles.map((role) => <option value={role.id} key={role.id}>{role.name}</option>)}</select></label>
                  <button className="button button-primary" type="submit">Attribuer le rÃ´le</button>
                </form>
              ) : null}
              <div className="it-access-role-list">
                {(assignments ?? []).map((assignment: any) => (
                  <div className="it-access-role" key={assignment.id}>
                    <div><strong>{assignment.roles?.name ?? 'RÃ´le'}</strong><small>{assignment.roles?.code}</small></div>
                    <span className={`it-user-status ${assignment.is_active ? 'status-active' : 'status-inactive'}`}>{assignment.is_active ? 'Actif' : 'RetirÃ©'}</span>
                    {assignment.is_active && selectedUser.id !== context.profile.id ? <form action={revokeUserRole}><input type="hidden" name="userId" value={selectedUser.id} /><input type="hidden" name="roleId" value={assignment.role_id} /><button className="button button-secondary" type="submit">Retirer</button></form> : null}
                  </div>
                ))}
                {!assignments?.length ? <p className="empty">Aucun rÃ´le attribuÃ© Ã  cet utilisateur.</p> : null}
              </div>
            </section>

            <section className="card">
              <div className="page-header" style={{ marginBottom: 14 }}><div><h2 className="page-title" style={{ fontSize: 20 }}>Pages accessibles</h2><p className="page-subtitle">Pages associÃ©es aux privilÃ¨ges des rÃ´les actifs de cet utilisateur.</p></div><span className="badge">{accessiblePages.size} page(s)</span></div>
              {selectedUser.status !== 'active' ? <p className="error">Le compte est dÃ©sactivÃ© : aucune page de lâ€™application nâ€™est accessible.</p> : accessiblePages.size ? <div className="it-access-page-list">{Array.from(accessiblePages.values()).map((page) => <Link className="it-access-page" href={page.href} key={page.href}>{page.label}<span aria-hidden="true">â†—</span></Link>)}</div> : <p className="empty">Aucun privilÃ¨ge actif ne donne accÃ¨s aux pages rÃ©pertoriÃ©es.</p>}
              <details className="it-access-permissions"><summary>Voir les permissions effectives ({permissions.size})</summary><div className="it-permission-list">{Array.from(permissions.values()).map((permission) => <span className="it-permission-chip" key={permission.code} title={`${permission.module} Â· ${permission.code}`}>{permission.name}</span>)}</div></details>
            </section>
          </div>
        ) : <section className="card empty">SÃ©lectionnez un utilisateur pour gÃ©rer ses accÃ¨s.</section>}
      </section>
    </main>
  )
}
