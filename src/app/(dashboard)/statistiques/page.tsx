import Link from 'next/link'
import { getAvailableDashboards } from './dashboard-actions'

const cards = [
  ['direction', 'Direction / Coordination', 'Effectifs, résultats, finances, personnel, internat et activités.', '/statistiques/direction'],
  ['pedagogy', 'Pédagogie', 'Résultats, évaluations, bulletins et assiduité.', '/statistiques/pedagogie'],
  ['finance', 'Finance', 'Encaissements, dépenses, impayés et soldes.', '/statistiques/finance'],
  ['boarding', 'Internat', 'Occupation, présences et mouvements.', '/statistiques/internat'],
  ['activities', 'Activités', 'Agriculture, élevage et AGR.', '/statistiques/activites'],
] as const

export default async function StatisticsPage() {
  const available = await getAvailableDashboards()

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Statistiques & tableaux de bord</h1>
          <p className="page-subtitle">Vues de pilotage adaptées aux responsabilités et aux droits de chaque utilisateur.</p>
        </div>
        <span className="badge">Étape 24</span>
      </div>

      <section className="grid grid-2">
        {cards.filter(([code]) => available.includes(code)).map(([code, title, description, href]) => (
          <Link key={code} href={href} className="card" style={{ display: 'block' }}>
            <div className="stat-label">DASHBOARD</div>
            <h2 style={{ margin: '8px 0' }}>{title}</h2>
            <p className="page-subtitle">{description}</p>
            <div style={{ marginTop: 16 }} className="button button-secondary">Ouvrir</div>
          </Link>
        ))}
      </section>

      {!available.length && (
        <section className="card empty" style={{ marginTop: 16 }}>
          Aucun tableau de bord n&apos;est autorisé pour votre profil.
        </section>
      )}
    </main>
  )
}
