import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function ITUsersPage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const [{ data: users, error }, { data: assignments }] = await Promise.all([
    supabase.from('users').select('id,first_name,last_name,email,status,last_login,created_at').eq('school_id', context.profile.school_id).order('last_name').limit(200),
    supabase.from('user_roles').select('user_id,roles(name,code)').eq('school_id', context.profile.school_id).eq('is_active', true),
  ])

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Utilisateurs</h1><p className="page-subtitle">Comptes et rôles actifs de l’établissement.</p></div><span className="badge">{users?.length ?? 0} compte(s)</span></div>
      {error ? <p className="error">Impossible de charger les comptes : {error.message}</p> : null}
      <section className="table-wrap">
        <table>
          <thead><tr><th>Nom</th><th>E-mail</th><th>Rôle(s)</th><th>État</th><th>Dernière connexion</th></tr></thead>
          <tbody>
            {(users ?? []).map((user) => {
              const roles = (assignments ?? []).filter((assignment: any) => assignment.user_id === user.id).map((assignment: any) => assignment.roles?.name).filter(Boolean)
              return <tr key={user.id}><td>{user.first_name} {user.last_name}</td><td>{user.email ?? '—'}</td><td>{roles.length ? roles.join(', ') : 'Aucun rôle actif'}</td><td><span className="badge">{user.status}</span></td><td>{user.last_login ? new Date(user.last_login).toLocaleString('fr-FR') : 'Jamais'}</td></tr>
            })}
          </tbody>
        </table>
        {!users?.length ? <p className="empty">Aucun compte trouvé pour cet établissement.</p> : null}
      </section>
      <p className="page-subtitle" style={{ marginTop: 12 }}>La liste est limitée aux comptes rattachés à l’établissement connecté.</p>
    </main>
  )
}
