import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleTeacher } from '../teacher-actions'

export default async function TeachersPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; created?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const { data: teachers, error } = await supabase
    .from('employees')
    .select('id, employee_number, first_name, last_name, gender, phone, email, qualification, status, teacher_profiles(speciality, pedagogical_role)')
    .eq('school_id', context.profile.school_id)
    .not('teacher_profiles', 'is', null)
    .order('last_name')
    .order('first_name')

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Enseignants</h1>
          <p className="page-subtitle">Enseignants, profils pédagogiques et affectations.</p>
        </div>
        <div className="actions">
          <Link className="button button-secondary" href="/pedagogie/affectations">Affectations</Link>
          <Link className="button button-primary" href="/personnel/enseignants/nouveau">+ Nouvel enseignant</Link>
        </div>
      </div>

      {params.created ? <p className="success">Enseignant créé.</p> : null}
      {params.updated ? <p className="success">Modification enregistrée.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">{error.message}</p> : null}

      <section className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>N° employé</th><th>Nom</th><th>Spécialité</th><th>Téléphone</th><th>Qualification</th><th>Statut</th><th></th>
              </tr>
            </thead>
            <tbody>
              {(teachers ?? []).map((teacher: any) => (
                <tr key={teacher.id}>
                  <td>{teacher.employee_number}</td>
                  <td>{teacher.last_name} {teacher.first_name}</td>
                  <td>{teacher.teacher_profiles?.speciality ?? '—'}</td>
                  <td>{teacher.phone ?? '—'}</td>
                  <td>{teacher.qualification ?? '—'}</td>
                  <td><span className="badge">{teacher.status === 'active' ? 'Actif' : 'Inactif'}</span></td>
                  <td className="actions">
                    <Link className="button button-secondary" href={`/personnel/enseignants/${teacher.id}`}>Ouvrir</Link>
                    <form action={toggleTeacher}>
                      <input type="hidden" name="id" value={teacher.id} />
                      <input type="hidden" name="active" value={String(teacher.status !== 'active')} />
                      <button className="button button-secondary" type="submit">
                        {teacher.status === 'active' ? 'Désactiver' : 'Réactiver'}
                      </button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {!teachers?.length ? (
          <p className="empty">
            Aucun enseignant n'est encore configuré. Les enseignants officiels seront saisis ici par l'administration.
          </p>
        ) : null}
      </section>
    </main>
  )
}
