import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { updateAssessment } from '../../../pedagogie-actions'

export default async function EditAssessmentPage({ params, searchParams }: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string }>
}) {
  const [{ id }, query, context] = await Promise.all([params, searchParams, getCurrentUserContext()])
  const schoolId = context?.profile.school_id
  if (!schoolId) return null
  const supabase = await createClient()
  const [{ data: assessment }, { data: years }, { data: classes }, { data: subjects }, { data: teachers }, { data: types }] = await Promise.all([
    supabase.from('assessments').select('id,school_year_id,period_id,class_id,subject_id,teacher_id,assessment_type_id,title,assessment_date,max_score,is_published,academic_periods(is_closed)').eq('id', id).eq('school_id', schoolId).maybeSingle(),
    supabase.from('school_years').select('id,name').eq('school_id', schoolId).order('start_date', { ascending: false }),
    supabase.from('classes').select('id,name,code,school_year_id,is_active').eq('school_id', schoolId).order('name'),
    supabase.from('subjects').select('id,name,code,is_active').eq('school_id', schoolId).order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number,status').eq('school_id', schoolId).order('last_name'),
    supabase.from('assessment_types').select('id,name,is_active').eq('school_id', schoolId).order('name'),
  ])
  const { data: periods } = await supabase.from('academic_periods').select('id,name,school_year_id,is_closed').in('school_year_id', (years ?? []).map(year => year.id)).order('sequence_no')
  if (!assessment) notFound()
  const locked = assessment.is_published || Boolean((assessment.academic_periods as { is_closed?: boolean } | null)?.is_closed)

  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Modifier l’évaluation</h1><p className="page-subtitle">Modifiez la date, la matière, la classe, l’enseignant, la période, le type ou le barème.</p></div><Link className="button button-secondary" href="/pedagogie/evaluations">Retour</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}
    {locked ? <p className="error">Cette évaluation ou sa période est verrouillée. Dépubliez l’évaluation ou rouvrez la période avant modification.</p> : null}
    <section className="card">
      <form action={updateAssessment} className="grid grid-2">
        <input type="hidden" name="id" value={assessment.id} />
        <label className="field"><span className="label">Année scolaire</span><select className="select" name="schoolYearId" defaultValue={assessment.school_year_id} required>{(years ?? []).map(year => <option key={year.id} value={year.id}>{year.name}</option>)}</select></label>
        <label className="field"><span className="label">Période</span><select className="select" name="periodId" defaultValue={assessment.period_id} required>{(periods ?? []).map(period => <option key={period.id} value={period.id}>{period.name}{period.is_closed ? ' · clôturée' : ''}</option>)}</select></label>
        <label className="field"><span className="label">Classe</span><select className="select" name="classId" defaultValue={assessment.class_id} required>{(classes ?? []).map(item => <option key={item.id} value={item.id}>{item.name} ({item.code}){!item.is_active ? ' · inactive' : ''}</option>)}</select></label>
        <label className="field"><span className="label">Matière</span><select className="select" name="subjectId" defaultValue={assessment.subject_id} required>{(subjects ?? []).map(item => <option key={item.id} value={item.id}>{item.name} ({item.code}){!item.is_active ? ' · inactive' : ''}</option>)}</select></label>
        <label className="field"><span className="label">Enseignant</span><select className="select" name="teacherId" defaultValue={assessment.teacher_id ?? ''} required><option value="">Sélectionner</option>{(teachers ?? []).map(item => <option key={item.id} value={item.id}>{item.last_name} {item.first_name} ({item.employee_number}){item.status !== 'active' ? ' · inactif' : ''}</option>)}</select></label>
        <label className="field"><span className="label">Type d’évaluation</span><select className="select" name="assessmentTypeId" defaultValue={assessment.assessment_type_id ?? ''}><option value="">Aucun type</option>{(types ?? []).map(item => <option key={item.id} value={item.id}>{item.name}{!item.is_active ? ' · inactif' : ''}</option>)}</select></label>
        <label className="field"><span className="label">Titre</span><input className="input" name="title" defaultValue={assessment.title} maxLength={200} required /></label>
        <label className="field"><span className="label">Date</span><input className="input" type="date" name="date" defaultValue={assessment.assessment_date} required /></label>
        <label className="field"><span className="label">Barème maximum</span><input className="input" type="number" name="maxScore" min="0.01" step="0.01" defaultValue={assessment.max_score} required /></label>
        <div><button className="button button-primary" type="submit" disabled={locked}>Enregistrer les modifications</button></div>
      </form>
    </section>
  </main>
}
