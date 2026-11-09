import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { ArabicReportCardPrint } from '@/components/pedagogy/arabic-report-card-print'

type Evaluation = { date?: string; type?: string; area?: string; score?: number | string; max_score?: number | string; observation?: string }

function appreciation(score: number) {
  if (score >= 18) return 'Excellent'
  if (score >= 16) return 'Très bien'
  if (score >= 14) return 'Bien'
  if (score >= 10) return 'Assez bien'
  return 'À renforcer'
}

function dateLabel(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(`${value}T00:00:00`)
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('fr-FR').format(date)
}

export default async function ArabicReportCardPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) return null
  const supabase = await createClient()
  const db = supabase as any
  const { data: card } = await db.from('specialized_report_cards')
    .select('id,student_id,period_start,period_end,average_score,evaluation_count,evaluations,status,students(id,first_name,last_name,student_number,date_of_birth,place_of_birth,gender)')
    .eq('id', id).eq('school_id', schoolId).eq('module', 'arabic').maybeSingle()
  if (!card) notFound()
  const [{ data: arabicProfile }, { data: user }] = await Promise.all([
    db.from('student_arabic').select('arabic_full_name,arabic_levels(name),employees(first_name,last_name)').eq('school_id', schoolId).eq('student_id', card.student_id).maybeSingle(),
    supabase.auth.getUser(),
  ])
  const student = Array.isArray(card.students) ? card.students[0] : card.students
  const evaluations: Evaluation[] = Array.isArray(card.evaluations) ? card.evaluations : []
  const total = evaluations.reduce((sum, item) => sum + (Number(item.score) || 0), 0)
  const maxTotal = evaluations.reduce((sum, item) => sum + (Number(item.max_score) || 20), 0)
  const teacher = Array.isArray(arabicProfile?.employees) ? arabicProfile.employees[0] : arabicProfile?.employees
  const level = Array.isArray(arabicProfile?.arabic_levels) ? arabicProfile.arabic_levels[0] : arabicProfile?.arabic_levels

  return <main className="page arabic-report-page">
    <div className="page-header no-print"><div><h1 className="page-title">Bulletin Arabe</h1><p className="page-subtitle">Aperçu imprimable inspiré du bulletin fourni.</p></div><div className="actions"><Link className="button button-secondary" href="/tahfiz-arabe/arabe/bulletins">Retour aux bulletins</Link><ArabicReportCardPrint /></div></div>
    <article className="arabic-report-sheet" lang="fr">
      <header className="arabic-report-head">
        <div className="arabic-report-stars" aria-hidden="true">★ ★ ★ <span>معهد الأمين</span> ★ ★ ★</div>
        <h1>Lycée privé Al Amine du Bazèga</h1>
        <p>Un système éducatif digne de confiance</p>
        <p className="arabic-report-contact">Bulletin de formation spécialisée · Arabe</p>
      </header>
      <div className="arabic-report-meta">
        <div><strong>ID élève :</strong> {student?.student_number ?? '—'}<br/><strong>Code bulletin :</strong> {card.id.slice(0, 8).toUpperCase()}</div>
        <div className="arabic-meta-center"><strong>كشف درجات اللغة العربية</strong><br/>Résultats de la période</div>
        <div className="arabic-meta-right"><strong>Période :</strong> {dateLabel(card.period_start)} – {dateLabel(card.period_end)}<br/><strong>Émis le :</strong> {dateLabel(new Date().toISOString().slice(0, 10))}</div>
      </div>
      <section className="arabic-report-student">
        <div><strong>Nom &amp; prénom :</strong> {student?.last_name} {student?.first_name}</div>
        <div className="arabic-student-name" dir="rtl" lang="ar"><strong>الاسم واللقب :</strong> {arabicProfile?.arabic_full_name || '—'}</div>
        <div><strong>Date de naissance :</strong> {dateLabel(student?.date_of_birth)} <span><strong>Lieu :</strong> {student?.place_of_birth || '—'}</span></div>
        <div><strong>Niveau :</strong> {level?.name || '—'} <span><strong>Enseignant :</strong> {teacher ? `${teacher.last_name} ${teacher.first_name}` : '—'}</span></div>
      </section>
      <table className="arabic-report-table">
        <thead><tr><th>Matières / compétences</th><th>Moyenne</th><th>Appréciation</th><th dir="rtl" lang="ar">المواد</th><th>Signature</th></tr></thead>
        <tbody>{evaluations.map((evaluation, index) => {
          const score = Number(evaluation.score) || 0
          const max = Number(evaluation.max_score) || 20
          const normalized = max > 0 ? score * 20 / max : score
          const label = evaluation.area || evaluation.type || 'Évaluation'
          return <tr key={`${evaluation.date}-${index}`}><td>{label}{evaluation.type && evaluation.area ? <small>{evaluation.type}</small> : null}</td><td><strong>{score.toLocaleString('fr-FR')}</strong> / {max.toLocaleString('fr-FR')}</td><td>{appreciation(normalized)}</td><td dir="rtl" lang="ar">{label}</td><td></td></tr>
        })}</tbody>
      </table>
      {!evaluations.length ? <p className="empty">Aucune note enregistrée pour cette période.</p> : null}
      <section className="arabic-report-summary">
        <div className="arabic-report-total"><strong>TOTAL DES POINTS</strong><span>{total.toLocaleString('fr-FR')} / {maxTotal.toLocaleString('fr-FR')}</span></div>
        <div><strong>Moyenne de la période :</strong><b>{Number(card.average_score).toLocaleString('fr-FR')} / 20</b></div>
        <div><strong>Rang :</strong><b>—</b></div>
        <div><strong>Nombre d’évaluations :</strong><b>{card.evaluation_count}</b></div>
        <div className="arabic-report-judgment"><strong>Appréciation</strong><b>{appreciation(Number(card.average_score))}</b><strong>Observation</strong><b>{evaluations.find(item => item.observation)?.observation || '—'}</b></div>
      </section>
      <footer className="arabic-report-signatures"><div>Fait le : {dateLabel(new Date().toISOString().slice(0, 10))}<p>Signature du parent</p></div><div>La direction des études<p>{user.user?.email ?? 'Signature et cachet'}</p></div></footer>
    </article>
  </main>
}
