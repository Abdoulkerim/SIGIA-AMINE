import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'
import { setTemporaryPassword } from './actions'

export default async function ManageUserAccountPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; updated?: string }> }) {
  const [context, { id }, query] = await Promise.all([getCurrentUserContext(), params, searchParams])
  if (!context?.roles.some(({ code }) => code === 'it_admin')) redirect('/dashboard')
  const supabase = await createClient()
  const { data: user } = await supabase.from('users').select('id,first_name,last_name,username,email').eq('id', id).maybeSingle()
  if (!user) notFound()
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Compte de {user.first_name} {user.last_name}</h1><p className="page-subtitle">{user.username ? `@${user.username}` : user.email}</p></div><Link className="button button-secondary" href="/administration-it/utilisateurs">Retour aux utilisateurs</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}
    {query.updated ? <p className="success">Le mot de passe temporaire a été défini. Communiquez-le à l’utilisateur par un canal sûr.</p> : null}
    <section className="card" style={{maxWidth:640}}><h2 style={{marginTop:0}}>Définir un mot de passe temporaire</h2><p>L’ancien mot de passe ne peut pas être consulté. L’utilisateur pourra se connecter avec ce mot de passe et le remplacer depuis « Mon compte ».</p><form action={setTemporaryPassword} className="grid"><input type="hidden" name="userId" value={user.id}/><div className="field"><label className="label" htmlFor="password">Nouveau mot de passe temporaire</label><input className="input" id="password" name="password" type="password" autoComplete="new-password" minLength={10} maxLength={128} required/><small>Au moins 10 caractères. Il sera visible seulement pendant sa saisie.</small></div><button className="button button-primary">Définir le mot de passe</button></form></section>
  </main>
}
