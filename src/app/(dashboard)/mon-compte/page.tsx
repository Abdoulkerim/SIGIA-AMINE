import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'
import { updateOwnAccount } from './actions'

export default async function MyAccountPage({ searchParams }: { searchParams: Promise<{ error?: string; updated?: string }> }) {
  const [context, params] = await Promise.all([getCurrentUserContext(), searchParams])
  if (!context) return null
  const supabase = await createClient()
  const { data: profile } = await supabase.from('users').select('first_name,last_name,username').eq('id', context.profile.id).single()
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Mon compte</h1><p className="page-subtitle">Modifiez votre nom, votre identifiant et votre mot de passe.</p></div></div>
    {params.error ? <p className="error">{params.error}</p> : null}
    {params.updated ? <p className="success">Votre compte a été mis à jour.</p> : null}
    <section className="card" style={{maxWidth:720}}><form action={updateOwnAccount} className="grid grid-2">
      <div className="field"><label className="label" htmlFor="firstName">Prénom</label><input className="input" id="firstName" name="firstName" defaultValue={profile?.first_name ?? ''} required maxLength={100}/></div>
      <div className="field"><label className="label" htmlFor="lastName">Nom</label><input className="input" id="lastName" name="lastName" defaultValue={profile?.last_name ?? ''} required maxLength={100}/></div>
      <div className="field" style={{gridColumn:'1/-1'}}><label className="label" htmlFor="username">Nom d’utilisateur</label><input className="input" id="username" name="username" defaultValue={profile?.username ?? ''} autoComplete="username" minLength={3} maxLength={40} pattern="[A-Za-z0-9._-]+" required/></div>
      <div className="field" style={{gridColumn:'1/-1'}}><label className="label" htmlFor="password">Nouveau mot de passe</label><input className="input" id="password" name="password" type="password" autoComplete="new-password" minLength={10} maxLength={128}/><small>Laissez vide pour garder votre mot de passe actuel. Au moins 10 caractères.</small></div>
      <button className="button button-primary" style={{gridColumn:'1/-1'}}>Enregistrer</button>
    </form></section>
  </main>
}
