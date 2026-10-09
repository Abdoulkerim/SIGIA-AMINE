import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleClass } from '../academic-actions'

export default async function ClassesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; created?: string; updated?: string; year?: string; active?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const { data: years } = await supabase
    .from('school_years')
    .select('id, name, is_current')
    .eq('school_id', context.profile.school_id)
    .order('start_date', { ascending: false })

  const selectedYear = params.year || years?.find((y) => y.is_current)?.id || years?.[0]?.id || ''

  const { data: classes, error } = await supabase
    .from('classes')
    .select('id, name, code, section, room_name, capacity, is_active, school_year_id')
    .eq('school_id', context.profile.school_id)
    .eq('school_year_id', selectedYear)
    .order('name')

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Classes</h1>
          <p className="page-subtitle">Organisation des classes, des salles et des effectifs par année scolaire.</p>
        </div>
        <Link className="button button-primary" href="/administration/classes/nouveau">+ Nouvelle classe</Link>
      </div>

      {params.created ? <p className="success">Classe créée.</p> : null}
      {params.updated ? <p className="success">Classe modifiée.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">Erreur : {error.message}</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <form method="get" className="grid grid-3">
          <div className="field">
            <label className="label" htmlFor="year">Année scolaire</label>
            <select className="select" name="year" id="year" defaultValue={selectedYear}>
              {(years ?? []).map((year) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
            </select>
          </div>
          <div className="field">
            <span className="label">Classes</span>
            <span>{classes?.length ?? 0}</span>
          </div>
          <div className="field" style={{ alignSelf: 'end' }}>
            <button className="button button-secondary" type="submit">Afficher</button>
          </div>
        </form>
      </section>

      <section className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Code</th><th>Classe</th><th>Section</th><th>Salle</th><th>Effectif maximal</th><th>Statut</th><th>Action</th></tr>
            </thead>
            <tbody>
              {(classes ?? []).map((item) => (
                <tr key={item.id}>
                  <td>{item.code}</td>
                  <td>{item.name}</td>
                  <td>{item.section ?? '—'}</td>
                  <td>{item.room_name ?? '—'}</td>
                  <td>{item.capacity ?? '—'}</td>
                  <td><span className="badge">{item.is_active ? 'Active' : 'Archivée'}</span></td>
                  <td className="actions">
                    <Link className="button button-secondary" href={`/administration/classes/${item.id}`}>Ouvrir</Link>
                    <form action={toggleClass}>
                      <input type="hidden" name="id" value={item.id} />
                      <input type="hidden" name="active" value={String(!item.is_active)} />
                      <button className="button button-secondary" type="submit">
                        {item.is_active ? 'Archiver' : 'Réactiver'}
                      </button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!classes?.length ? <p className="empty">Aucune classe pour cette année. Configure d'abord les niveaux officiels.</p> : null}
      </section>
    </main>
  )
}
