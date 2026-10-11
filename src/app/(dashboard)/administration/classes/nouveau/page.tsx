import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClass } from '../../academic-actions'
import { SchoolYearSelect } from '@/components/administration/school-year-select'

export default async function NewClassPage({ searchParams }: { searchParams: Promise<{ error?: string; year?: string; createdYear?: string }> }) {
  const params = await searchParams
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const supabase = await createClient()
  const { data: years, error: yearsError } = await supabase
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

      {params.error ? <p className="error" role="alert">{params.error}</p> : null}
      {params.createdYear ? <p className="success">Année scolaire créée et sélectionnée.</p> : null}
      {yearsError ? <p className="error">Impossible de charger les années scolaires : {yearsError.message}</p> : null}
      {!years?.length ? <p className="error">Aucune année scolaire n’est configurée. Créez-en une pour pouvoir enregistrer une classe.</p> : null}

      <section className="card" style={{ maxWidth: 900 }}>
        <form action={createClass} className="grid grid-2">
          <div className="field">
            <label className="label" htmlFor="schoolYearId">Année scolaire *</label>
            <SchoolYearSelect years={years ?? []} name="schoolYearId" id="schoolYearId" value={params.year ?? years?.find((year) => year.is_current)?.id ?? years?.[0]?.id ?? ''} required returnTo="/administration/classes/nouveau" />
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
            <button className="button button-primary" type="submit" disabled={!years?.length}>Créer la classe</button>
            <Link className="button button-secondary" href="/administration/classes">Annuler</Link>
          </div>
        </form>
      </section>
    </main>
  )
}
