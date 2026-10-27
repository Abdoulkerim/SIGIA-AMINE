import Link from 'next/link'
import { createStudent } from '../actions'
import { PhotoUpload } from '@/components/students/photo-upload'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

const stages = [
  ['maternelle', 'Maternelle'],
  ['primaire', 'Primaire'],
  ['secondaire', 'Secondaire'],
  ['formation', 'Centre de formation'],
  ['autre', 'Autre'],
]

export default async function NewStudentPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const [params, context] = await Promise.all([searchParams, getCurrentUserContext()])
  if (!context?.profile.school_id) return null

  const supabase = await createClient()
  const [{ data: schoolYears }, { data: classes, error: classesError }] = await Promise.all([
    supabase.from('school_years').select('id,name,is_current').eq('school_id', context.profile.school_id).order('start_date', { ascending: false }),
    supabase.from('classes').select('id,name,code,school_year_id,education_stage').eq('school_id', context.profile.school_id).order('name'),
  ])
  const canChooseAnyStage = context?.roles.some(({ code }) => ['founder', 'super_admin'].includes(code ?? '')) ?? false
  const availableStages = canChooseAnyStage
    ? stages
    : stages.filter(([stage]) => stage === context?.profile.education_stage)
  const classesByYear = new Map<string, NonNullable<typeof classes>>()
  for (const item of classes ?? []) {
    const yearClasses = classesByYear.get(item.school_year_id) ?? []
    yearClasses.push(item)
    classesByYear.set(item.school_year_id, yearClasses)
  }

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
              <label className="label" htmlFor="educationStage">Cycle scolaire *</label>
              <select className="select" id="educationStage" name="educationStage" required defaultValue={context?.profile.education_stage ?? ''}>
                <option value="" disabled>Choisir un cycle</option>
                {availableStages.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
              </select>
              <small>Ce cycle détermine le périmètre de données du dossier.</small>
              {!canChooseAnyStage && !context?.profile.education_stage
                ? <small className="error">Un administrateur doit attribuer un cycle à votre compte.</small>
                : null}
            </div>
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
            <div className="field" style={{ gridColumn: '1 / -1' }}>
              <label className="label" htmlFor="classId">Classe pour l’année scolaire (facultatif)</label>
              <select className="select" id="classId" name="classId" defaultValue="">
                <option value="">Créer le dossier sans l’inscrire dans une classe</option>
                {(schoolYears ?? []).map((year) => {
                  const yearClasses = classesByYear.get(year.id) ?? []
                  return yearClasses.length ? (
                    <optgroup key={year.id} label={`${year.name}${year.is_current ? ' — année actuelle' : ''}`}>
                      {yearClasses.map((item) => (
                        <option key={item.id} value={item.id}>
                          {item.name}{item.code ? ` (${item.code})` : ''}{item.education_stage ? ` — ${item.education_stage}` : ''}
                        </option>
                      ))}
                    </optgroup>
                  ) : null
                })}
              </select>
              {classesError ? <small className="error">Impossible de charger les classes : {classesError.message}</small> : null}
              {!classesError && !classes?.length
                ? <small>Aucune classe n’est configurée. <Link href="/administration/classes/nouveau">Créer une classe</Link>.</small>
                : null}
              {!classesError && classes?.length
                ? <small>Une classe choisie inscrit aussi l’élève pour cette année scolaire.</small>
                : null}
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
