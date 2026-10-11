import Link from 'next/link'
import { createSchoolYear } from '../../../academic-actions'

type ReturnTo = '/administration/classes' | '/administration/classes/nouveau'

export default async function NewSchoolYearPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; returnTo?: string }>
}) {
  const params = await searchParams
  const returnTo: ReturnTo = params.returnTo === '/administration/classes/nouveau'
    ? '/administration/classes/nouveau'
    : '/administration/classes'

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouvelle année scolaire</h1>
          <p className="page-subtitle">Créez une année scolaire pour votre établissement. Elle sera disponible pour les classes dès son enregistrement.</p>
        </div>
        <Link className="button button-secondary" href={returnTo}>Retour</Link>
      </div>

      {params.error ? <p className="error" role="alert">{params.error}</p> : null}

      <section className="card" style={{ maxWidth: 800 }}>
        <form action={createSchoolYear} className="grid grid-2">
          <input type="hidden" name="returnTo" value={returnTo} />
          <div className="field" style={{ gridColumn: '1 / -1' }}>
            <label className="label" htmlFor="schoolYearName">Nom de l’année scolaire *</label>
            <input className="input" id="schoolYearName" name="name" required maxLength={100} placeholder="Ex. 2026–2027" />
          </div>
          <div className="field">
            <label className="label" htmlFor="startDate">Date de début *</label>
            <input className="input" id="startDate" name="startDate" type="date" required />
          </div>
          <div className="field">
            <label className="label" htmlFor="endDate">Date de fin *</label>
            <input className="input" id="endDate" name="endDate" type="date" required />
          </div>
          <label className="field" style={{ gridColumn: '1 / -1', display: 'flex', alignItems: 'center', gap: 10 }}>
            <input name="isCurrent" type="checkbox" />
            Définir comme année scolaire actuelle
          </label>
          <div className="actions" style={{ gridColumn: '1 / -1' }}>
            <button className="button button-primary" type="submit">Créer l’année scolaire</button>
            <Link className="button button-secondary" href={returnTo}>Annuler</Link>
          </div>
        </form>
      </section>
    </main>
  )
}
