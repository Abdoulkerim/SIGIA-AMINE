import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function PedagogiePage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const schoolId = context.profile.school_id

  const [{ count: timetableCount }, { count: assessmentsCount }, { count: gradesCount }, { count: reportCardsCount }] = await Promise.all([
    supabase.from('timetable_slots').select('*', { count: 'exact', head: true }).eq('school_id', schoolId).eq('is_active', true),
    supabase.from('assessments').select('*', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('grades').select('*', { count: 'exact', head: true }).in('assessment_id', await getAssessmentIds(supabase, schoolId)),
    supabase.from('report_cards').select('*', { count: 'exact', head: true }).eq('school_id', schoolId),
  ])

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Pédagogie</h1>
          <p className="page-subtitle">Classe → Matière → Enseignant → Évaluation → Note → Moyenne → Bulletin.</p>
        </div>
      </div>

      <section className="grid grid-4">
        <Stat label="Créneaux actifs" value={timetableCount ?? 0} />
        <Stat label="Évaluations" value={assessmentsCount ?? 0} />
        <Stat label="Notes" value={gradesCount ?? 0} />
        <Stat label="Bulletins" value={reportCardsCount ?? 0} />
      </section>

      <section className="grid grid-2" style={{ marginTop: 20 }}>
        <article className="card">
          <h2 style={{ marginTop: 0 }}>Emploi du temps</h2>
          <p className="page-subtitle">Créer les créneaux et bloquer les conflits de classe, d’enseignant et de salle.</p>
          <Link className="button button-primary" href="/pedagogie/emploi-du-temps">Ouvrir</Link>
        </article>
        <article className="card">
          <h2 style={{ marginTop: 0 }}>Évaluations et notes</h2>
          <p className="page-subtitle">Créer une évaluation, saisir les notes, puis publier l’évaluation.</p>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <Link className="button button-primary" href="/pedagogie/evaluations">Évaluations</Link>
            <Link className="button button-secondary" href="/pedagogie/types-evaluations">Types</Link>
          </div>
        </article>
        <article className="card">
          <h2 style={{ marginTop: 0 }}>Bulletins</h2>
          <p className="page-subtitle">Générer un brouillon à partir des notes publiées, puis publier après clôture de la période.</p>
          <Link className="button button-primary" href="/pedagogie/bulletins">Ouvrir</Link>
        </article>
        <article className="card">
          <h2 style={{ marginTop: 0 }}>Matières & affectations</h2>
          <p className="page-subtitle">Les étapes 10 et 11 restent la source de vérité pour le catalogue et les affectations.</p>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <Link className="button button-secondary" href="/pedagogie/matieres">Matières</Link>
            <Link className="button button-secondary" href="/pedagogie/affectations">Affectations</Link>
          </div>
        </article>
      </section>

      <section className="card" style={{ marginTop: 20 }}>
        <h2 style={{ marginTop: 0 }}>Point important</h2>
        <p style={{ marginBottom: 0, color: 'var(--muted)' }}>
          Aucun type d’évaluation officiel, coefficient spécifique, règle de classement ou décision de passage n’est inventé dans cette étape. Les fonctions de bulletin laissent volontairement <code>rank</code> et <code>decision</code> à null tant que les règles pédagogiques officielles d’Al Amine ne sont pas fournies.
        </p>
      </section>
    </main>
  )
}

async function getAssessmentIds(supabase: Awaited<ReturnType<typeof createClient>>, schoolId: string) {
  const { data } = await supabase.from('assessments').select('id').eq('school_id', schoolId)
  return (data ?? []).map((row) => row.id)
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="card">
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
    </div>
  )
}
