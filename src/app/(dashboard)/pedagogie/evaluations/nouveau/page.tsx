import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createAcademicPeriod, createAssessment } from '../../pedagogie-actions'
import { AssessmentFields } from './assessment-fields'

export default async function NewAssessmentPage({ searchParams }: { searchParams: Promise<{ error?: string; periodCreated?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const [{ data: years }, { data: periods }, { data: classes }, { data: subjects }, { data: teachers }, { data: types }, { data: linkedTeacher }, { data: roleAssignments }] = await Promise.all([
    supabase.from('school_years').select('id,name,is_current').eq('school_id', schoolId).order('start_date',{ascending:false}),
    supabase.from('academic_periods').select('id,name,school_year_id,start_date,end_date,is_closed').in('school_year_id', (await supabase.from('school_years').select('id').eq('school_id', schoolId)).data?.map(x=>x.id) ?? []).order('sequence_no'),
    supabase.from('classes').select('id,name,code,school_year_id').eq('school_id', schoolId).eq('is_active',true).order('name'),
    supabase.from('subjects').select('id,name,code').eq('school_id', schoolId).eq('is_active',true).order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number').eq('school_id', schoolId).eq('status','active').order('last_name'),
    supabase.from('assessment_types').select('id,name').eq('school_id', schoolId).eq('is_active',true).order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number,teacher_profiles!inner(employee_id)').eq('school_id', schoolId).eq('user_id', context.profile.id).eq('status','active').maybeSingle(),
    supabase.from('user_roles').select('school_id,roles(role_permissions(permissions(code)))').eq('user_id', context.profile.id).eq('is_active', true),
  ])
  const currentYear = years?.find(y=>y.is_current) ?? years?.[0]
  const teacherProfile = linkedTeacher ? { id: linkedTeacher.id, first_name: linkedTeacher.first_name, last_name: linkedTeacher.last_name, employee_number: linkedTeacher.employee_number } : null
  const { data: assignments } = teacherProfile
    ? await supabase.from('teacher_assignments').select('school_year_id,class_id,subject_id,teacher_id').eq('school_id', schoolId).eq('teacher_id', teacherProfile.id)
    : { data: [] }
  const canManagePeriods = context.roles.some(role => role.code === 'super_admin') || (roleAssignments ?? []).some((assignment: any) =>
    (assignment.school_id === null || assignment.school_id === schoolId)
    && (assignment.roles?.role_permissions ?? []).some((item: any) => ['settings.manage', 'assessments.manage'].includes(item.permissions?.code)),
  )
  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Nouvelle évaluation</h1><p className="page-subtitle">Le serveur vérifiera la cohérence année/période/classe/matière/enseignant.</p></div><Link className="button button-secondary" href="/pedagogie/evaluations">Retour</Link></div>
      {params.error ? <p className="error">{params.error}</p> : null}
      {params.periodCreated ? <p className="success">La période a été créée.</p> : null}
      <p className="field-hint">Le coefficient dépend du couple matière / classe. Configurez-le sur la fiche de la matière, dans « Rattacher la matière à une classe et une année », avant de créer l’évaluation. <Link href="/pedagogie/matieres">Ouvrir les matières</Link></p>
      <section className="card">
        <form action={createAssessment}>
          <div className="grid grid-2">
            <AssessmentFields years={years ?? []} periods={periods ?? []} classes={classes ?? []} subjects={subjects ?? []} teachers={teachers ?? []} assignments={assignments ?? []} initialYearId={currentYear?.id ?? ''} teacherProfile={teacherProfile} />
            <Field label="Type d’évaluation"><select className="select" name="assessmentTypeId"><option value="">Aucun type</option>{(types ?? []).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></Field>
            <Field label="Titre"><input className="input" name="title" placeholder="Ex. Devoir 1" required /></Field>
            <Field label="Date"><input className="input" type="date" name="date" required /></Field>
            <Field label="Barème maximum"><input className="input" type="number" step="0.01" min="0.01" name="maxScore" defaultValue="20" required /></Field>
          </div>
          <button className="button button-primary" type="submit">Créer l’évaluation</button>
        </form>
      </section>
      {canManagePeriods ? <section className="card" style={{ marginTop: 16 }}>
        <h2 style={{ marginTop: 0 }}>Créer une autre période</h2>
        <p className="page-subtitle">Ajoutez une période avec son nom, son code et ses dates pour l’année scolaire choisie.</p>
        <form action={createAcademicPeriod} className="grid grid-2">
          <label className="field"><span className="label">Année scolaire</span><select className="select" name="schoolYearId" defaultValue={currentYear?.id ?? ''} required>{(years ?? []).map(year => <option key={year.id} value={year.id}>{year.name}</option>)}</select></label>
          <label className="field"><span className="label">Nom de la période</span><input className="input" name="name" placeholder="Ex. Session de rattrapage" required maxLength={100} /></label>
          <label className="field"><span className="label">Code</span><input className="input" name="code" placeholder="Ex. RATTRAPAGE" required maxLength={30} /></label>
          <label className="field"><span className="label">Ordre d’affichage</span><input className="input" type="number" name="sequenceNo" min="1" step="1" placeholder="Attribué automatiquement" /></label>
          <label className="field"><span className="label">Début</span><input className="input" type="date" name="startDate" required /></label>
          <label className="field"><span className="label">Fin</span><input className="input" type="date" name="endDate" required /></label>
          <button className="button button-secondary" type="submit">Créer la période</button>
        </form>
      </section> : null}
    </main>
  )
}
function Field({ label, children }: { label: string; children: React.ReactNode }) { return <label className="field"><span className="label">{label}</span>{children}</label> }
