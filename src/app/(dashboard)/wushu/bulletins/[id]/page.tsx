import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { ArabicReportCardPrint } from '@/components/pedagogy/arabic-report-card-print'

type Evaluation = { date?: string; type?: string; area?: string; score?: number | string; max_score?: number | string; grade?: string; observation?: string }
type SubjectRow = Evaluation & { name: string; coefficient: number; weighted: number; normalized: number }

function dateLabel(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(`${value}T00:00:00`)
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('fr-FR').format(date)
}
function number(value: number) { return value.toLocaleString('fr-FR', { maximumFractionDigits: 2 }) }
function coefficient(label: string) {
  const normalized = label.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  return normalized.includes('tao impose') || normalized === 'combat' ? 2 : 1
}
function weightedAverage(items: Evaluation[]) {
  let points = 0
  let weights = 0
  for (const item of items) {
    const max = Number(item.max_score) || 20
    const score = Number(item.score) || 0
    const weight = coefficient(item.area || item.type || '')
    points += (max > 0 ? score * 20 / max : score) * weight
    weights += weight
  }
  return weights ? points / weights : 0
}
function appreciation(score: number) {
  if (score >= 18) return 'Excellent'
  if (score >= 16) return 'Très bien'
  if (score >= 14) return 'Bien'
  if (score >= 12) return 'Passable'
  if (score >= 10) return 'Moyen'
  return 'Insuffisant'
}
function schoolYear(date: string) {
  const [year, month] = date.split('-').map(Number)
  const start = month >= 8 ? year : year - 1
  return `${start} – ${start + 1}`
}

export default async function WushuReportCardPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) return null
  const supabase = await createClient()
  const db = supabase as any
  const { data: card } = await db.from('specialized_report_cards').select('id,student_id,period_start,period_end,average_score,evaluation_count,evaluations,status,students(id,first_name,last_name,student_number,date_of_birth,place_of_birth,gender)').eq('id', id).eq('school_id', schoolId).eq('module', 'wushu').maybeSingle()
  if (!card) notFound()
  const [{ data: profile }, { data: peers }] = await Promise.all([
    db.from('student_wushu').select('current_grade,group_id,wushu_groups(name,level)').eq('school_id', schoolId).eq('student_id', card.student_id).maybeSingle(),
    db.from('student_wushu').select('student_id,group_id').eq('school_id', schoolId).eq('status', 'active'),
  ])
  const student = Array.isArray(card.students) ? card.students[0] : card.students
  const peerIds = (peers ?? []).filter((item: any) => item.student_id !== card.student_id && item.group_id === profile?.group_id).map((item: any) => item.student_id)
  const [{ data: peerCards }, { count: groupSize }] = await Promise.all([
    peerIds.length && profile?.group_id
      ? db.from('specialized_report_cards').select('student_id,evaluations').eq('school_id', schoolId).eq('module', 'wushu').eq('period_start', card.period_start).eq('period_end', card.period_end).in('student_id', peerIds)
      : Promise.resolve({ data: [] }),
    profile?.group_id
      ? db.from('student_wushu').select('id', { count: 'exact', head: true }).eq('school_id', schoolId).eq('group_id', profile.group_id).eq('status', 'active')
      : Promise.resolve({ count: null }),
  ])
  const evaluations: Evaluation[] = Array.isArray(card.evaluations) ? card.evaluations : []
  const subjectGroups = new Map<string, Evaluation[]>()
  for (const item of evaluations) {
    const name = item.area || item.type || 'Évaluation Wushu'
    subjectGroups.set(name, [...(subjectGroups.get(name) ?? []), item])
  }
  const rows: SubjectRow[] = [...subjectGroups.entries()].map(([name, items]) => {
    const normalizedScores = items.map(item => {
      const max = Number(item.max_score) || 20
      const score = Number(item.score) || 0
      return max > 0 ? score * 20 / max : score
    })
    const normalized = normalizedScores.reduce((sum, score) => sum + score, 0) / normalizedScores.length
    const weight = coefficient(name)
    const lastItem = items[items.length - 1]
    return { ...lastItem, name, score: normalized, max_score: 20, coefficient: weight, normalized, weighted: normalized * weight }
  })
  const coefficientTotal = rows.reduce((sum, row) => sum + row.coefficient, 0)
  const totalPoints = rows.reduce((sum, row) => sum + row.weighted, 0)
  const maxPoints = coefficientTotal * 20
  const average = coefficientTotal ? totalPoints / coefficientTotal : Number(card.average_score) || 0
  const classScores = [...(peerCards ?? []).map((item: any) => weightedAverage(Array.isArray(item.evaluations) ? item.evaluations : [])), average]
  const sorted = [...classScores].sort((a, b) => b - a)
  const rank = sorted.findIndex(score => score === average) + 1
  const classAverage = classScores.reduce((sum, score) => sum + score, 0) / (classScores.length || 1)
  const latestGrade = [...evaluations].reverse().find(item => item.grade)?.grade
  const group = Array.isArray(profile?.wushu_groups) ? profile.wushu_groups[0] : profile?.wushu_groups
  const gender = student?.gender === 'female' ? 'Féminin' : student?.gender === 'male' ? 'Masculin' : '—'
  const decision = average >= 10 ? 'Admis(e)' : 'À reprendre'

  return <main className="page wushu-report-page">
    <div className="page-header no-print"><div><h1 className="page-title">Bulletin Wushu</h1><p className="page-subtitle">Aperçu conforme au modèle fourni, prêt à imprimer.</p></div><div className="actions"><Link className="button button-secondary" href="/wushu/bulletins">Retour aux bulletins</Link><ArabicReportCardPrint /></div></div>
    <article className="wushu-report-sheet">
      <header className="wushu-report-head">
        <h1>Complexe scolaire Al Amine du Bazèga</h1>
        <p className="wushu-tagline">Al Amine, un système éducatif digne de confiance</p>
        <p className="wushu-contact">Tél. : +226 77561518 / 69846076 / 70049600</p>
        <div className="wushu-report-identifiers"><div><strong>ID élève :</strong> {student?.student_number ?? '—'}<br/><strong>Code bulletin :</strong> {card.id.slice(0, 8).toUpperCase()}</div><img className="wushu-club-logo" src="/kung-fu-groupe-al-amine.png" width="90" height="90" alt="Club Kung Fu Wushu Al Amine"/><div className="wushu-school-mark"><img src="/logo-complexe-scolaire-al-amine.jpg" width="190" height="86" alt="Groupe scolaire Al Amine"/><b>Sciences · Sagesse · Succès</b></div><img className="wushu-club-logo" src="/kung-fu-groupe-al-amine.png" width="90" height="90" alt="Club Kung Fu Wushu Al Amine"/><div><strong>Matricule :</strong> {student?.student_number ?? '—'}<br/><strong>Année scolaire :</strong> {schoolYear(card.period_start)}</div></div>
        <h2>BULLETIN DE NOTES DE KUNG FU WUSHU</h2>
        <div className="wushu-passage">{rows.find(row => row.type)?.type || 'ÉVALUATION DE WUSHU'}</div>
      </header>
      <section className="wushu-student-info">
        <div><strong>Nom et Prénom(s) :</strong> {student?.last_name} {student?.first_name}</div>
        <div><strong>Né(e) le :</strong> {dateLabel(student?.date_of_birth)} <span>à {student?.place_of_birth || '—'}</span><span>Sexe : {gender}</span></div>
        <div><strong>Grade détenu :</strong> {profile?.current_grade || '—'}</div>
        <div><strong>Grade postulé :</strong> {latestGrade || '—'} <span className="wushu-group-size">Effectif : {groupSize ?? '—'} élèves</span></div>
        {group ? <div><strong>Groupe :</strong> {group.name}{group.level ? ` · ${group.level}` : ''}</div> : null}
      </section>
      <table className="wushu-report-table"><thead><tr><th>MATIÈRES</th><th>Note / 20</th><th>Coef.</th><th>Pondérée</th><th>APPRÉCIATIONS</th></tr></thead><tbody>
        {rows.map((row, index) => <tr key={`${row.date}-${index}`}><td>{row.name}</td><td><strong>{number(row.normalized)}</strong></td><td className="wushu-coeff">{row.coefficient}</td><td><strong>{number(row.weighted)}</strong></td><td>{appreciation(row.normalized)}</td></tr>)}
        {!rows.length ? <tr><td colSpan={5}>Aucune note enregistrée pour cette période.</td></tr> : null}
      </tbody></table>
      <section className="wushu-report-summary">
        <div className="wushu-total"><strong>TOTAL DES POINTS</strong><b>{number(totalPoints)} sur {number(maxPoints)}</b><strong>TOTAL COEF. : {number(coefficientTotal)}</strong></div>
        <div className="wushu-summary-left"><div><strong>Moyenne de l’élève :</strong><b>{number(average)} sur 20</b></div><div><strong>Rang de l’élève :</strong><b>{rank ? `${rank}${rank === 1 ? 'er' : 'ème'} sur ${classScores.length} bulletins` : '—'}</b></div><div><strong>Moyenne du groupe :</strong><b>{number(classAverage)} sur 20</b></div><div><strong>Plus forte moyenne :</strong><b>{number(Math.max(...classScores))} sur 20</b></div><div><strong>Plus faible moyenne :</strong><b>{number(Math.min(...classScores))} sur 20</b></div></div>
        <div className="wushu-summary-right"><strong>APPRÉCIATION</strong><b>{appreciation(average)}</b><strong>CONDUITE</strong><b>—</b></div>
      </section>
      <footer className="wushu-report-footer"><div><strong>*** DÉCISION ***</strong><b>{decision}</b><span>Fait le : {dateLabel(new Date().toISOString().slice(0, 10))}</span></div><div><strong>Le Directeur technique</strong><span>Signature et cachet</span></div></footer>
    </article>
  </main>
}
