import Link from 'next/link'
import { createSubject } from '../../subjects-actions'

const domains = [
  ['general', 'Général'],
  ['arabe', 'Arabe'],
  ['islamique', 'Islamique'],
  ['tahfiz', 'Tahfiz'],
  ['eps', 'EPS'],
  ['wushu', 'Wushu'],
  ['autre', 'Autre'],
]

export default function NewSubjectPage() {
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouvelle matière</h1>
          <p className="page-subtitle">Créer une matière du catalogue de l'établissement.</p>
        </div>
        <Link className="button button-secondary" href="/pedagogie/matieres">Retour</Link>
      </div>

      <section className="card">
        <form action={createSubject} className="grid grid-2">
          <div className="field">
            <label className="label" htmlFor="code">Code *</label>
            <input className="input" id="code" name="code" required placeholder="Ex. MATH" />
          </div>
          <div className="field">
            <label className="label" htmlFor="name">Nom *</label>
            <input className="input" id="name" name="name" required placeholder="Ex. Mathématiques" />
          </div>
          <div className="field">
            <label className="label" htmlFor="domain">Domaine *</label>
            <select className="select" id="domain" name="domain" defaultValue="general" required>
              {domains.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </div>
          <div className="field">
            <label className="label" htmlFor="coefficient">Coefficient *</label>
            <input className="input" id="coefficient" name="coefficient" type="number" min="0.01" step="0.01" defaultValue="1" required />
          </div>
          <div className="field">
            <label className="label" htmlFor="weeklyHours">Volume horaire hebdomadaire</label>
            <input className="input" id="weeklyHours" name="weeklyHours" type="number" min="0.01" step="0.25" placeholder="Ex. 3" />
          </div>
          <div className="field" style={{ gridColumn: '1 / -1' }}>
            <label className="label" htmlFor="description">Description</label>
            <textarea className="input" id="description" name="description" rows={4} />
          </div>
          <div><button className="button button-primary" type="submit">Créer la matière</button></div>
        </form>
      </section>
    </main>
  )
}
