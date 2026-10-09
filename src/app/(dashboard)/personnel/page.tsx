import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function PersonnelPage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const today = new Date().toISOString().slice(0, 10)
  const { data: dashboard } = await supabase.rpc('get_hr_dashboard', {
    p_school_id: context.profile.school_id,
    p_date: today,
  })
  const stats = dashboard ?? {}
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Personnel / RH / Paie</h1><p className="page-subtitle">Dossiers administratifs, contrats, présence, congés, compétences, formations et rémunération.</p></div><div className="actions"><Link className="button button-primary" href="/personnel/employes/nouveau">+ Nouvel employé</Link></div></div>
    <section className="grid grid-4">
      <article className="card"><h3>Personnel</h3><p className="metric">{stats.employees ?? 0}</p><span className="badge">Actifs : {stats.active_employees ?? 0}</span></article>
      <article className="card"><h3>Présence aujourd’hui</h3><p className="metric">{stats.present_today ?? 0}</p><span className="badge">Absents : {stats.absent_today ?? 0} • Retards : {stats.late_today ?? 0}</span></article>
      <article className="card"><h3>Congés en cours</h3><p className="metric">{stats.on_leave_today ?? 0}</p><span className="badge">À la date du {today}</span></article>
      <article className="card"><h3>Paie</h3><p className="metric">{Number(stats.pending_payroll_amount ?? 0).toLocaleString('fr-FR')} FCFA</p><span className="badge">Montant en attente</span></article>
    </section>
    <section className="grid grid-2" style={{marginTop:16}}>
      <article className="card"><h2>Ressources humaines</h2><p>Gérez le dossier de chaque agent, les contrats, les absences, congés, compétences et formations.</p><div className="actions"><Link className="button button-secondary" href="/personnel/employes">Dossiers employés</Link><Link className="button button-secondary" href="/personnel/contrats">Contrats</Link><Link className="button button-secondary" href="/personnel/presences">Présences</Link><Link className="button button-secondary" href="/personnel/conges">Congés</Link><Link className="button button-secondary" href="/personnel/formations">Formations & compétences</Link></div></article>
      <article className="card"><h2>Paie</h2><p>Préparez, contrôlez, validez, payez puis clôturez chaque période de rémunération.</p><div className="actions"><Link className="button button-primary" href="/personnel/paie">Ouvrir la paie</Link></div><p className="page-subtitle" style={{marginTop:12}}>Les règles fiscales, sociales ou réglementaires ne sont pas déduites automatiquement : les montants de base, indemnités et retenues restent paramétrables.</p></article>
    </section>
  </main>
}
