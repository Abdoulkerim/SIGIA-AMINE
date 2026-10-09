import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleLevel } from '../academic-actions'

export default async function LevelsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; created?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const { data: levels, error } = await supabase
    .from('levels')
    .select('id, code, name, education_cycle, sequence_no, is_active')
    .eq('school_id', context.profile.school_id)
    .order('sequence_no', { ascending: true, nullsFirst: false })
    .order('name')

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Niveaux</h1>
          <p className="page-subtitle">Référentiel des niveaux pédagogiques de l'établissement.</p>
        </div>
        <Link className="button button-primary" href="/administration/niveaux/nouveau">+ Nouveau niveau</Link>
      </div>

      {params.created ? <p className="success">Niveau créé.</p> : null}
      {params.updated ? <p className="success">Niveau modifié.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">Erreur : {error.message}</p> : null}

      <section className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Code</th><th>Nom</th><th>Cycle</th><th>Ordre</th><th>Statut</th><th>Action</th></tr>
            </thead>
            <tbody>
              {(levels ?? []).map((level) => (
                <tr key={level.id}>
                  <td>{level.code}</td>
                  <td>{level.name}</td>
                  <td>{level.education_cycle ?? '—'}</td>
                  <td>{level.sequence_no ?? '—'}</td>
                  <td><span className="badge">{level.is_active ? 'Actif' : 'Archivé'}</span></td>
                  <td>
                    <form action={toggleLevel}>
                      <input type="hidden" name="id" value={level.id} />
                      <input type="hidden" name="active" value={String(!level.is_active)} />
                      <button className="button button-secondary" type="submit">
                        {level.is_active ? 'Archiver' : 'Réactiver'}
                      </button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!levels?.length ? <p className="empty">Aucun niveau configuré. Les niveaux officiels d'Al Amine doivent être saisis par l'administration.</p> : null}
      </section>
    </main>
  )
}
