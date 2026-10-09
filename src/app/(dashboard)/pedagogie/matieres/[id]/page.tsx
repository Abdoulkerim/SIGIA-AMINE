import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleSubjectClassAssignment, updateSubject } from '../../subjects-actions'
import SubjectClassAssignmentForm from './subject-class-assignment-form'

const domains = [
  ['general', 'Général'],
  ['arabe', 'Arabe'],
  ['islamique', 'Islamique'],
  ['tahfiz', 'Tahfiz'],
  ['eps', 'EPS'],
  ['wushu', 'Wushu'],
  ['autre', 'Autre'],
]

export default async function SubjectDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string; created?: string; assigned?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const { id } = await params
  const query = await searchParams
  const supabase = await createClient()

  const [{ data: subject, error }, { data: years }, { data: classes }, { data: assignments }] = await Promise.all([
    supabase.from('subjects').select('id, code, name, domain, coefficient, weekly_hours, description, is_active').eq('id', id).eq('school_id', context.profile.school_id).single(),
    supabase.from('school_years').select('id, name, is_current').eq('school_id', context.profile.school_id).order('start_date', { ascending: false }),
    supabase.from('classes').select('id, name, code, school_year_id').eq('school_id', context.profile.school_id).eq('is_active', true).order('name'),
    supabase.from('subject_class_assignments').select('id, school_year_id, class_id, coefficient_override, weekly_hours_override, is_required, is_active, school_years(name), classes(name,code)').eq('subject_id', id).eq('school_id', context.profile.school_id).order('is_active', { ascending: false }),
  ])

  if (error || !subject) notFound()

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">{subject.name}</h1>
          <p className="page-subtitle">{subject.code} • {subject.domain} • {subject.is_active ? 'Active' : 'Archivée'}</p>
        </div>
        <Link className="button button-secondary" href="/pedagogie/matieres">Retour aux matières</Link>
      </div>

      {query.created ? <p className="success">Matière créée.</p> : null}
      {query.assigned ? <p className="success">Matière rattachée à la classe.</p> : null}
      {query.updated ? <p className="success">Modification enregistrée.</p> : null}
      {query.error ? <p className="error">{query.error}</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <h2>Informations de la matière</h2>
        <form action={updateSubject} className="grid grid-2">
          <input type="hidden" name="id" value={subject.id} />
          <div className="field"><label className="label" htmlFor="code">Code *</label><input className="input" id="code" name="code" defaultValue={subject.code} required /></div>
          <div className="field"><label className="label" htmlFor="name">Nom *</label><input className="input" id="name" name="name" defaultValue={subject.name} required /></div>
          <div className="field"><label className="label" htmlFor="domain">Domaine *</label>
            <select className="select" id="domain" name="domain" defaultValue={subject.domain} required>
              {domains.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </div>
          <div className="field"><label className="label" htmlFor="coefficient">Coefficient *</label><input className="input" id="coefficient" name="coefficient" type="number" min="0.01" step="0.01" defaultValue={subject.coefficient} required /></div>
          <div className="field"><label className="label" htmlFor="weeklyHours">H/semaine</label><input className="input" id="weeklyHours" name="weeklyHours" type="number" min="0.01" step="0.25" defaultValue={subject.weekly_hours ?? ''} /></div>
          <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="description">Description</label><textarea className="input" id="description" name="description" rows={4} defaultValue={subject.description ?? ''} /></div>
          <div><button className="button button-primary" type="submit">Enregistrer</button></div>
        </form>
      </section>

      <section className="card" style={{ marginBottom: 16 }}>
        <h2>Rattacher la matière à une classe et une année</h2>
        <p>Les coefficients et volumes horaires peuvent être adaptés pour chaque classe.</p>
        <SubjectClassAssignmentForm
          subjectId={subject.id}
          coefficient={subject.coefficient}
          weeklyHours={subject.weekly_hours}
          years={years ?? []}
          classes={classes ?? []}
        />
      </section>

      <section className="card">
        <h2>Configurations actuelles</h2>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Année</th><th>Classe</th><th>Coef.</th><th>H/semaine</th><th>Obligatoire</th><th>Statut</th><th></th></tr></thead>
            <tbody>
              {(assignments ?? []).map((a: any) => (
                <tr key={a.id}>
                  <td>{a.school_years?.name ?? '—'}</td>
                  <td>{a.classes?.name ?? '—'} {a.classes?.code ? `(${a.classes.code})` : ''}</td>
                  <td>{a.coefficient_override ?? subject.coefficient}</td>
                  <td>{a.weekly_hours_override ?? subject.weekly_hours ?? '—'}</td>
                  <td>{a.is_required ? 'Oui' : 'Non'}</td>
                  <td><span className="badge">{a.is_active ? 'Active' : 'Inactive'}</span></td>
                  <td>
                    <form action={toggleSubjectClassAssignment}>
                      <input type="hidden" name="assignmentId" value={a.id} />
                      <input type="hidden" name="subjectId" value={subject.id} />
                      <input type="hidden" name="active" value={String(!a.is_active)} />
                      <button className="button button-secondary" type="submit">{a.is_active ? 'Désactiver' : 'Réactiver'}</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!assignments?.length ? <p className="empty">Aucune classe n’est encore rattachée à cette matière.</p> : null}
      </section>
    </main>
  )
}
