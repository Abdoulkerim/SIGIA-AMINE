import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { firstRelation } from '@/lib/supabase/relations'
import { cancelEnrollment, finalizeEnrollment } from '../actions'

const labels: Record<string, string> = {
  pending: 'En préparation',
  approved: 'Validée',
  enrolled: 'Inscrite',
  completed: 'Terminée',
  cancelled: 'Annulée',
}

export default async function EnrollmentDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string; created?: string; finalized?: string; cancelled?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const { id } = await params
  const query = await searchParams
  const supabase = await createClient()

  const { data: enrollment, error } = await supabase
    .from('enrollments')
    .select(`
      id, registration_number, status, residence_type, enrollment_date, is_reenrollment,
      registration_fee, notes, requested_level_id, source_admission_id,
      students(id, student_number, first_name, last_name, gender, date_of_birth, status),
      school_years(id, name),
      classes(id, name, code),
      levels:requested_level_id(id, code, name),
      admission_applications:source_admission_id(id, application_number, status)
    `)
    .eq('id', id)
    .eq('school_id', context.profile.school_id)
    .single()

  if (error || !enrollment) notFound()

  const student = firstRelation(enrollment.students)
  const schoolYear = firstRelation(enrollment.school_years)
  const enrolledClass = firstRelation(enrollment.classes)
  const level = firstRelation(enrollment.levels)
  const admission = firstRelation(enrollment.admission_applications)

  const { data: classes } = await supabase
    .from('classes')
    .select('id, name, code, level_id, capacity')
    .eq('school_id', context.profile.school_id)
    .eq('school_year_id', schoolYear?.id ?? '')
    .eq('is_active', true)
    .order('name')

  const canFinalize = ['pending', 'approved'].includes(enrollment.status) && (classes?.length ?? 0) > 0

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Inscription {enrollment.registration_number}</h1>
          <p className="page-subtitle">Dossier d'inscription et réinscription.</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <span className="badge">{labels[enrollment.status] ?? enrollment.status}</span>
          <Link className="button button-secondary" href="/administration/inscriptions">Retour</Link>
        </div>
      </div>

      {query.created ? <p className="success">Dossier créé avec succès.</p> : null}
      {query.finalized ? <p className="success">Inscription finalisée et élève activé.</p> : null}
      {query.cancelled ? <p className="success">Inscription annulée.</p> : null}
      {query.error ? <p className="error">{query.error}</p> : null}

      <section className="grid grid-2">
        <div className="card">
          <h2>Élève</h2>
          <p><strong>Matricule :</strong> {student?.student_number ?? '—'}</p>
          <p><strong>Nom :</strong> {student ? `${student.last_name} ${student.first_name}` : '—'}</p>
          <p><strong>Statut élève :</strong> {student?.status ?? '—'}</p>
          <p><strong>Régime :</strong> {enrollment.residence_type}</p>
        </div>
        <div className="card">
          <h2>Scolarité</h2>
          <p><strong>Année :</strong> {schoolYear?.name ?? '—'}</p>
          <p><strong>Niveau demandé :</strong> {level?.name ?? 'À définir'}</p>
          <p><strong>Classe :</strong> {enrolledClass?.name ?? "À affecter à l'étape 9"}</p>
          <p><strong>Type :</strong> {enrollment.is_reenrollment ? 'Réinscription' : 'Inscription'}</p>
          <p><strong>Admission source :</strong> {admission?.application_number ?? '—'}</p>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Finalisation</h2>
        {!classes?.length ? (
          <div className="notice">
            <strong>Aucune classe n'est encore configurée pour cette année.</strong>
            <p style={{ marginBottom: 0 }}>C'est normal à l'étape 8. L'affectation définitive sera faite lorsque le module Niveaux / Classes de l'étape 9 sera opérationnel.</p>
          </div>
        ) : canFinalize ? (
          <form action={finalizeEnrollment}>
            <input type="hidden" name="enrollmentId" value={enrollment.id} />
            <div className="field" style={{ maxWidth: 560 }}>
              <label className="label" htmlFor="classId">Classe *</label>
              <select className="select" id="classId" name="classId" required defaultValue="">
                <option value="">Choisir une classe</option>
                {(classes ?? []).map((c: any) => <option key={c.id} value={c.id}>{c.name}{c.code ? ` (${c.code})` : ''}</option>)}
              </select>
            </div>
            <button className="button button-primary" type="submit">Finaliser l'inscription</button>
          </form>
        ) : null}

        {['pending', 'approved'].includes(enrollment.status) ? (
          <form action={cancelEnrollment} style={{ marginTop: 12 }}>
            <input type="hidden" name="enrollmentId" value={enrollment.id} />
            <button className="button button-danger" type="submit">Annuler l'inscription</button>
          </form>
        ) : null}
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Notes</h2>
        <p style={{ whiteSpace: 'pre-wrap' }}>{enrollment.notes ?? 'Aucune note.'}</p>
      </section>
    </main>
  )
}
