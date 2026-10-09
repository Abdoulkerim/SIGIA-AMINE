import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createAssessment } from '../../pedagogie-actions'

export default async function NewAssessmentPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const [{ data: years }, { data: periods }, { data: classes }, { data: subjects }, { data: teachers }, { data: types }] = await Promise.all([
    supabase.from('school_years').select('id,name,is_current').eq('school_id', schoolId).order('start_date',{ascending:false}),
    supabase.from('academic_periods').select('id,name,school_year_id,start_date,end_date,is_closed').in('school_year_id', (await supabase.from('school_years').select('id').eq('school_id', schoolId)).data?.map(x=>x.id) ?? []).order('sequence_no'),
    supabase.from('classes').select('id,name,code,school_year_id').eq('school_id', schoolId).eq('is_active',true).order('name'),
    supabase.from('subjects').select('id,name,code').eq('school_id', schoolId).eq('is_active',true).order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number').eq('school_id', schoolId).eq('status','active').order('last_name'),
    supabase.from('assessment_types').select('id,name').eq('school_id', schoolId).eq('is_active',true).order('name'),
  ])
  const currentYear = years?.find(y=>y.is_current) ?? years?.[0]
  const openPeriods = (periods ?? []).filter(p => !p.is_closed)
  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Nouvelle évaluation</h1><p className="page-subtitle">Le serveur vérifiera la cohérence année/période/classe/matière/enseignant.</p></div><Link className="button button-secondary" href="/pedagogie/evaluations">Retour</Link></div>
      {params.error ? <p className="error">{params.error}</p> : null}
      <section className="card">
        <form action={createAssessment}>
          <div className="grid grid-2">
            <Field label="Année scolaire"><select className="select" name="schoolYearId" defaultValue={currentYear?.id ?? ''} required>{(years ?? []).map(y=><option key={y.id} value={y.id}>{y.name}</option>)}</select></Field>
            <Field label="Période"><select className="select" name="periodId" required><option value="">Sélectionner</option>{openPeriods.map(p=><option key={p.id} value={p.id}>{p.name} ({p.start_date} → {p.end_date})</option>)}</select></Field>
            <Field label="Classe"><select className="select" name="classId" required><option value="">Sélectionner</option>{(classes ?? []).map(c=><option key={c.id} value={c.id}>{c.name} ({c.code})</option>)}</select></Field>
            <Field label="Matière"><select className="select" name="subjectId" required><option value="">Sélectionner</option>{(subjects ?? []).map(s=><option key={s.id} value={s.id}>{s.name} ({s.code})</option>)}</select></Field>
            <Field label="Enseignant"><select className="select" name="teacherId" required><option value="">Sélectionner</option>{(teachers ?? []).map(t=><option key={t.id} value={t.id}>{t.last_name} {t.first_name} ({t.employee_number})</option>)}</select></Field>
            <Field label="Type d’évaluation"><select className="select" name="assessmentTypeId"><option value="">Aucun type</option>{(types ?? []).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></Field>
            <Field label="Titre"><input className="input" name="title" placeholder="Ex. Devoir 1" required /></Field>
            <Field label="Date"><input className="input" type="date" name="date" required /></Field>
            <Field label="Barème maximum"><input className="input" type="number" step="0.01" min="0.01" name="maxScore" defaultValue="20" required /></Field>
          </div>
          <button className="button button-primary" type="submit">Créer l’évaluation</button>
        </form>
      </section>
    </main>
  )
}
function Field({ label, children }: { label: string; children: React.ReactNode }) { return <label className="field"><span className="label">{label}</span>{children}</label> }
