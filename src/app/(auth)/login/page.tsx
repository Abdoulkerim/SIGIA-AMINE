import { signIn } from './actions'

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string; next?: string }> }) {
  const params = await searchParams
  return (
    <main className="auth-shell">
      <section className="card auth-card">
        <div className="brand">SIGIA-AMINE</div>
        <h1 className="page-title" style={{ marginTop: 12 }}>Connexion</h1>
        <p className="page-subtitle">Accès sécurisé au système de gestion Al Amine.</p>

        {params.error ? <p className="error" style={{ marginTop: 16 }}>{params.error}</p> : null}

        <form action={signIn} style={{ marginTop: 24 }}>
          <input type="hidden" name="next" value={params.next ?? '/'} />

          <div className="field">
            <label className="label" htmlFor="email">Adresse e-mail</label>
            <input className="input" id="email" name="email" type="email" autoComplete="email" required />
          </div>

          <div className="field">
            <label className="label" htmlFor="password">Mot de passe</label>
            <input className="input" id="password" name="password" type="password" autoComplete="current-password" required />
          </div>

          <button className="button button-primary" type="submit" style={{ width: '100%' }}>
            Se connecter
          </button>
        </form>
      </section>
    </main>
  )
}
