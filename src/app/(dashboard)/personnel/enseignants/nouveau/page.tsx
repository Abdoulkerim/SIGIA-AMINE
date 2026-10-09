import Link from 'next/link'
import { createTeacher } from '../../teacher-actions'

export default function NewTeacherPage() {
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouvel enseignant</h1>
          <p className="page-subtitle">Créer le dossier personnel et le profil pédagogique.</p>
        </div>
        <Link className="button button-secondary" href="/personnel/enseignants">Retour</Link>
      </div>

      <section className="card">
        <form action={createTeacher} className="grid grid-2">
          <div className="field"><label className="label" htmlFor="employeeNumber">N° employé *</label><input className="input" id="employeeNumber" name="employeeNumber" required /></div>
          <div className="field"><label className="label" htmlFor="firstName">Prénom *</label><input className="input" id="firstName" name="firstName" required /></div>
          <div className="field"><label className="label" htmlFor="lastName">Nom *</label><input className="input" id="lastName" name="lastName" required /></div>
          <div className="field"><label className="label" htmlFor="gender">Genre</label>
            <select className="select" id="gender" name="gender"><option value="">Non renseigné</option><option value="male">Masculin</option><option value="female">Féminin</option><option value="other">Autre</option></select>
          </div>
          <div className="field"><label className="label" htmlFor="dateOfBirth">Date de naissance</label><input className="input" id="dateOfBirth" name="dateOfBirth" type="date" /></div>
          <div className="field"><label className="label" htmlFor="hireDate">Date d'embauche</label><input className="input" id="hireDate" name="hireDate" type="date" /></div>
          <div className="field"><label className="label" htmlFor="phone">Téléphone</label><input className="input" id="phone" name="phone" /></div>
          <div className="field"><label className="label" htmlFor="email">Email</label><input className="input" id="email" name="email" type="email" /></div>
          <div className="field"><label className="label" htmlFor="placeOfBirth">Lieu de naissance</label><input className="input" id="placeOfBirth" name="placeOfBirth" /></div>
          <div className="field"><label className="label" htmlFor="qualification">Qualification</label><input className="input" id="qualification" name="qualification" /></div>
          <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="address">Adresse</label><input className="input" id="address" name="address" /></div>

          <div className="field"><label className="label" htmlFor="speciality">Spécialité</label><input className="input" id="speciality" name="speciality" placeholder="Ex. Mathématiques" /></div>
          <div className="field"><label className="label" htmlFor="diploma">Diplôme</label><input className="input" id="diploma" name="diploma" /></div>
          <div className="field"><label className="label" htmlFor="pedagogicalRole">Rôle pédagogique</label><input className="input" id="pedagogicalRole" name="pedagogicalRole" placeholder="Ex. Enseignant principal" /></div>
          <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="biography">Biographie / observations</label><textarea className="input" id="biography" name="biography" rows={4} /></div>

          <div><button className="button button-primary" type="submit">Créer l'enseignant</button></div>
        </form>
      </section>
    </main>
  )
}
