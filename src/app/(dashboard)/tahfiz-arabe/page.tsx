import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function TahfizArabicPage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const [{ count: tahfizStudents }, { count: tahfizSessions }, { count: arabicStudents }, { count: arabicEvaluations }] = await Promise.all([
    supabase.from('student_tahfiz').select('id', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('tahfiz_sessions').select('id', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('student_arabic').select('id', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('arabic_evaluations').select('id', { count: 'exact', head: true }).eq('school_id', schoolId),
  ])
  return <main className="page">
    <div className="page-header">
      <div><p className="page-subtitle">Étape 20 • Formation spécialisée</p><h1 className="page-title">Tahfiz / Arabe</h1><p className="page-subtitle">Suivi des apprentissages spécialisés, de la progression et des résultats, dans le dossier global de l’élève.</p></div>
    </div>
    <section className="grid grid-4" style={{ marginBottom: 16 }}>
      <article className="card"><div className="stat-label">Élèves Tahfiz</div><div className="stat-value">{tahfizStudents ?? 0}</div></article>
      <article className="card"><div className="stat-label">Séances Tahfiz</div><div className="stat-value">{tahfizSessions ?? 0}</div></article>
      <article className="card"><div className="stat-label">Élèves Arabe</div><div className="stat-value">{arabicStudents ?? 0}</div></article>
      <article className="card"><div className="stat-label">Évaluations Arabe</div><div className="stat-value">{arabicEvaluations ?? 0}</div></article>
    </section>
    <section className="grid grid-2">
      <Link className="card" href="/tahfiz-arabe/tahfiz"><h2>Tahfiz</h2><p className="page-subtitle">Niveaux, affectations, nouvelles mémorisations, révisions, récitations, évaluations, présence et progression.</p></Link>
      <Link className="card" href="/tahfiz-arabe/arabe"><h2>Arabe</h2><p className="page-subtitle">Niveaux, parcours individuels, séances, présence, évaluations et progression en formation arabe.</p></Link>
    </section>
    <section className="card" style={{ marginTop: 16 }}>
      <h2>Principe de conception</h2>
      <p>Les niveaux, contenus, domaines d’évaluation, observations et progressions restent paramétrables : le cahier des charges décrit le besoin fonctionnel mais ne fixe pas de référentiel officiel détaillé.</p>
      <p className="page-subtitle">Les résultats visibles aux parents/élèves sont soumis à publication par les responsables autorisés.</p>
    </section>
  </main>
}
