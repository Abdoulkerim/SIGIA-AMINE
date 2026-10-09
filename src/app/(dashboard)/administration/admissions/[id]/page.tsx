import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { reviewAdmission } from '../actions'

const labels: Record<string, string> = {
  pending: 'En attente',
  approved: 'Admise',
  rejected: 'Rejetée',
  enrolled: 'Inscrite',
  cancelled: 'Annulée',
  completed: 'Terminée',
}

export default async function AdmissionDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ updated?: string; error?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const { id } = await params
  const query = await searchParams
  const supabase = await createClient()

  const { data: admission, error } = await supabase
    .from('admission_applications')
    .select(`
      id, application_number, candidate_first_name, candidate_last_name, candidate_gender,
      candidate_date_of_birth, candidate_place_of_birth, candidate_nationality, candidate_address,
      applicant_name, applicant_phone, desired_level_label, desired_residence_type,
      status, submitted_at, reviewed_at, reviewed_by, notes, created_at,
      school_years!admission_applications_desired_year_id_fkey(id, name),
      levels!admission_applications_desired_level_id_fkey(id, name),
      parents!admission_applications_primary_parent_id_fkey(id, first_name, last_name, phone)
    `)
    .eq('id', id)
    .eq('school_id', context.profile.school_id)
    .single()
    .overrideTypes<{
      school_years: { id: string; name: string } | null
      levels: { id: string; name: string } | null
      parents: { id: string; first_name: string; last_name: string; phone: string | null } | null
    }>()

  if (error || !admission) notFound()

  const canReview = ['pending', 'approved', 'rejected', 'cancelled'].includes(admission.status)

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Préinscription {admission.application_number}</h1>
          <p className="page-subtitle">Dossier candidat avant inscription scolaire.</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <span className="badge">{labels[admission.status] ?? admission.status}</span>
          <Link className="button button-secondary" href="/administration/admissions">Retour</Link>
        </div>
      </div>

      {query.updated ? <p className="success">Le statut du dossier a été mis à jour.</p> : null}
      {query.error ? <p className="error">{query.error}</p> : null}

      <section className="grid grid-2">
        <div className="card">
          <h2>Candidat</h2>
          <p><strong>Nom :</strong> {admission.candidate_last_name ?? '—'}</p>
          <p><strong>Prénom :</strong> {admission.candidate_first_name ?? '—'}</p>
          <p><strong>Genre :</strong> {admission.candidate_gender ?? '—'}</p>
          <p><strong>Date de naissance :</strong> {admission.candidate_date_of_birth ?? '—'}</p>
          <p><strong>Lieu de naissance :</strong> {admission.candidate_place_of_birth ?? '—'}</p>
          <p><strong>Nationalité :</strong> {admission.candidate_nationality ?? '—'}</p>
          <p><strong>Adresse :</strong> {admission.candidate_address ?? '—'}</p>
        </div>

        <div className="card">
          <h2>Demande scolaire</h2>
          <p><strong>Année :</strong> {admission.school_years?.name ?? '—'}</p>
          <p><strong>Niveau référencé :</strong> {admission.levels?.name ?? '—'}</p>
          <p><strong>Niveau demandé :</strong> {admission.desired_level_label ?? '—'}</p>
          <p><strong>Régime :</strong> {admission.desired_residence_type ?? '—'}</p>
          <p><strong>Téléphone :</strong> {admission.applicant_phone ?? '—'}</p>
          <p><strong>Parent / tuteur :</strong> {admission.parents ? `${admission.parents.last_name} ${admission.parents.first_name}` : '—'}</p>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Observations</h2>
        <p style={{ whiteSpace: 'pre-wrap' }}>{admission.notes ?? 'Aucune observation.'}</p>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Workflow d'admission</h2>
        <p><strong>Soumis :</strong> {admission.submitted_at ? new Date(admission.submitted_at).toLocaleString('fr-FR') : '—'}</p>
        <p><strong>Examiné :</strong> {admission.reviewed_at ? new Date(admission.reviewed_at).toLocaleString('fr-FR') : '—'}</p>
        {canReview && admission.status !== 'enrolled' ? (
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {admission.status === 'pending' ? (
              <>
                <form action={reviewAdmission}><input type="hidden" name="id" value={admission.id} /><input type="hidden" name="action" value="approve" /><button className="button button-primary" type="submit">Approuver</button></form>
                <form action={reviewAdmission}><input type="hidden" name="id" value={admission.id} /><input type="hidden" name="action" value="reject" /><button className="button button-danger" type="submit">Rejeter</button></form>
                <form action={reviewAdmission}><input type="hidden" name="id" value={admission.id} /><input type="hidden" name="action" value="cancel" /><button className="button button-secondary" type="submit">Annuler</button></form>
              </>
            ) : null}
            {admission.status === 'rejected' || admission.status === 'cancelled' ? (
              <form action={reviewAdmission}><input type="hidden" name="id" value={admission.id} /><input type="hidden" name="action" value="reopen" /><button className="button button-secondary" type="submit">Réouvrir</button></form>
            ) : null}
            {admission.status === 'approved' ? (
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                <p className="success" style={{ margin: 0 }}>Admission approuvée. Tu peux préparer l'inscription.</p>
                <Link className="button button-primary" href={`/administration/inscriptions/nouveau?admission=${admission.id}`}>Préparer l'inscription</Link>
              </div>
            ) : null}
          </div>
        ) : null}
      </section>
    </main>
  )
}
