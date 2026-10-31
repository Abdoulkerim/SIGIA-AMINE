import Link from 'next/link'
import { redirect } from 'next/navigation'
import { FunctionsHttpError } from '@supabase/supabase-js'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { deleteManagedUser, updateManagedUserStage } from './directory-actions'

const stages = [['all','Tous les cycles'],['maternelle','Maternelle'],['primaire','Primaire'],['secondaire','Secondaire'],['formation','Centre de formation'],['autre','Autre'],['parent','Parent — enfants rattachés uniquement']]
const statuses = [['all','Tous les états'],['active','Actif'],['inactive','Inactif'],['suspended','Suspendu']]

export default async function ITUsersPage({ searchParams }: { searchParams: Promise<{ schoolId?: string; educationStage?: string; status?: string; created?: string; updated?: string; deleted?: string; error?: string }> }) {
  const params = await searchParams
  const context = await getCurrentUserContext()
  if (!context?.roles.some(({ code }) => code === 'it_admin')) redirect('/dashboard')
  const selectedStage = stages.some(([value]) => value === params.educationStage) ? params.educationStage! : 'all'
  const selectedStatus = statuses.some(([value]) => value === params.status) ? params.status! : 'all'
  const supabase = await createClient()
  const { data: directory, error } = await supabase.functions.invoke('managed-user-directory', {
    body: { action: 'list', schoolId: params.schoolId || '', educationStage: selectedStage, status: selectedStatus },
  })
  let errorMessage = error ? 'Impossible de charger les comptes. Vérifiez le déploiement de managed-user-directory.' : directory?.error
  if (error instanceof FunctionsHttpError) {
    try { const result = await error.context.json(); if (typeof result?.error === 'string') errorMessage = result.error } catch { /* Réponse non JSON. */ }
  }
  const schools = directory?.schools ?? []
  const users = directory?.users ?? []
  const schoolName = schools.find((school: {id:string}) => school.id === params.schoolId)?.name
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Utilisateurs</h1><p className="page-subtitle">Administration des comptes par école, cycle et état.</p></div><div className="actions"><Link className="button button-primary" href="/administration-it/utilisateurs/nouveau">Créer un compte</Link></div></div>
    {params.created ? <p className="success">Le compte a été créé et son rôle attribué.</p> : null}
    {params.updated ? <p className="success">Le cycle du compte a été modifié.</p> : null}
    {params.deleted ? <p className="success">Le compte a été supprimé.</p> : null}
    {params.error || errorMessage ? <p className="error">{params.error || errorMessage}</p> : null}
    <section className="card" style={{marginBottom:16}}><form method="get" className="grid grid-3" action="/administration-it/utilisateurs">
      <div className="field"><label className="label" htmlFor="schoolId">École</label><select className="select" id="schoolId" name="schoolId" required defaultValue={params.schoolId ?? ''}><option value="" disabled>Choisir une école</option>{schools.map((school: {id:string;name:string})=><option key={school.id} value={school.id}>{school.name}</option>)}</select></div>
      <div className="field"><label className="label" htmlFor="educationStage">Cycle</label><select className="select" id="educationStage" name="educationStage" defaultValue={selectedStage}>{stages.map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></div>
      <div className="field"><label className="label" htmlFor="status">État</label><select className="select" id="status" name="status" defaultValue={selectedStatus}>{statuses.map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></div>
      <button className="button button-primary" style={{gridColumn:'1/-1'}}>Afficher les comptes</button>
    </form></section>
    {params.schoolId ? <section className="table-wrap"><div style={{padding:16}}><strong>{schoolName ?? 'École sélectionnée'}</strong> · {users.length} compte(s)</div>
      <table><thead><tr><th>Nom</th><th>E-mail</th><th>Rôle(s)</th><th>Cycle</th><th>État</th><th>Dernière connexion</th><th>Actions</th></tr></thead><tbody>
        {users.map((user: any) => { const cycle = user.education_stage ?? 'parent'; return <tr key={user.id}>
          <td><strong>{user.first_name} {user.last_name}</strong><br/><small>{user.username ? `@${user.username}` : 'Sans nom d’utilisateur'}</small></td><td>{user.email ?? '—'}</td><td>{user.roles?.length ? user.roles.join(', ') : 'Aucun rôle actif'}</td>
          <td><form action={updateManagedUserStage} style={{display:'flex',gap:6}}><input type="hidden" name="schoolId" value={user.school_id}/><input type="hidden" name="userId" value={user.id}/><input type="hidden" name="currentStage" value={cycle}/><select className="select" name="newStage" defaultValue={cycle} aria-label={`Cycle de ${user.first_name} ${user.last_name}`}>{stages.filter(([value])=>value!=='all').map(([value,label])=><option key={value} value={value}>{label}</option>)}</select><button className="button button-secondary">Modifier</button></form></td>
          <td><span className="badge">{user.status}</span></td><td>{user.last_login ? new Date(user.last_login).toLocaleString('fr-FR') : 'Jamais'}</td>
          <td><div className="grid" style={{gap:8}}>{user.school_id === context.profile.school_id ? <Link className="button button-secondary" href={`/administration-it/utilisateurs/${user.id}`}>Mot de passe</Link> : null}<form action={deleteManagedUser}><input type="hidden" name="schoolId" value={user.school_id}/><input type="hidden" name="userId" value={user.id}/><input type="hidden" name="educationStage" value={cycle}/><label className="label" htmlFor={`confirm-${user.id}`}>Saisir SUPPRIMER pour confirmer</label><input className="input" id={`confirm-${user.id}`} name="confirmation" pattern="SUPPRIMER" required/><button className="button button-danger" style={{marginTop:6}}>Supprimer</button></form></div></td>
        </tr>})}
      </tbody></table>{params.schoolId && !users.length ? <p className="empty">Aucun compte trouvé pour ces filtres.</p> : null}
    </section> : <p className="empty">Choisissez une école pour afficher les comptes et leurs cycles.</p>}
    <p className="page-subtitle" style={{marginTop:12}}>La consultation et la gestion des comptes sont réservées à l’Administrateur informatique.</p>
  </main>
}
