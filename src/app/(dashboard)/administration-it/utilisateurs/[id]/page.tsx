import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'
import { linkTeacherProfile, setTemporaryPassword } from './actions'

export default async function ManageUserAccountPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; updated?: string; linked?: string }> }) {
  const [context, { id }, query] = await Promise.all([getCurrentUserContext(), params, searchParams])
  if (!context?.roles.some(({ code }) => code === 'it_admin' || code === 'super_admin')) redirect('/dashboard')
  const supabase = await createClient()
  const { data: user } = await supabase.from('users').select('id,school_id,first_name,last_name,username,email').eq('id', id).maybeSingle()
  if (!user) notFound()

  const [rolesResult, directoryResult] = await Promise.all([
    user.school_id
      ? supabase.from('user_roles').select('roles(code)').eq('user_id', user.id).eq('school_id', user.school_id).eq('is_active', true)
      : Promise.resolve({ data: [], error: null }),
    user.school_id
      ? supabase.functions.invoke('managed-user-directory', { body: { action: 'teacher-profiles', schoolId: user.school_id, userId: user.id } })
      : Promise.resolve({ data: null, error: null }),
  ])
  const roleRows = rolesResult.data
  const isTeacher = (roleRows ?? []).some((row: any) => row.roles?.code === 'teacher')
  const directory = directoryResult.data
  const directoryError = directoryResult.error

  return <main className="page user-account-page">
    <div className="page-header user-account-header">
      <div><span className="user-directory-eyebrow">Administration des comptes</span><h1 className="page-title">Compte de {user.first_name} {user.last_name}</h1><p className="page-subtitle">{user.username ? `@${user.username}` : user.email}</p></div>
      <Link className="button button-secondary" href="/administration-it/utilisateurs">Retour aux utilisateurs</Link>
    </div>
    {query.error ? <p className="error user-notice" role="alert">{query.error}</p> : null}
    {query.updated ? <p className="success user-notice" role="status">Mot de passe temporaire défini.</p> : null}
    {query.linked ? <p className="success user-notice" role="status">Le compte est relié au profil enseignant.</p> : null}

    {isTeacher ? <section className="card user-account-card">
      <div className="user-section-heading"><span className="user-section-icon" aria-hidden="true">↔</span><div><h2>Profil enseignant</h2><p>Reliez ce compte à la fiche correspondante pour donner accès aux classes, matières et évaluations affectées.</p></div></div>
      {directoryError ? <p className="error user-notice" role="alert">Impossible de charger les profils enseignants. {directoryError.message}</p>
        : Array.isArray(directory?.profiles) && directory.profiles.length ? <form action={linkTeacherProfile} className="user-link-form">
          <input type="hidden" name="userId" value={user.id}/><input type="hidden" name="schoolId" value={user.school_id ?? ''}/>
          <label className="field"><span className="label">Fiche enseignant correspondante</span><select className="select" name="employeeId" required defaultValue=""><option value="">Sélectionner une fiche</option>{directory.profiles.map((employee: any) => <option key={employee.id} value={employee.id}>{employee.last_name} {employee.first_name} · N° {employee.employee_number ?? '—'}</option>)}</select><small>Vérifiez le nom et le numéro avant de confirmer la liaison.</small></label>
          <button className="button button-primary">Lier le compte au profil</button>
        </form>
        : <div className="user-empty-profiles"><strong>Aucune fiche disponible</strong><p>{Array.isArray(directory?.profiles) ? 'Aucun profil enseignant actif et libre n’a été trouvé dans cette école.' : 'Vérifiez que ce compte possède le rôle enseignant et réessayez.'}</p></div>}
    </section> : <section className="card user-account-card user-role-hint"><strong>Ce compte n’a pas le rôle Enseignant.</strong><p>Attribuez d’abord le rôle enseignant dans « Rôles et permissions » pour pouvoir lui associer une fiche.</p><Link className="button button-secondary" href={`/administration-it/acces?userId=${user.id}`}>Gérer les rôles</Link></section>}

    <section className="card user-account-card">
      <div className="user-section-heading"><span className="user-section-icon" aria-hidden="true">•••</span><div><h2>Mot de passe temporaire</h2><p>L’ancien mot de passe ne peut pas être consulté. L’utilisateur pourra remplacer le mot de passe temporaire depuis « Mon compte ».</p></div></div>
      <form action={setTemporaryPassword} className="user-password-form"><input type="hidden" name="userId" value={user.id}/><div className="field"><label className="label" htmlFor="password">Nouveau mot de passe temporaire</label><input className="input" id="password" name="password" type="password" autoComplete="new-password" minLength={10} maxLength={128} required/><small>Au moins 10 caractères.</small></div><button className="button button-primary">Définir le mot de passe</button></form>
    </section>
  </main>
}
