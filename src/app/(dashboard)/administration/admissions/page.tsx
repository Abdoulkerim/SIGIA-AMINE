import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

const labels: Record<string, string> = {
  pending: 'En attente',
  approved: 'Admise',
  rejected: 'Rejetée',
  enrolled: 'Inscrite',
  cancelled: 'Annulée',
  completed: 'Terminée',
}

export default async function AdmissionsPage({
  searchParams,
}: {
  searchParams: Promise<{ created?: string; number?: string; error?: string; status?: string; q?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const params = await searchParams
  const supabase = await createClient()

  const [applicationsResult, yearsResult] = await Promise.all([
    supabase
      .from('admission_applications')
      .select('id, application_number, candidate_first_name, candidate_last_name, applicant_name, applicant_phone, desired_level_label, desired_residence_type, status, submitted_at, created_at, school_years(id, name), levels(id, name)')
      .eq('school_id', context.profile.school_id)
      .order('created_at', { ascending: false })
      .limit(200),
    supabase
      .from('school_years')
      .select('id, name, is_current')
      .eq('school_id', context.profile.school_id)
      .order('start_date', { ascending: false }),
  ])

  let applications = applicationsResult.data ?? []
  if (params.status) applications = applications.filter((a) => a.status === params.status)
  if (params.q?.trim()) {
    const q = params.q.trim().toLowerCase()
    applications = applications.filter((a) => `${a.application_number} ${a.candidate_first_name ?? ''} ${a.candidate_last_name ?? ''} ${a.applicant_name ?? ''}`.toLowerCase().includes(q))
  }

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Admissions / Préinscriptions</h1>
          <p className="page-subtitle">Du dossier candidat à la décision d'admission, avant l'inscription scolaire.</p>
        </div>
        <Link className="button button-primary" href="/administration/admissions/nouveau">+ Nouvelle préinscription</Link>
      </div>

      {params.created ? <p className="success">Préinscription enregistrée : {params.number ?? 'référence générée'}.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {applicationsResult.error ? <p className="error">Erreur de lecture : {applicationsResult.error.message}</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <form method="get" className="grid grid-4">
          <div className="field">
            <label className="label" htmlFor="q">Recherche</label>
            <input className="input" id="q" name="q" defaultValue={params.q ?? ''} placeholder="Numéro, nom, prénom..." />
          </div>
          <div className="field">
            <label className="label" htmlFor="status">Statut</label>
            <select className="select" id="status" name="status" defaultValue={params.status ?? ''}>
              <option value="">Tous</option>
              {Object.entries(labels).map(([code, label]) => <option key={code} value={code}>{label}</option>)}
            </select>
          </div>
          <div className="field" style={{ justifyContent: 'end' }}>
            <span className="label">Années configurées</span>
            <span>{yearsResult.data?.length ?? 0}</span>
          </div>
          <div className="field" style={{ justifyContent: 'end' }}>
            <span className="label">Dossiers affichés</span>
            <span>{applications.length}</span>
          </div>
          <div><button className="button button-secondary" type="submit">Filtrer</button></div>
        </form>
      </section>

      {!applications.length ? (
        <section className="card empty">
          <h2 style={{ marginTop: 0, color: 'var(--text)' }}>Aucune préinscription</h2>
          <p>Crée le premier dossier candidat pour démarrer le workflow d'admission.</p>
          <Link className="button button-primary" href="/administration/admissions/nouveau">Créer une préinscription</Link>
        </section>
      ) : (
        <section className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Référence</th>
                <th>Candidat</th>
                <th>Téléphone</th>
                <th>Niveau demandé</th>
                <th>Année</th>
                <th>Régime</th>
                <th>Statut</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {applications.map((a: any) => (
                <tr key={a.id}>
                  <td>{a.application_number}</td>
                  <td>{a.candidate_last_name ? `${a.candidate_last_name} ${a.candidate_first_name}` : a.applicant_name}</td>
                  <td>{a.applicant_phone ?? '—'}</td>
                  <td>{a.desired_level_label ?? a.levels?.name ?? '—'}</td>
                  <td>{a.school_years?.name ?? '—'}</td>
                  <td>{a.desired_residence_type ?? '—'}</td>
                  <td><span className="badge">{labels[a.status] ?? a.status}</span></td>
                  <td><Link className="button button-secondary" href={`/administration/admissions/${a.id}`}>Ouvrir</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </main>
  )
}
