import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function StudentsPage({ searchParams }: { searchParams: Promise<{ created?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const params = await searchParams
  const supabase = await createClient()
  const { data: students, error } = await supabase
    .from('students')
    .select('id, student_number, first_name, last_name, gender, date_of_birth, residence_type, status')
    .eq('school_id', context.profile.school_id)
    .order('last_name', { ascending: true })
    .order('first_name', { ascending: true })
    .limit(100)

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Élèves</h1>
          <p className="page-subtitle">Dossier administratif numérique des élèves du Complexe Scolaire Al Amine.</p>
        </div>
        <Link className="button button-primary" href="/administration/eleves/nouveau">+ Nouvel élève</Link>
      </div>

      {params.created ? <p className="success">Élève enregistré avec succès.</p> : null}
      {error ? <p className="error">Erreur de lecture : {error.message}</p> : null}

      {!students?.length ? (
        <section className="card empty">
          <h2 style={{ marginTop: 0, color: 'var(--text)' }}>Aucun élève enregistré</h2>
          <p>Le seed officiel ne contient volontairement aucune donnée personnelle. Commence par créer le premier dossier.</p>
          <Link className="button button-primary" href="/administration/eleves/nouveau">Créer le premier dossier</Link>
        </section>
      ) : (
        <section className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Matricule</th>
                <th>Nom</th>
                <th>Prénom</th>
                <th>Genre</th>
                <th>Naissance</th>
                <th>Régime</th>
                <th>Statut</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {students.map((student) => (
                <tr key={student.id}>
                  <td>{student.student_number}</td>
                  <td>{student.last_name}</td>
                  <td>{student.first_name}</td>
                  <td>{student.gender ?? '—'}</td>
                  <td>{student.date_of_birth ?? '—'}</td>
                  <td>{student.residence_type}</td>
                  <td><span className="badge">{student.status}</span></td>
                  <td><Link className="button button-secondary" href={`/administration/eleves/${student.id}`}>Ouvrir</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </main>
  )
}
