import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleTeacherAssignment } from '../../personnel/teacher-actions'

export default async function AssignmentsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; created?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const { data: assignments, error } = await supabase
    .from('teacher_assignments')
    .select('id, weekly_hours, is_primary, school_years(name), employees(id, first_name, last_name, employee_number), classes(name, code), subjects(name, code)')
    .eq('school_id', context.profile.school_id)
    .order('school_year_id', { ascending: false })

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Affectations des enseignants</h1>
          <p className="page-subtitle">Relier un enseignant à une classe et une matière.</p>
        </div>
        <Link className="button button-primary" href="/pedagogie/affectations/nouveau">+ Nouvelle affectation</Link>
      </div>

      {params.created ? <p className="success">Affectation enregistrée.</p> : null}
      {params.updated ? <p className="success">Affectation modifiée.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">{error.message}</p> : null}

      <section className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>Année</th><th>Enseignant</th><th>Classe</th><th>Matière</th><th>H/semaine</th><th>Principal</th><th></th></tr></thead>
            <tbody>
              {(assignments ?? []).map((a: any) => (
                <tr key={a.id}>
                  <td>{a.school_years?.name ?? '—'}</td>
                  <td>{a.employees?.last_name} {a.employees?.first_name} ({a.employees?.employee_number})</td>
                  <td>{a.classes?.name ?? '—'}</td>
                  <td>{a.subjects?.name ?? '—'}</td>
                  <td>{a.weekly_hours ?? '—'}</td>
                  <td>{a.is_primary ? 'Oui' : 'Non'}</td>
                  <td>
                    <form action={toggleTeacherAssignment}>
                      <input type="hidden" name="id" value={a.id} />
                      <input type="hidden" name="active" value="false" />
                      <button className="button button-secondary" type="submit">Retirer</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!assignments?.length ? <p className="empty">Aucune affectation.</p> : null}
      </section>
    </main>
  )
}
