import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createAdmission } from '../actions'

export default async function NewAdmissionPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const [yearsResult, levelsResult, parentsResult] = await Promise.all([
    supabase.from('school_years').select('id, name, is_current').eq('school_id', context.profile.school_id).order('start_date', { ascending: false }),
    supabase.from('levels').select('id, code, name').eq('school_id', context.profile.school_id).order('name'),
    supabase.from('parents').select('id, first_name, last_name, phone').eq('school_id', context.profile.school_id).order('last_name').limit(200),
  ])

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouvelle préinscription</h1>
          <p className="page-subtitle">Créer un dossier candidat. L'inscription scolaire sera traitée à l'étape 8.</p>
        </div>
        <Link className="button button-secondary" href="/administration/admissions">Retour</Link>
      </div>

      {params.error ? <p className="error">{params.error}</p> : null}

      <form action={createAdmission} className="card">
        <h2>1. Identité du candidat</h2>
        <div className="grid grid-2">
          <div className="field"><label className="label" htmlFor="lastName">Nom *</label><input className="input" id="lastName" name="candidateLastName" required /></div>
          <div className="field"><label className="label" htmlFor="firstName">Prénom *</label><input className="input" id="firstName" name="candidateFirstName" required /></div>
          <div className="field"><label className="label" htmlFor="gender">Genre</label><select className="select" id="gender" name="candidateGender"><option value="">Non précisé</option><option value="male">Masculin</option><option value="female">Féminin</option><option value="other">Autre</option></select></div>
          <div className="field"><label className="label" htmlFor="dob">Date de naissance</label><input className="input" id="dob" name="candidateDateOfBirth" type="date" /></div>
          <div className="field"><label className="label" htmlFor="birthPlace">Lieu de naissance</label><input className="input" id="birthPlace" name="candidatePlaceOfBirth" /></div>
          <div className="field"><label className="label" htmlFor="nationality">Nationalité</label><input className="input" id="nationality" name="candidateNationality" /></div>
          <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="address">Adresse</label><textarea className="input" id="address" name="candidateAddress" rows={2} /></div>
        </div>

        <h2>2. Scolarité demandée</h2>
        <div className="grid grid-2">
          <div className="field">
            <label className="label" htmlFor="year">Année scolaire *</label>
            <select className="select" id="year" name="desiredYearId" required>
              <option value="">Choisir une année</option>
              {(yearsResult.data ?? []).map((year: any) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
            </select>
          </div>
          <div className="field">
            <label className="label" htmlFor="level">Niveau configuré</label>
            <select className="select" id="level" name="desiredLevelId" defaultValue="">
              <option value="">Pas encore configuré / utiliser le libellé ci-dessous</option>
              {(levelsResult.data ?? []).map((level: any) => <option key={level.id} value={level.id}>{level.name}{level.code ? ` (${level.code})` : ''}</option>)}
            </select>
          </div>
          <div className="field"><label className="label" htmlFor="levelLabel">Libellé du niveau demandé</label><input className="input" id="levelLabel" name="desiredLevelLabel" placeholder="Ex. 6e, CM2, Seconde..." /></div>
          <div className="field"><label className="label" htmlFor="residence">Régime souhaité</label><select className="select" id="residence" name="desiredResidenceType"><option value="external">Externe</option><option value="internal">Interne</option><option value="other">Autre</option></select></div>
        </div>

        <h2>3. Responsable connu</h2>
        <div className="grid grid-2">
          <div className="field"><label className="label" htmlFor="phone">Téléphone du demandeur / contact</label><input className="input" id="phone" name="applicantPhone" /></div>
          <div className="field">
            <label className="label" htmlFor="parent">Parent / tuteur déjà enregistré</label>
            <select className="select" id="parent" name="primaryParentId" defaultValue="">
              <option value="">Aucun / à renseigner plus tard</option>
              {(parentsResult.data ?? []).map((parent: any) => <option key={parent.id} value={parent.id}>{parent.last_name} {parent.first_name}{parent.phone ? ` — ${parent.phone}` : ''}</option>)}
            </select>
          </div>
        </div>

        <h2>4. Observations</h2>
        <div className="field"><label className="label" htmlFor="notes">Notes du dossier</label><textarea className="input" id="notes" name="notes" rows={5} /></div>

        <button className="button button-primary" type="submit">Enregistrer la préinscription</button>
      </form>
    </main>
  )
}
