import Image from 'next/image'
import { signIn } from './actions'

const spaces = [
  { id: 'maternelle', label: 'Maternelle' },
  { id: 'primaire', label: 'Primaire' },
  { id: 'secondaire', label: 'Secondaire' },
  { id: 'formation', label: 'Centre de formation' },
  { id: 'parent', label: 'Parent' },
] as const

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; next?: string; space?: string }>
}) {
  const params = await searchParams
  const selectedSpace = spaces.find((space) => space.id === params.space)

  return (
    <main className="login-page">
      <div className="login-topbar">
        <span className="login-topbar-mark" aria-hidden="true">✦</span>
        Portail de gestion scolaire
      </div>

      <div className="login-scene">
        <div className="login-orbit login-orbit-left" aria-hidden="true" />
        <div className="login-orbit login-orbit-right" aria-hidden="true" />
        <div className="login-accent login-accent-green" aria-hidden="true" />
        <div className="login-accent login-accent-orange" aria-hidden="true" />

        <div className="login-photo login-photo-left">
          <Image
            fill
            src="/kung-fu-diplomes.png"
            alt="Deux élèves du Complexe scolaire Al Amine avec leur diplôme de kung-fu wushu"
            sizes="(max-width: 560px) 0px, (max-width: 1120px) 150px, 22vw"
            className="login-photo-image"
          />
        </div>
        <div className="login-photo login-photo-right">
          <Image
            fill
            src="/kung-fu-groupe-al-amine.png"
            alt="Groupe de kung-fu devant le Complexe scolaire Al Amine"
            sizes="(max-width: 560px) 0px, (max-width: 1120px) 170px, 26vw"
            className="login-photo-image"
          />
        </div>
        <section className="login-content" aria-labelledby="login-heading">
          <div className="login-brand-lockup">
            <Image
              className="login-brand-icon"
              src="/logo-complexe-scolaire-al-amine.jpg"
              alt="Logo du Complexe scolaire Al Amine"
              width={64}
              height={64}
            />
            <span className="login-brand-name">SIGIA<span>AMINE</span></span>
          </div>

          <div className="login-heading-block">
            <p className="login-eyebrow">Bienvenue dans votre espace</p>
            <h1 id="login-heading">SYSTÈME INTELLIGENT DE GESTION INTÉGRÉ AL AMINE</h1>
            <p className="login-tagline">La réussite de chaque élève, au cœur de nos priorités.</p>
            {selectedSpace ? <span className="login-space-label">Espace {selectedSpace.label}</span> : null}
          </div>

          <div className="login-form-card" id="connexion">
            <h2>Connexion</h2>
            <p className="login-form-hint">Connectez-vous pour accéder à votre espace de travail.</p>
            {params.error ? <p className="error" role="alert">{params.error}</p> : null}

            <form action={signIn} className="login-form">
              <input type="hidden" name="next" value={params.next ?? '/'} />
              <input type="hidden" name="space" value={selectedSpace?.id ?? ''} />
              <label className="login-field">
                <span>Adresse e-mail</span>
                <input className="input" id="email" name="email" type="email" autoComplete="email" placeholder="nom@exemple.com" required />
              </label>
              <label className="login-field">
                <span>Mot de passe</span>
                <input className="input" id="password" name="password" type="password" autoComplete="current-password" placeholder="Votre mot de passe" required />
              </label>
              <button className="login-submit" type="submit">Se connecter <span aria-hidden="true">→</span></button>
            </form>
            <p className="login-secure-note"><span aria-hidden="true">●</span> Connexion sécurisée</p>
          </div>
        </section>
      </div>

      <footer className="login-footer">
        <div className="login-footer-inner">
          <span className="login-footer-label">Choisir un espace</span>
          <nav className="login-space-links" aria-label="Espaces de connexion">
            {spaces.map((space) => (
              <a
                className="login-space-link"
                href={`/login?space=${space.id}#connexion`}
                aria-current={selectedSpace?.id === space.id ? 'page' : undefined}
                key={space.id}
              >
                {space.label}
              </a>
            ))}
          </nav>
          <span className="login-footer-note">SIGIA-AMINE · Plateforme de gestion scolaire</span>
        </div>
      </footer>
    </main>
  )
}
