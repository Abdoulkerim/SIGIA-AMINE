import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { prepareFromAdmission, prepareReenrollment } from '../actions'

export default async function NewEnrollmentPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; admission?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const [admissionsResult, studentsResult, yearsResult] = await Promise.all([
    supabase
      .from('admission_applications')
      .select('id, application_number, candidate_first_name, candidate_last_name, desired_level_label, school_years(id, name), parents:primary_parent_id(id, first_name, last_name)')
      .eq('school_id', context.profile.school_id)
      .eq('status', 'approved')
      .order('reviewed_at', { ascending: false })
      .limit(200),
    supabase
      .from('students')
      .select('id, student_number, first_name, last_name, status, residence_type')
      .eq('school_id', context.profile.school_id)
      .not('status', 'in', '(withdrawn,archived)')
      .order('last_name')
      .limit(500),
    supabase
      .from('school_years')
      .select('id, name, is_current')
      .eq('school_id', context.profile.school_id)
      .order('start_date', { ascending: false }),
  ])

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouvelle inscription</h1>
          <p className="page-subtitle">Une inscription peut rester en préparation avant l'affectation définitive à une classe.</p>
        </div>
        <Link className="button button-secondary" href="/administration/inscriptions">Retour</Link>
      </div>

      {params.error ? <p className="error">{params.error}</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <h2>1. À partir d'une admission approuvée</h2>
        <p>Cette option crée le dossier élève si nécessaire et génère un brouillon d'inscription. La classe sera affectée à l'étape 9.</p>
        <form action={prepareFromAdmission}>
          <div className="grid grid-2">
            <div className="field">
              <label className="label" htmlFor="admissionId">Admission *</label>
              <select className="select" id="admissionId" name="admissionId" required defaultValue={params.admission ?? ''}>
                <option value="">Choisir une admission</option>
                {(admissionsResult.data ?? []).map((a: any) => <option key={a.id} value={a.id}>{a.application_number} — {a.candidate_last_name} {a.candidate_first_name} — {a.school_years?.name ?? 'année ?'}</option>)}
              </select>
            </div>
            <div className="field">
              <label className="label" htmlFor="parentRelationship">Lien avec le parent principal</label>
              <select className="select" id="parentRelationship" name="parentRelationship">
                <option value="">Ne pas encore créer le lien</option>
                <option value="father">Père</option>
                <option value="mother">Mère</option>
                <option value="guardian">Tuteur</option>
                <option value="tutor">Tutrice / responsable</option>
                <option value="other">Autre</option>
              </select>
            </div>
          </div>
          <button className="button button-primary" type="submit">Créer le dossier d'inscription</button>
        </form>
      </section>

      <section className="card">
        <h2>2. Réinscription d'un élève existant</h2>
        <p>La réinscription conserve l'historique de l'élève et crée un nouveau dossier pour l'année choisie.</p>
        <form action={prepareReenrollment}>
          <div className="grid grid-3">
            <div className="field">
              <label className="label" htmlFor="studentId">Élève *</label>
              <select className="select" id="studentId" name="studentId" required>
                <option value="">Choisir un élève</option>
                {(studentsResult.data ?? []).map((s: any) => <option key={s.id} value={s.id}>{s.student_number} — {s.last_name} {s.first_name}</option>)}
              </select>
            </div>
            <div className="field">
              <label className="label" htmlFor="schoolYearId">Année scolaire *</label>
              <select className="select" id="schoolYearId" name="schoolYearId" required>
                <option value="">Choisir une année</option>
                {(yearsResult.data ?? []).map((y: any) => <option key={y.id} value={y.id}>{y.name}{y.is_current ? ' — actuelle' : ''}</option>)}
              </select>
            </div>
            <div className="field">
              <label className="label" htmlFor="residenceType">Régime *</label>
              <select className="select" id="residenceType" name="residenceType" defaultValue="external">
                <option value="external">Externe</option>
                <option value="internal">Interne</option>
                <option value="other">Autre</option>
              </select>
            </div>
          </div>
          <button className="button button-primary" type="submit">Créer la réinscription</button>
        </form>
      </section>
    </main>
  )
}
