import Link from 'next/link'
import { createParent } from '../actions'

export default async function NewParentPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const params = await searchParams
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouveau parent / tuteur</h1>
          <p className="page-subtitle">Créer le dossier d'un responsable légal ou familial.</p>
        </div>
        <Link className="button button-secondary" href="/administration/parents">Retour</Link>
      </div>

      {params.error ? <p className="error">{params.error}</p> : null}

      <form action={createParent} className="card">
        <div className="grid grid-2">
          <div className="field"><label className="label" htmlFor="lastName">Nom *</label><input className="input" id="lastName" name="lastName" required /></div>
          <div className="field"><label className="label" htmlFor="firstName">Prénom *</label><input className="input" id="firstName" name="firstName" required /></div>
          <div className="field"><label className="label" htmlFor="gender">Genre</label><select className="select" id="gender" name="gender"><option value="">Non précisé</option><option value="male">Masculin</option><option value="female">Féminin</option><option value="other">Autre</option></select></div>
          <div className="field"><label className="label" htmlFor="profession">Profession</label><input className="input" id="profession" name="profession" /></div>
          <div className="field"><label className="label" htmlFor="phone">Téléphone</label><input className="input" id="phone" name="phone" /></div>
          <div className="field"><label className="label" htmlFor="email">E-mail</label><input className="input" id="email" name="email" type="email" /></div>
          <div className="field"><label className="label" htmlFor="preferredContactMethod">Mode de contact préféré</label><select className="select" id="preferredContactMethod" name="preferredContactMethod"><option value="">Non défini</option><option value="phone">Téléphone</option><option value="whatsapp">WhatsApp</option><option value="email">E-mail</option></select></div>
          <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="address">Adresse</label><textarea className="input" id="address" name="address" rows={3} /></div>
        </div>
        <button className="button button-primary" type="submit">Enregistrer le parent</button>
      </form>
    </main>
  )
}
