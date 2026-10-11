import Link from 'next/link'
import { createStudent } from '../actions'
import { PhotoUpload } from '@/components/students/photo-upload'

export default async function NewStudentPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const params = await searchParams

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouveau dossier élève</h1>
          <p className="page-subtitle">Étape 1 : création du dossier administratif de base.</p>
        </div>
        <Link className="button button-secondary" href="/administration/eleves">Retour</Link>
      </div>

      {params.error ? <p className="error">{params.error}</p> : null}

      <section className="card" style={{ maxWidth: 800 }}>
        <form action={createStudent}>
          <div className="grid grid-2">
            <div className="field">
              <label className="label" htmlFor="studentNumber">Matricule *</label>
              <input className="input" id="studentNumber" name="studentNumber" required placeholder="Ex. ELV-0001" />
            </div>
            <div className="field">
              <label className="label" htmlFor="gender">Genre</label>
              <select className="select" id="gender" name="gender" defaultValue="">
                <option value="">Non précisé</option>
                <option value="male">Masculin</option>
                <option value="female">Féminin</option>
                <option value="other">Autre</option>
              </select>
            </div>
            <div className="field">
              <label className="label" htmlFor="firstName">Prénom *</label>
              <input className="input" id="firstName" name="firstName" required />
            </div>
            <div className="field">
              <label className="label" htmlFor="lastName">Nom *</label>
              <input className="input" id="lastName" name="lastName" required />
            </div>
            <div className="field">
              <label className="label" htmlFor="dateOfBirth">Date de naissance</label>
              <input className="input" id="dateOfBirth" name="dateOfBirth" type="date" />
            </div>
            <div className="field">
              <label className="label" htmlFor="residenceType">Régime</label>
              <select className="select" id="residenceType" name="residenceType" defaultValue="external">
                <option value="external">Externe</option>
                <option value="internal">Interne</option>
                <option value="other">Autre / régime spécifique</option>
              </select>
            </div>
          </div>

          <PhotoUpload />

          <div style={{ marginTop: 8, display: 'flex', gap: 10 }}>
            <button className="button button-primary" type="submit">Enregistrer l’élève</button>
            <Link className="button button-secondary" href="/administration/eleves">Annuler</Link>
          </div>
        </form>
      </section>
    </main>
  )
}
