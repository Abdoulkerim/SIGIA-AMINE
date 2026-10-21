import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { createManagedUser } from './actions'

const stages = [['maternelle','Maternelle'],['primaire','Primaire'],['secondaire','Secondaire'],['formation','Centre de formation'],['autre','Autre'],['parent','Parent — enfants rattachés uniquement']]

export default async function NewITUserPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const [{ data: roles }, params] = await Promise.all([createClient().then((client) => client.from('roles').select('id,name,code').order('name')), searchParams])
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Créer un compte utilisateur</h1><p className="page-subtitle">Définissez l’identité, le cycle de données et le rôle donnant accès aux modules.</p></div><Link className="button button-secondary" href="/administration-it/utilisateurs">Retour aux utilisateurs</Link></div>
    {params.error ? <p className="error">{params.error}</p> : null}
    <section className="card" style={{maxWidth:760}}><form action={createManagedUser} className="grid grid-2">
      <div className="field"><label className="label" htmlFor="firstName">Prénom</label><input className="input" id="firstName" name="firstName" autoComplete="given-name" required maxLength={100}/></div>
      <div className="field"><label className="label" htmlFor="lastName">Nom</label><input className="input" id="lastName" name="lastName" autoComplete="family-name" required maxLength={100}/></div>
      <div className="field"><label className="label" htmlFor="username">Nom d’utilisateur</label><input className="input" id="username" name="username" autoComplete="username" minLength={3} maxLength={40} pattern="[A-Za-z0-9._-]+" required/><small>3 à 40 lettres, chiffres, points, tirets ou tirets bas.</small></div>
      <div className="field"><label className="label" htmlFor="email">E-mail de connexion</label><input className="input" id="email" name="email" type="email" autoComplete="email" required maxLength={254}/></div>
      <div className="field"><label className="label" htmlFor="password">Mot de passe initial</label><input className="input" id="password" name="password" type="password" autoComplete="new-password" minLength={10} required/><small>Au moins 10 caractères. Transmettez-le au nouvel utilisateur par un canal sûr.</small></div>
      <div className="field"><label className="label" htmlFor="educationStage">Cycle / périmètre des données</label><select className="select" id="educationStage" name="educationStage" required defaultValue=""><option value="" disabled>Choisir un cycle</option>{stages.map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></div>
      <div className="field"><label className="label" htmlFor="roleId">Rôle et permissions</label><select className="select" id="roleId" name="roleId" required defaultValue=""><option value="" disabled>Choisir un rôle</option>{(roles??[]).map((role)=><option key={role.id} value={role.id}>{role.name} ({role.code})</option>)}</select><small>Le rôle détermine les permissions et les pages accessibles.</small></div>
      <button className="button button-primary" style={{gridColumn:'1/-1'}}>Créer le compte et attribuer le rôle</button>
    </form></section>
  </main>
}
