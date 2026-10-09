import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { updateClass } from '../../academic-actions'

export default async function ClassDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const { id } = await params
  const query = await searchParams
  const supabase = await createClient()

  const [{ data: item }, { data: years }] = await Promise.all([
    supabase.from('classes').select('id, school_year_id, name, code, section, room_name, capacity, is_active').eq('id', id).eq('school_id', context.profile.school_id).single(),
    supabase.from('school_years').select('id,name,is_current').eq('school_id', context.profile.school_id).order('start_date', { ascending: false }),
  ])

  if (!item) {
    return <main className="page"><p className="error">Classe introuvable.</p><Link className="button button-secondary" href="/administration/classes">Retour</Link></main>
  }

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">{item.name}</h1>
          <p className="page-subtitle">Code : {item.code}</p>
        </div>
        <Link className="button button-secondary" href="/administration/classes">Retour</Link>
      </div>

      {query.updated ? <p className="success">Classe modifiée.</p> : null}
      {query.error ? <p className="error">{query.error}</p> : null}
      <section className="card">
        <form action={updateClass} className="grid grid-2">
          <input type="hidden" name="id" value={item.id} />
          <div className="field">
            <label className="label" htmlFor="schoolYearId">Année scolaire *</label>
            <select className="select" id="schoolYearId" name="schoolYearId" defaultValue={item.school_year_id} required>
              {(years ?? []).map((year) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
            </select>
          </div>
          <div className="field"><label className="label" htmlFor="code">Code *</label><input className="input" id="code" name="code" required defaultValue={item.code} /></div>
          <div className="field"><label className="label" htmlFor="name">Nom *</label><input className="input" id="name" name="name" required defaultValue={item.name} /></div>
          <div className="field"><label className="label" htmlFor="section">Section</label><input className="input" id="section" name="section" defaultValue={item.section ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="roomName">Salle</label><input className="input" id="roomName" name="roomName" defaultValue={item.room_name ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="capacity">Effectif maximal</label><input className="input" id="capacity" name="capacity" type="number" min="1" step="1" defaultValue={item.capacity ?? ''} /></div>
          <div className="actions" style={{ alignSelf: 'end' }}><button className="button button-primary" type="submit">Enregistrer</button><Link className="button button-secondary" href="/administration/classes">Annuler</Link></div>
        </form>
      </section>
    </main>
  )
}
