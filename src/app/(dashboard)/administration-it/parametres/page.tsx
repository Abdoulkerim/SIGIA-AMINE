import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function ITSettingsPage() {
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) return <main className="page"><p className="empty">Aucun établissement associé à ce compte.</p></main>

  const supabase = await createClient()
  const [{ data: school, error: schoolError }, { data: settings, error: settingsError }, { data: years }] = await Promise.all([
    supabase.from('schools').select('name,short_name,legal_name,code,email,phone,address,city,country,currency_code,timezone,website,is_active').eq('id', schoolId).maybeSingle(),
    supabase.from('school_settings').select('default_language,grading_scale,passing_score,late_tolerance_minutes,invoice_prefix,receipt_prefix,student_prefix,updated_at').eq('school_id', schoolId).maybeSingle(),
    supabase.from('school_years').select('name,is_current,start_date,end_date').eq('school_id', schoolId).order('start_date', { ascending: false }).limit(6),
  ])

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Paramètres établissement</h1><p className="page-subtitle">Informations de l’école et principales valeurs de configuration.</p></div></div>
      {schoolError ? <p className="error">Impossible de charger l’établissement : {schoolError.message}</p> : null}
      {settingsError ? <p className="error">Impossible de charger les paramètres : {settingsError.message}</p> : null}

      <section className="grid grid-2">
        <article className="card">
          <h2 style={{ marginTop: 0 }}>Établissement</h2>
          <dl className="it-settings-list">
            <div><dt>Nom</dt><dd>{school?.name ?? '—'}</dd></div>
            <div><dt>Nom légal</dt><dd>{school?.legal_name ?? '—'}</dd></div>
            <div><dt>Code</dt><dd>{school?.code ?? '—'}</dd></div>
            <div><dt>Adresse</dt><dd>{[school?.address, school?.city, school?.country].filter(Boolean).join(', ') || '—'}</dd></div>
            <div><dt>Contact</dt><dd>{[school?.phone, school?.email].filter(Boolean).join(' · ') || '—'}</dd></div>
            <div><dt>Devise / fuseau</dt><dd>{school?.currency_code ?? '—'} · {school?.timezone ?? '—'}</dd></div>
            <div><dt>Site web</dt><dd>{school?.website ?? '—'}</dd></div>
            <div><dt>État</dt><dd><span className="badge">{school?.is_active ? 'Actif' : 'Inactif'}</span></dd></div>
          </dl>
        </article>

        <article className="card">
          <h2 style={{ marginTop: 0 }}>Paramètres de gestion</h2>
          {settings ? (
            <dl className="it-settings-list">
              <div><dt>Langue par défaut</dt><dd>{settings.default_language}</dd></div>
              <div><dt>Barème de notation</dt><dd>{settings.grading_scale}</dd></div>
              <div><dt>Note de passage</dt><dd>{settings.passing_score}</dd></div>
              <div><dt>Tolérance de retard</dt><dd>{settings.late_tolerance_minutes} min</dd></div>
              <div><dt>Préfixe élève</dt><dd>{settings.student_prefix}</dd></div>
              <div><dt>Préfixe facture</dt><dd>{settings.invoice_prefix}</dd></div>
              <div><dt>Préfixe reçu</dt><dd>{settings.receipt_prefix}</dd></div>
              <div><dt>Dernière mise à jour</dt><dd>{new Date(settings.updated_at).toLocaleString('fr-FR')}</dd></div>
            </dl>
          ) : <p className="empty">Aucun paramètre général défini pour cet établissement.</p>}
        </article>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2 style={{ marginTop: 0 }}>Années scolaires</h2>
        {years?.length ? <div className="table-wrap"><table><thead><tr><th>Année</th><th>Début</th><th>Fin</th><th>État</th></tr></thead><tbody>{years.map((year) => <tr key={year.name}><td>{year.name}</td><td>{year.start_date}</td><td>{year.end_date}</td><td><span className="badge">{year.is_current ? 'En cours' : 'Archivée'}</span></td></tr>)}</tbody></table></div> : <p className="empty">Aucune année scolaire enregistrée.</p>}
      </section>
    </main>
  )
}
