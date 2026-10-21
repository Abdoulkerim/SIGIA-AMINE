import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleSubject } from '../subjects-actions'
import { ReportActions } from '@/components/reports/report-actions'

export default async function SubjectsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const { data: subjects, error } = await supabase
    .from('subjects')
    .select('id, code, name, domain, weekly_hours, is_active')
    .eq('school_id', context.profile.school_id)
    .order('domain')
    .order('name')

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Matières</h1>
          <p className="page-subtitle">Catalogue des matières de l'établissement et paramètres pédagogiques.</p>
        </div>
        <Link className="button button-primary" href="/pedagogie/matieres/nouveau">+ Nouvelle matière</Link>
      </div>

      {params.updated ? <p className="success">Modification enregistrée.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">Erreur de lecture : {error.message}</p> : null}

      <ReportActions title="Liste des matières" fileName="liste-matieres" headers={['Code', 'Matière', 'Domaine', 'Heures par semaine', 'Statut']} rows={(subjects ?? []).map((subject) => [subject.code, subject.name, subject.domain, subject.weekly_hours, subject.is_active ? 'Active' : 'Archivée'])} />

      {!subjects?.length ? (
        <section className="card empty">
          <h2 style={{ marginTop: 0, color: 'var(--text)' }}>Aucune matière configurée</h2>
          <p>Les matières officielles d'Al Amine seront saisies par l'administration. Aucune matière réelle n'est inventée dans le seed.</p>
          <Link className="button button-primary" href="/pedagogie/matieres/nouveau">Créer une matière de test</Link>
        </section>
      ) : (
        <section className="card">
          <div className="table-wrap">
            <table>
              <thead><tr><th>Code</th><th>Matière</th><th>Domaine</th><th>H/semaine</th><th>Statut</th><th></th></tr></thead>
              <tbody>
                {subjects.map((subject) => (
                  <tr key={subject.id}>
                    <td>{subject.code}</td>
                    <td>{subject.name}</td>
                    <td>{subject.domain}</td>
                    <td>{subject.weekly_hours ?? '—'}</td>
                    <td><span className="badge">{subject.is_active ? 'Active' : 'Archivée'}</span></td>
                    <td className="actions">
                      <Link className="button button-secondary" href={`/pedagogie/matieres/${subject.id}`}>Ouvrir</Link>
                      <form action={toggleSubject}>
                        <input type="hidden" name="id" value={subject.id} />
                        <input type="hidden" name="active" value={String(!subject.is_active)} />
                        <button className="button button-secondary" type="submit">{subject.is_active ? 'Archiver' : 'Réactiver'}</button>
                      </form>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </main>
  )
}
