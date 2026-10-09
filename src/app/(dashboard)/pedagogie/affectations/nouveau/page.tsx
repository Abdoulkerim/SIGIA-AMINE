import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { assignTeacher } from '../../../personnel/teacher-actions'

export default async function NewAssignmentPage({
  searchParams,
}: {
  searchParams: Promise<{ teacher?: string; error?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const query = await searchParams
  const supabase = await createClient()

  const [{ data: years }, { data: teachers, error: teachersError }, { data: classes }, { data: subjects }] = await Promise.all([
    supabase.from('school_years').select('id,name,is_current').eq('school_id', context.profile.school_id).order('start_date', { ascending: false }),
    supabase.from('employees').select('id,employee_number,first_name,last_name,teacher_profiles!inner(employee_id)').eq('school_id', context.profile.school_id).eq('status','active').order('last_name'),
    supabase.from('classes').select('id,name,code,school_year_id').eq('school_id', context.profile.school_id).eq('is_active',true).order('name'),
    supabase.from('subjects').select('id,name,code').eq('school_id', context.profile.school_id).eq('is_active',true).order('name'),
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

      <section className="card">
        <form action={assignTeacher} className="grid grid-2">
          <div className="field">
            <label className="label" htmlFor="schoolYearId">Année scolaire *</label>
            <select className="select" id="schoolYearId" name="schoolYearId" required>
              {(years ?? []).map((year) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
            </select>
          </div>

          <div className="field">
            <label className="label" htmlFor="teacherId">Enseignant *</label>
            <select className="select" id="teacherId" name="teacherId" defaultValue={query.teacher ?? ''} required>
              <option value="" disabled>Choisir...</option>
              {(teachers ?? []).map((teacher) => <option key={teacher.id} value={teacher.id}>{teacher.last_name} {teacher.first_name} — {teacher.employee_number}</option>)}
            </select>
            {teachersError ? <p className="error">Impossible de charger les enseignants. Vérifie les droits d’accès et réessaie.</p> : null}
            {!teachersError && !teachers?.length ? <p className="field-hint">Aucun employé actif avec un profil enseignant n’est disponible.</p> : null}
          </div>

          <div className="field">
            <label className="label" htmlFor="classId">Classe *</label>
            <select className="select" id="classId" name="classId" required>
              <option value="" disabled>Choisir...</option>
              {(classes ?? []).map((item) => <option key={item.id} value={item.id}>{item.name} — {item.code}</option>)}
            </select>
          </div>

          <div className="field">
            <label className="label" htmlFor="subjectId">Matière *</label>
            <select className="select" id="subjectId" name="subjectId" required>
              <option value="" disabled>Choisir...</option>
              {(subjects ?? []).map((subject) => <option key={subject.id} value={subject.id}>{subject.name} — {subject.code}</option>)}
            </select>
          </div>

          <div className="field">
            <label className="label" htmlFor="weeklyHours">Volume hebdomadaire</label>
            <input className="input" id="weeklyHours" name="weeklyHours" type="number" min="0.25" step="0.25" />
          </div>

          <div className="field">
            <label className="label" htmlFor="isPrimary">Enseignant principal ?</label>
            <select className="select" id="isPrimary" name="isPrimary" defaultValue="false">
              <option value="false">Non</option>
              <option value="true">Oui</option>
            </select>
          </div>

          <div><button className="button button-primary" type="submit">Enregistrer l'affectation</button></div>
        </form>
      </section>
    </main>
  )
}
