import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function SchoolLifePage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)

  const [sessions, absent, late, openFollowups, incidents, pendingJustifications, rewards] = await Promise.all([
    supabase.from('attendance_sessions').select('id', { count: 'exact', head: true }).eq('school_id', schoolId).gte('session_date', since),
    supabase.from('attendance_records').select('id', { count: 'exact', head: true }).eq('status', 'absent'),
    supabase.from('attendance_records').select('id', { count: 'exact', head: true }).eq('status', 'late'),
    supabase.from('student_followups').select('id', { count: 'exact', head: true }).in('status', ['open', 'in_progress']),
    supabase.from('discipline_events').select('id', { count: 'exact', head: true }).eq('school_id', schoolId).gte('event_date', since),
    supabase.from('absence_justifications').select('id', { count: 'exact', head: true }).eq('school_id', schoolId).eq('status', 'pending'),
    supabase.from('student_rewards').select('id', { count: 'exact', head: true }).eq('school_id', schoolId).gte('reward_date', since),
  ])

  const cards = [
    ['Séances d’appel (30 j)', sessions.count ?? 0],
    ['Absences enregistrées', absent.count ?? 0],
    ['Retards enregistrés', late.count ?? 0],
    ['Suivis ouverts', openFollowups.count ?? 0],
    ['Incidents (30 j)', incidents.count ?? 0],
    ['Justificatifs en attente', pendingJustifications.count ?? 0],
    ['Récompenses (30 j)', rewards.count ?? 0],
  ]

  const links = [
    ['Présences & appels', '/vie-scolaire/presences', 'Créer les séances et saisir les statuts présence/absence/retard.'],
    ['Justificatifs', '/vie-scolaire/justificatifs', 'Suivre et traiter les demandes de justification.'],
    ['Discipline', '/vie-scolaire/discipline', 'Incidents, observations, sanctions et actions prises.'],
    ['Suivi éducatif', '/vie-scolaire/suivi-educatif', 'Observations, actions d’accompagnement et bilans de suivi.'],
    ['Récompenses', '/vie-scolaire/recompenses', 'Valoriser les réussites et les comportements positifs.'],
    ['Catégories discipline', '/vie-scolaire/discipline/categories', 'Paramétrer les catégories et leur niveau de gravité.'],
  ]

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Vie scolaire</h1>
          <p className="page-subtitle">Présence, absence, retard, discipline et suivi éducatif de l’élève.</p>
        </div>
      </div>

      <section className="grid grid-4" style={{ marginBottom: 16 }}>
        {cards.map(([label, value]) => (
          <article className="card" key={String(label)}>
            <div className="stat-label">{label}</div>
            <div className="stat-value">{value}</div>
          </article>
        ))}
      </section>

      <section className="grid grid-2">
        {links.map(([title, href, description]) => (
          <Link className="card" href={href} key={href}>
            <h2 style={{ marginTop: 0 }}>{title}</h2>
            <p className="page-subtitle">{description}</p>
          </Link>
        ))}
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <strong>Principe métier</strong>
        <p className="page-subtitle" style={{ marginBottom: 0 }}>
          Les données de vie scolaire restent rattachées à l’élève, à son école et à son année scolaire. Les règles détaillées de calcul de présence, les barèmes disciplinaires et les procédures officielles de sanction ne sont pas précisés dans le cahier des charges : SIGIA-AMINE les laisse donc paramétrables au lieu d’inventer une règle institutionnelle.
        </p>
      </section>
    </main>
  )
}
