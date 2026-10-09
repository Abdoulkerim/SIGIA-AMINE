import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClass } from '../../academic-actions'

export default async function NewClassPage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const supabase = await createClient()
  const { data: years } = await supabase
    .from('school_years')
    .select('id, name, is_current')
    .eq('school_id', context.profile.school_id)
    .order('start_date', { ascending: false })

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouvelle classe</h1>
          <p className="page-subtitle">Renseigner l’année scolaire, l’identification et les capacités de la classe.</p>
        </div>
        <Link className="button button-secondary" href="/administration/classes">Retour</Link>
      </div>

      <section className="card" style={{ maxWidth: 900 }}>
        <form action={createClass} className="grid grid-2">
          <div className="field">
            <label className="label" htmlFor="schoolYearId">Année scolaire *</label>
            <select className="select" id="schoolYearId" name="schoolYearId" required defaultValue={years?.find((year) => year.is_current)?.id ?? years?.[0]?.id ?? ''}>
              {(years ?? []).map((year) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
            </select>
          </div>
          <div className="field">
            <label className="label" htmlFor="code">Code *</label>
            <input className="input" id="code" name="code" required maxLength={50} placeholder="Ex. 6EME-A" />
          </div>
          <div className="field">
            <label className="label" htmlFor="name">Nom de la classe *</label>
            <input className="input" id="name" name="name" required maxLength={120} placeholder="Ex. 6e A" />
          </div>
          <div className="field">
            <label className="label" htmlFor="section">Section</label>
            <input className="input" id="section" name="section" maxLength={50} placeholder="Ex. A" />
          </div>
          <div className="field">
            <label className="label" htmlFor="roomName">Salle</label>
            <input className="input" id="roomName" name="roomName" maxLength={120} placeholder="Ex. Salle 3" />
          </div>
          <div className="field">
            <label className="label" htmlFor="capacity">Effectif maximal</label>
            <input className="input" id="capacity" name="capacity" type="number" min="1" step="1" />
          </div>
          <div className="actions" style={{ gridColumn: '1 / -1' }}>
            <button className="button button-primary" type="submit">Créer la classe</button>
            <Link className="button button-secondary" href="/administration/classes">Annuler</Link>
          </div>
        </form>
      </section>
    </main>
  )
}
