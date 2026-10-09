import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { saveAssessmentGradesFromForm } from '../../../pedagogie-actions'

export default async function AssessmentGradesPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; created?: string; saved?: string }> }) {
  const { id } = await params
  const query = await searchParams
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const { data: assessment, error: assessmentError } = await supabase
    .from('assessments')
    .select('id,title,max_score,is_published,school_year_id,class_id,period_id,subjects!assessments_subject_id_fkey(name),classes!assessments_class_id_fkey(name,code),academic_periods!assessments_period_id_fkey(name,is_closed),employees!assessments_teacher_id_fkey(first_name,last_name)')
    .eq('id', id)
    .single()
    .overrideTypes<{
      subjects: { name: string } | null
      classes: { name: string; code: string } | null
      academic_periods: { name: string; is_closed: boolean } | null
      employees: { first_name: string; last_name: string } | null
    }>()
  if (assessmentError || !assessment) return <main className="page"><p className="error">Évaluation introuvable.</p></main>

  const { data: students } = await supabase
    .from('enrollments')
    .select('student_id, students(id,first_name,last_name,student_number)')
    .eq('school_year_id', assessment.school_year_id)
    .eq('class_id', assessment.class_id)
    .eq('status','enrolled')
    .order('students(last_name)')
  const { data: grades } = await supabase.from('grades').select('student_id,score,observation').eq('assessment_id', id)
  const gradeMap = new Map((grades ?? []).map(g=>[g.student_id,g]))

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Saisie des notes</h1><p className="page-subtitle">{assessment.title} · {assessment.subjects?.name ?? 'Matière'} · {assessment.classes?.name ?? 'Classe'} · barème {assessment.max_score}</p></div><Link className="button button-secondary" href="/pedagogie/evaluations">Retour</Link></div>
      {query.created ? <p className="success">Évaluation créée. Saisissez maintenant les notes.</p> : null}{query.saved ? <p className="success">Notes enregistrées.</p> : null}{query.error ? <p className="error">{query.error}</p> : null}
      {assessment.is_published ? <p className="error">Cette évaluation est publiée : les notes sont verrouillées.</p> : null}
      {assessment.academic_periods?.is_closed ? <p className="error">La période est clôturée : aucune modification n'est autorisée.</p> : null}
      <section className="card">
        <form action={saveAssessmentGradesFromForm}>
          <input type="hidden" name="assessmentId" value={id} />
          <div className="table-wrap"><table><thead><tr><th>N°</th><th>Élève</th><th>Note / {assessment.max_score}</th><th>Observation</th></tr></thead><tbody>
          {(students ?? []).map((row: any) => { const s=row.students; const g=gradeMap.get(row.student_id); return <tr key={row.student_id}><td>{s?.student_number ?? '—'}</td><td>{s?.last_name} {s?.first_name}</td><td><input className="input" type="number" step="0.01" min="0" max={assessment.max_score} name={`score_${row.student_id}`} defaultValue={g?.score ?? ''} disabled={assessment.is_published || assessment.academic_periods?.is_closed} /></td><td><input className="input" name={`observation_${row.student_id}`} defaultValue={g?.observation ?? ''} disabled={assessment.is_published || assessment.academic_periods?.is_closed} /></td></tr> })}
          </tbody></table></div>
          {!students?.length ? <p className="empty">Aucun élève inscrit dans cette classe pour cette année.</p> : <div style={{marginTop:16,display:'flex',gap:10,flexWrap:'wrap'}}><button className="button button-primary" type="submit" disabled={assessment.is_published || assessment.academic_periods?.is_closed}>Enregistrer les notes</button><Link className="button button-secondary" href="/pedagogie/evaluations">Retour aux évaluations</Link></div>}
        </form>
      </section>
    </main>
  )
}
