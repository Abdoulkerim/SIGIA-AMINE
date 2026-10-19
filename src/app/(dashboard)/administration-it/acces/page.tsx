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
  'users.roles.manage': [{ label: 'Accès utilisateurs', href: '/administration-it/acces' }, { label: 'Rôles et permissions', href: '/administration-it/roles' }],
  'audit.view': [{ label: 'Journal d’audit', href: '/administration-it/audit' }],
  'settings.manage': [{ label: 'Paramètres établissement', href: '/administration-it/parametres' }],
  'students.view': [{ label: 'Élèves', href: '/administration/eleves' }],
  'students.manage': [{ label: 'Élèves', href: '/administration/eleves' }],
  'parents.view': [{ label: 'Parents', href: '/administration/parents' }],
  'parents.manage': [{ label: 'Parents', href: '/administration/parents' }],
  'enrollments.manage': [{ label: 'Admissions', href: '/administration/admissions' }, { label: 'Inscriptions', href: '/administration/inscriptions' }],
  'classes.manage': [{ label: 'Niveaux et classes', href: '/administration/classes' }],
  'subjects.manage': [{ label: 'Matières', href: '/pedagogie/matieres' }],
  'teachers.manage': [{ label: 'Enseignants', href: '/personnel/enseignants' }],
  'timetable.manage': [{ label: 'Emploi du temps', href: '/pedagogie/emploi-du-temps' }],
  'assessments.manage': [{ label: 'Évaluations', href: '/pedagogie/evaluations' }],
  'grades.enter': [{ label: 'Saisie des notes', href: '/pedagogie/evaluations' }],
  'grades.publish': [{ label: 'Publication des notes', href: '/pedagogie/bulletins' }],
  'report_cards.generate': [{ label: 'Bulletins', href: '/pedagogie/bulletins' }],
  'attendance.manage': [{ label: 'Présences', href: '/vie-scolaire/presences' }],
  'discipline.manage': [{ label: 'Discipline', href: '/vie-scolaire/discipline' }],
  'finance.view': [{ label: 'Finance', href: '/finance' }],
  'finance.manage': [{ label: 'Factures et paiements', href: '/finance/factures' }],
  'expenses.manage': [{ label: 'Dépenses', href: '/finance/depenses' }],
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
  'livestock.manage': [{ label: 'Élevage', href: '/activites/elevage' }],
  'communication.manage': [{ label: 'Communication', href: '/communication' }],
  'documents.view': [{ label: 'Documents', href: '/documents' }],
  'documents.manage': [{ label: 'Gestion documentaire', href: '/documents' }],
  'reports.view': [{ label: 'Statistiques', href: '/statistiques' }],
  'ai.use': [{ label: 'Assistant IA', href: '/ia' }],
}

export default async function UserAccessPage({ searchParams }: { searchParams: Promise<{ userId?: string; error?: string; updated?: string }> }) {
  const params = await searchParams
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return <main className="page"><p className="empty">Aucun établissement associé à ce compte.</p></main>

  const schoolId = context.profile.school_id
  const supabase = await createClient()
  const [{ data: users, error: usersError }, { data: roles, error: rolesError }] = await Promise.all([
    supabase.from('users').select('id,first_name,last_name,email,status,education_stage').eq('school_id', schoolId).order('last_name').limit(300),
    supabase.from('roles').select('id,name,code,description,role_permissions(permissions(code,name,module,action))').order('name'),
  ])

  const selectedUser = (users ?? []).find((user) => user.id === params.userId)
    ?? (users ?? []).find((user) => user.id !== context.profile.id)
    ?? users?.[0]

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
      <div className="page-header"><div><h1 className="page-title">Accès utilisateurs</h1><p className="page-subtitle">Attribuez les rôles, contrôlez l’accès à la connexion et consultez les pages ouvertes à chaque compte.</p></div><span className="badge">Contrôle d’accès</span></div>
      {params.error ? <p className="error">{params.error}</p> : null}
      {params.updated === 'role' ? <p className="success">Les rôles de l’utilisateur ont été mis à jour.</p> : null}
      {params.updated === 'status' ? <p className="success">L’accès à la connexion a été mis à jour.</p> : null}
      {params.updated === 'stage' ? <p className="success">Le cycle scolaire de l’utilisateur a été mis à jour.</p> : null}
      {usersError ? <p className="error">Impossible de charger les utilisateurs : {usersError.message}</p> : null}
      {rolesError ? <p className="error">Impossible de charger les rôles : {rolesError.message}</p> : null}

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
                <div><h2>{selectedUser.first_name} {selectedUser.last_name}</h2><p className="page-subtitle">{selectedUser.email ?? 'Adresse e-mail non renseignée'}</p></div>
                <span className={`it-user-status status-${selectedUser.status}`}>{selectedUser.status === 'active' ? 'Connexion autorisée' : selectedUser.status === 'suspended' ? 'Connexion suspendue' : 'Compte inactif'}</span>
              </div>
              {selectedUser.id === context.profile.id ? <p className="error" style={{ marginTop: 16 }}>Votre propre compte est protégé : choisissez un autre utilisateur pour modifier ses accès.</p> : (
                <>
                  <form action={updateUserLoginAccess} className="it-access-status-form">
                    <input type="hidden" name="userId" value={selectedUser.id} />
                    <label className="field" style={{ margin: 0 }}><span className="label">Accès à la connexion</span><select className="select" name="status" defaultValue={selectedUser.status}><option value="active">Autorisé</option><option value="suspended">Suspendu</option><option value="inactive">Désactivé</option></select></label>
                    <button className="button button-primary" type="submit">Enregistrer l’accès</button>
                  </form>
                  <form action={updateUserEducationStage} className="it-access-status-form" style={{ marginTop: 14 }}>
                    <input type="hidden" name="userId" value={selectedUser.id} />
                    <label className="field" style={{ margin: 0, flex: 1 }}><span className="label">Données accessibles</span><select className="select" name="educationStage" required defaultValue={selectedUser.education_stage ?? ''}><option value="" disabled>Choisir le cycle autorisé…</option>{Object.entries(educationStages).map(([value, label]) => <option value={value} key={value}>{label}</option>)}<option value="parent">Parent — enfants rattachés uniquement</option></select></label>
                    <button className="button button-primary" type="submit">Enregistrer le cycle</button>
                  </form>
                  <p className="page-subtitle" style={{ marginTop: 8 }}>Un compte ordinaire est limité à un seul cycle. Les parents voient uniquement les dossiers de leurs enfants.</p>
                </>
              )}
            </section>

            <section className="card">
              <h2 style={{ marginTop: 0 }}>Rôles et privilèges</h2>
              {assignmentsError ? <p className="error">Impossible de charger les rôles de cet utilisateur : {assignmentsError.message}</p> : null}
              {selectedUser.id !== context.profile.id ? (
                <form action={assignUserRole} className="it-access-status-form">
                  <input type="hidden" name="userId" value={selectedUser.id} />
                  <label className="field" style={{ margin: 0, flex: 1 }}><span className="label">Ajouter ou réactiver un rôle</span><select className="select" name="roleId" required defaultValue=""><option value="" disabled>Choisir un rôle…</option>{assignableRoles.map((role) => <option value={role.id} key={role.id}>{role.name}</option>)}</select></label>
                  <button className="button button-primary" type="submit">Attribuer le rôle</button>
                </form>
              ) : null}
              <div className="it-access-role-list">
                {(assignments ?? []).map((assignment: any) => (
                  <div className="it-access-role" key={assignment.id}>
                    <div><strong>{assignment.roles?.name ?? 'Rôle'}</strong><small>{assignment.roles?.code}</small></div>
                    <span className={`it-user-status ${assignment.is_active ? 'status-active' : 'status-inactive'}`}>{assignment.is_active ? 'Actif' : 'Retiré'}</span>
                    {assignment.is_active && selectedUser.id !== context.profile.id ? <form action={revokeUserRole}><input type="hidden" name="userId" value={selectedUser.id} /><input type="hidden" name="roleId" value={assignment.role_id} /><button className="button button-secondary" type="submit">Retirer</button></form> : null}
                  </div>
                ))}
                {!assignments?.length ? <p className="empty">Aucun rôle attribué à cet utilisateur.</p> : null}
              </div>
            </section>

            <section className="card">
              <div className="page-header" style={{ marginBottom: 14 }}><div><h2 className="page-title" style={{ fontSize: 20 }}>Pages accessibles</h2><p className="page-subtitle">Pages associées aux privilèges des rôles actifs de cet utilisateur.</p></div><span className="badge">{accessiblePages.size} page(s)</span></div>
              {selectedUser.status !== 'active' ? <p className="error">Le compte est désactivé : aucune page de l’application n’est accessible.</p> : accessiblePages.size ? <div className="it-access-page-list">{Array.from(accessiblePages.values()).map((page) => <Link className="it-access-page" href={page.href} key={page.href}>{page.label}<span aria-hidden="true">↗</span></Link>)}</div> : <p className="empty">Aucun privilège actif ne donne accès aux pages répertoriées.</p>}
              <details className="it-access-permissions"><summary>Voir les permissions effectives ({permissions.size})</summary><div className="it-permission-list">{Array.from(permissions.values()).map((permission) => <span className="it-permission-chip" key={permission.code} title={`${permission.module} · ${permission.code}`}>{permission.name}</span>)}</div></details>
            </section>
          </div>
        ) : <section className="card empty">Sélectionnez un utilisateur pour gérer ses accès.</section>}
      </section>
    </main>
  )
}
