import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

const labels: Record<string, string> = {
  pending: 'En préparation',
  approved: 'Validée',
  enrolled: 'Inscrite',
  completed: 'Terminée',
  cancelled: 'Annulée',
}

export default async function EnrollmentsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; created?: string; finalized?: string; cancelled?: string; status?: string; q?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const params = await searchParams
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('enrollments')
    .select(`
      id, registration_number, status, residence_type, enrollment_date, is_reenrollment,
      students(id, student_number, first_name, last_name),
      school_years(id, name),
      classes(id, name, code),
      levels:requested_level_id(id, name),
      admission_applications:source_admission_id(id, application_number)
    `)
    .eq('school_id', context.profile.school_id)
    .order('enrollment_date', { ascending: false })
    .limit(300)

  let rows = data ?? []
  if (params.status) rows = rows.filter((row: any) => row.status === params.status)
  if (params.q?.trim()) {
    const q = params.q.trim().toLowerCase()
    rows = rows.filter((row: any) => {
      const text = [row.registration_number, row.students?.student_number, row.students?.first_name, row.students?.last_name, row.school_years?.name, row.classes?.name].filter(Boolean).join(' ').toLowerCase()
      return text.includes(q)
    })
  }

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Inscriptions / Réinscriptions</h1>
          <p className="page-subtitle">Créer le dossier d'inscription, conserver l'historique et finaliser l'affectation lorsque la classe est disponible.</p>
        </div>
        <Link className="button button-primary" href="/administration/inscriptions/nouveau">+ Nouvelle inscription</Link>
      </div>

      {params.created ? <p className="success">Dossier d'inscription créé.</p> : null}
      {params.finalized ? <p className="success">Inscription finalisée.</p> : null}
      {params.cancelled ? <p className="success">Inscription annulée.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">Erreur : {error.message}</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <form method="get" className="grid grid-4">
          <div className="field"><label className="label" htmlFor="q">Recherche</label><input className="input" id="q" name="q" defaultValue={params.q ?? ''} placeholder="N°, matricule, nom..." /></div>
          <div className="field"><label className="label" htmlFor="status">Statut</label><select className="select" id="status" name="status" defaultValue={params.status ?? ''}><option value="">Tous</option>{Object.entries(labels).map(([code, label]) => <option key={code} value={code}>{label}</option>)}</select></div>
          <div className="field"><span className="label">Dossiers</span><span>{rows.length}</span></div>
          <div className="field" style={{ alignSelf: 'end' }}><button className="button button-secondary" type="submit">Filtrer</button></div>
        </form>
      </section>

      {!rows.length ? (
        <section className="card empty">
          <h2 style={{ marginTop: 0 }}>Aucune inscription</h2>
          <p>Commence avec une admission approuvée ou crée une réinscription pour un élève existant.</p>
          <Link className="button button-primary" href="/administration/inscriptions/nouveau">Créer une inscription</Link>
        </section>
      ) : (
        <section className="table-wrap">
          <table>
            <thead><tr><th>Référence</th><th>Élève</th><th>Année</th><th>Niveau</th><th>Classe</th><th>Régime</th><th>Type</th><th>Statut</th><th></th></tr></thead>
            <tbody>
              {rows.map((row: any) => (
                <tr key={row.id}>
                  <td>{row.registration_number}</td>
                  <td>{row.students ? `${row.students.last_name} ${row.students.first_name}` : '—'}</td>
                  <td>{row.school_years?.name ?? '—'}</td>
                  <td>{row.levels?.name ?? 'À définir'}</td>
                  <td>{row.classes?.name ?? 'À affecter'}</td>
                  <td>{row.residence_type}</td>
                  <td>{row.is_reenrollment ? 'Réinscription' : 'Inscription'}</td>
                  <td><span className="badge">{labels[row.status] ?? row.status}</span></td>
                  <td><Link className="button button-secondary" href={`/administration/inscriptions/${row.id}`}>Ouvrir</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </main>
  )
}
