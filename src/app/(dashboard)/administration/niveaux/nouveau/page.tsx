import Link from 'next/link'
import { createLevel } from '../../academic-actions'

export default function NewLevelPage() {
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouveau niveau</h1>
          <p className="page-subtitle">Créer un niveau officiel de l'établissement.</p>
        </div>
        <Link className="button button-secondary" href="/administration/niveaux">Retour</Link>
      </div>

      <section className="card">
        <form action={createLevel} className="grid grid-2">
          <div className="field">
            <label className="label" htmlFor="code">Code *</label>
            <input className="input" id="code" name="code" required placeholder="Ex. 6EME" />
          </div>
          <div className="field">
            <label className="label" htmlFor="name">Nom *</label>
            <input className="input" id="name" name="name" required placeholder="Ex. Sixième" />
          </div>
          <div className="field">
            <label className="label" htmlFor="educationCycle">Cycle</label>
            <input className="input" id="educationCycle" name="educationCycle" placeholder="Ex. Collège" />
          </div>
          <div className="field">
            <label className="label" htmlFor="sequenceNo">Ordre</label>
            <input className="input" id="sequenceNo" name="sequenceNo" type="number" min="0" />
          </div>
          <div><button className="button button-primary" type="submit">Créer le niveau</button></div>
        </form>
      </section>
    </main>
  )
}
