import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'
import { updateTeacherAssignment } from '../../../../personnel/teacher-actions'
import TeacherAssignmentForm from '../../nouveau/teacher-assignment-form'

export default async function EditTeacherAssignmentPage({ params, searchParams }: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string }>
}) {
  const [{ id }, query, context] = await Promise.all([params, searchParams, getCurrentUserContext()])
  const schoolId = context?.profile.school_id
  if (!schoolId) return null
  const supabase = await createClient()
  const [{ data: assignment }, { data: years }, { data: teachers, error: teachersError }, { data: classes }, { data: subjects, error: subjectsError }, { data: eligibleAssignments, error: eligibleAssignmentsError }] = await Promise.all([
    supabase.from('teacher_assignments').select('id,school_year_id,teacher_id,class_id,subject_id,weekly_hours,is_primary').eq('id', id).eq('school_id', schoolId).maybeSingle(),
    supabase.from('school_years').select('id,name,is_current').eq('school_id', schoolId).order('start_date', { ascending: false }),
    supabase.from('employees').select('id,employee_number,first_name,last_name,teacher_profiles!inner(employee_id)').eq('school_id', schoolId).eq('status', 'active').order('last_name'),
    supabase.from('classes').select('id,name,code,school_year_id').eq('school_id', schoolId).eq('is_active', true).order('name'),
    fetchAllRows(() => supabase.from('subjects').select('id,name,code').eq('school_id', schoolId).eq('is_active', true).order('name').order('id')),
    fetchAllRows(() => supabase.from('subject_class_assignments').select('school_year_id,class_id,subject_id').eq('school_id', schoolId).eq('is_active', true).order('school_year_id').order('class_id').order('subject_id')),
  ])
  if (!assignment) notFound()

  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Modifier l’affectation</h1><p className="page-subtitle">Mettez à jour l’enseignant, la classe, la matière ou le volume horaire.</p></div><Link className="button button-secondary" href="/pedagogie/affectations">Retour</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}
    {subjectsError || eligibleAssignmentsError ? <p className="error">Impossible de charger toutes les matières rattachées. Actualisez la page ou vérifiez les droits d’accès.</p> : null}
    <section className="card">
      <TeacherAssignmentForm
        years={years ?? []}
        teachers={teachers ?? []}
        teachersError={Boolean(teachersError)}
        classes={classes ?? []}
        subjects={subjects ?? []}
        eligibleAssignments={eligibleAssignments ?? []}
        selectedTeacherId={assignment.teacher_id}
        initialAssignment={{
          id: assignment.id,
          schoolYearId: assignment.school_year_id,
          teacherId: assignment.teacher_id,
          classId: assignment.class_id,
          subjectId: assignment.subject_id,
          weeklyHours: assignment.weekly_hours,
          isPrimary: assignment.is_primary,
        }}
        action={updateTeacherAssignment}
      />
    </section>
  </main>
}
