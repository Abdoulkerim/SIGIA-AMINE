import Link from 'next/link'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function CardsHome() {
  const context = await getCurrentUserContext()
  const isItAdminOnly = context?.roles.some(({ code }) => code === 'it_admin')
    && !context?.roles.some(({ code }) => code === 'super_admin' || code === 'founder')
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Carte scolaire</h1>
          <p className="page-subtitle">Consultez les fiches des élèves et des employés.</p>
        </div>
      </div>
      <section className="grid grid-2">
        <Link className="card it-tool-card" href="/administration-it/cartes/eleves">
          <strong>Cartes des élèves</strong><span>Matricule, nom, classe et statut.</span><span aria-hidden="true">→</span>
        </Link>
        {!isItAdminOnly ? <Link className="card it-tool-card" href="/administration-it/cartes/employes">
          <strong>Cartes des employés</strong><span>Matricule, nom, fonction et statut.</span><span aria-hidden="true">→</span>
        </Link> : null}
      </section>
    </main>
  )
}
