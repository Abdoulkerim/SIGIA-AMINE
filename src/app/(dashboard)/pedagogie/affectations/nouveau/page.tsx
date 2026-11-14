import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'
import { assignTeacher } from '../../../personnel/teacher-actions'
import TeacherAssignmentForm from './teacher-assignment-form'

export default async function NewAssignmentPage({
  searchParams,
}: {
  searchParams: Promise<{ teacher?: string; error?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const query = await searchParams
  const supabase = await createClient()

  const [{ data: years }, { data: teachers, error: teachersError }, { data: classes }, { data: subjects, error: subjectsError }, { data: eligibleAssignments, error: eligibleAssignmentsError }] = await Promise.all([
    supabase.from('school_years').select('id,name,is_current').eq('school_id', context.profile.school_id).order('start_date', { ascending: false }),
    supabase.from('employees').select('id,employee_number,first_name,last_name,teacher_profiles!inner(employee_id)').eq('school_id', context.profile.school_id).eq('status','active').order('last_name'),
    supabase.from('classes').select('id,name,code,school_year_id').eq('school_id', context.profile.school_id).eq('is_active',true).order('name'),
    fetchAllRows(() => supabase.from('subjects').select('id,name,code').eq('school_id', context.profile.school_id).eq('is_active',true).order('name').order('id')),
    fetchAllRows(() => supabase.from('subject_class_assignments').select('school_year_id,class_id,subject_id').eq('school_id', context.profile.school_id).eq('is_active', true).order('school_year_id').order('class_id').order('subject_id')),
  ])

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Nouvelle affectation</h1>
          <p className="page-subtitle">L'affectation sera vérifiée côté PostgreSQL avant l'enregistrement.</p>
        </div>
        <Link className="button button-secondary" href="/pedagogie/affectations">Retour</Link>
      </div>

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
          selectedTeacherId={query.teacher ?? ''}
          action={assignTeacher}
        />
      </section>
    </main>
  )
}
