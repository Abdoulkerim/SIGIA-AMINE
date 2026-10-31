import Link from 'next/link'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createManagedUser } from './actions'
import { InitialPasswordField } from './password-field'

const stages = [['maternelle','Maternelle'],['primaire','Primaire'],['secondaire','Secondaire'],['formation','Centre de formation'],['autre','Autre'],['parent','Parent — enfants rattachés uniquement']]

export default async function NewITUserPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.roles.some(({ code }) => code === 'it_admin')) redirect('/dashboard')
  const supabase = await createClient()
  const [{ data: roles }, { data: directory, error: directoryError }, params] = await Promise.all([
    supabase.from('roles').select('id,name,code').order('name'),
    supabase.functions.invoke('managed-user-directory', { body: { action: 'list' } }),
    searchParams,
  ])
  const schools = (directory?.schools ?? []).filter((school: { is_active: boolean }) => school.is_active)
  const assignableRoles = (roles ?? []).filter((role) => !['super_admin','founder','it_admin'].includes(role.code))
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Créer un compte utilisateur</h1><p className="page-subtitle">Définissez l’identité, l’école, le cycle de données et le rôle.</p></div><Link className="button button-secondary" href="/administration-it/utilisateurs">Retour aux utilisateurs</Link></div>
    {params.error ? <p className="error">{params.error}</p> : null}
    {directoryError ? <p className="error">Impossible de charger les écoles. Vérifiez le déploiement de la fonction managed-user-directory.</p> : null}
    <section className="card" style={{maxWidth:760}}><form action={createManagedUser} className="grid grid-2">
      <div className="field"><label className="label" htmlFor="firstName">Prénom</label><input className="input" id="firstName" name="firstName" autoComplete="given-name" required maxLength={100}/></div>
      <div className="field"><label className="label" htmlFor="lastName">Nom</label><input className="input" id="lastName" name="lastName" autoComplete="family-name" required maxLength={100}/></div>
      <div className="field"><label className="label" htmlFor="username">Nom d’utilisateur</label><input className="input" id="username" name="username" autoComplete="username" minLength={3} maxLength={40} pattern="[A-Za-z0-9._-]+" required/><small>3 à 40 lettres, chiffres, points, tirets ou tirets bas.</small></div>
      <div className="field"><label className="label" htmlFor="email">E-mail de connexion</label><input className="input" id="email" name="email" type="email" autoComplete="email" required maxLength={254}/></div>
      <div className="field"><label className="label" htmlFor="password">Mot de passe initial</label><InitialPasswordField/><small>Au moins 10 caractères. Transmettez-le au nouvel utilisateur par un canal sûr.</small></div>
      <div className="field"><label className="label" htmlFor="schoolId">École</label><select className="select" id="schoolId" name="schoolId" required defaultValue={schools.length === 1 ? schools[0].id : ''}><option value="" disabled>Choisir une école</option>{schools.map((school: {id:string;name:string})=><option key={school.id} value={school.id}>{school.name}</option>)}</select></div>
      <div className="field"><label className="label" htmlFor="educationStage">Cycle / périmètre des données</label><select className="select" id="educationStage" name="educationStage" required defaultValue=""><option value="" disabled>Choisir un cycle</option>{stages.map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></div>
      <div className="field"><label className="label" htmlFor="roleId">Rôle et permissions</label><select className="select" id="roleId" name="roleId" required defaultValue=""><option value="" disabled>Choisir un rôle</option>{assignableRoles.map((role)=><option key={role.id} value={role.id}>{role.name} ({role.code})</option>)}</select><small>Les rôles d’administration sont réservés.</small></div>
      <button className="button button-primary" style={{gridColumn:'1/-1'}} disabled={!schools.length || !assignableRoles.length}>Créer le compte et attribuer le rôle</button>
    </form></section>
  </main>
}
