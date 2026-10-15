import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function ITSystemPage() {
  const context = await getCurrentUserContext()
  const supabase = await createClient()
  const { data: user, error } = context
    ? await supabase.from('users').select('id').eq('id', context.profile.id).maybeSingle()
    : { data: null, error: new Error('Session utilisateur indisponible') }
  const configReady = Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)
  const checks = [
    { label: 'Session sécurisée', detail: context ? 'Un utilisateur authentifié est actif.' : 'Aucune session active.', ok: Boolean(context) },
    { label: 'Configuration Supabase', detail: configReady ? 'Les paramètres de connexion sont présents.' : 'Une variable de configuration est absente.', ok: configReady },
    { label: 'Accès à la base de données', detail: error ? 'La vérification de la connexion a échoué.' : user ? 'La base de données répond.' : 'Le profil utilisateur est introuvable.', ok: Boolean(user && !error) },
  ]

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">État du système</h1><p className="page-subtitle">Contrôles de disponibilité des services utilisés par la plateforme.</p></div><span className="badge">{process.env.NODE_ENV === 'production' ? 'Production' : 'Hors production'}</span></div>
      <section className="grid grid-3">
        {checks.map((check) => (
          <article className="card" key={check.label}>
            <div className="it-status-row"><span className={`it-status-dot${check.ok ? '' : ' is-warning'}`} aria-hidden="true" /><strong>{check.ok ? 'Opérationnel' : 'À vérifier'}</strong></div>
            <h2 style={{ marginBottom: 6 }}>{check.label}</h2>
            <p className="page-subtitle" style={{ lineHeight: 1.5 }}>{check.detail}</p>
          </article>
        ))}
      </section>
      <section className="card" style={{ marginTop: 16 }}>
        <h2 style={{ marginTop: 0 }}>Périmètre des contrôles</h2>
        <p>Cette page vérifie la configuration applicative, la session et une lecture authentifiée de la base. Elle ne confirme pas l’état des sauvegardes, des e-mails ou des services externes.</p>
      </section>
    </main>
  )
}
