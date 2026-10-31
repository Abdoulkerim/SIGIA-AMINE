import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleTeacher, updateTeacher } from '../../teacher-actions'

export default async function TeacherDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string; created?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const { id } = await params
  const query = await searchParams
  const supabase = await createClient()

  const [{ data: teacher }, { data: assignments }] = await Promise.all([
    supabase.from('employees')
      .select('id, employee_number, first_name, last_name, gender, date_of_birth, place_of_birth, phone, email, address, qualification, hire_date, status, teacher_profiles(speciality, diploma, pedagogical_role, biography)')
      .eq('id', id)
      .eq('school_id', context.profile.school_id)
      .single(),
    supabase.from('teacher_assignments')
      .select('id, school_year_id, class_id, subject_id, weekly_hours, is_primary, school_years(name), classes(name, code), subjects(name, code)')
      .eq('teacher_id', id)
      .eq('school_id', context.profile.school_id)
      .order('school_year_id', { ascending: false }),
  ])

  if (!teacher) notFound()
  const profile = (teacher as any).teacher_profiles?.[0] ?? (teacher as any).teacher_profiles ?? {}

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">{teacher.last_name} {teacher.first_name}</h1>
          <p className="page-subtitle">N° {teacher.employee_number} • {teacher.status === 'active' ? 'Actif' : 'Inactif'}</p>
        </div>
        <div className="actions">
          <Link className="button button-secondary" href="/personnel/enseignants">Retour</Link>
          <Link className="button button-primary" href={`/pedagogie/affectations/nouveau?teacher=${teacher.id}`}>+ Affecter</Link>
          <a className="button button-secondary" href="#informations-enseignant">Modifier les informations</a>
        </div>
      </div>

      {query.created ? <p className="success">Enseignant créé.</p> : null}
      {query.updated ? <p className="success">Modification enregistrée.</p> : null}
      {query.error ? <p className="error">{query.error}</p> : null}

      <section className="card" id="informations-enseignant" style={{ marginBottom: 16 }}>
        <h2>Informations de l'enseignant</h2>
        <form action={updateTeacher} className="grid grid-2">
          <input type="hidden" name="id" value={teacher.id} />
          <div className="field"><label className="label" htmlFor="employeeNumber">N° employé *</label><input className="input" id="employeeNumber" name="employeeNumber" defaultValue={teacher.employee_number} required /></div>
          <div className="field"><label className="label" htmlFor="firstName">Prénom *</label><input className="input" id="firstName" name="firstName" defaultValue={teacher.first_name} required /></div>
          <div className="field"><label className="label" htmlFor="lastName">Nom *</label><input className="input" id="lastName" name="lastName" defaultValue={teacher.last_name} required /></div>
          <div className="field"><label className="label" htmlFor="gender">Genre</label>
            <select className="select" id="gender" name="gender" defaultValue={teacher.gender ?? ''}><option value="">Non renseigné</option><option value="male">Masculin</option><option value="female">Féminin</option><option value="other">Autre</option></select>
          </div>
          <div className="field"><label className="label" htmlFor="dateOfBirth">Date de naissance</label><input className="input" id="dateOfBirth" name="dateOfBirth" type="date" defaultValue={teacher.date_of_birth ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="hireDate">Date d'embauche</label><input className="input" id="hireDate" name="hireDate" type="date" defaultValue={teacher.hire_date ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="phone">Téléphone</label><input className="input" id="phone" name="phone" defaultValue={teacher.phone ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="email">Email</label><input className="input" id="email" name="email" type="email" defaultValue={teacher.email ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="placeOfBirth">Lieu de naissance</label><input className="input" id="placeOfBirth" name="placeOfBirth" defaultValue={teacher.place_of_birth ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="qualification">Qualification</label><input className="input" id="qualification" name="qualification" defaultValue={teacher.qualification ?? ''} /></div>
          <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="address">Adresse</label><input className="input" id="address" name="address" defaultValue={teacher.address ?? ''} /></div>

          <div className="field"><label className="label" htmlFor="speciality">Spécialité</label><input className="input" id="speciality" name="speciality" defaultValue={profile?.speciality ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="diploma">Diplôme</label><input className="input" id="diploma" name="diploma" defaultValue={profile?.diploma ?? ''} /></div>
          <div className="field"><label className="label" htmlFor="pedagogicalRole">Rôle pédagogique</label><input className="input" id="pedagogicalRole" name="pedagogicalRole" defaultValue={profile?.pedagogical_role ?? ''} /></div>
          <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="biography">Biographie / observations</label><textarea className="input" id="biography" name="biography" rows={4} defaultValue={profile?.biography ?? ''} /></div>
          <div><button className="button button-primary" type="submit">Enregistrer</button></div>
        </form>
        <div style={{ marginTop: 16 }}>
          <form action={toggleTeacher}>
            <input type="hidden" name="id" value={teacher.id} />
            <input type="hidden" name="active" value={String(teacher.status !== 'active')} />
            <button className="button button-secondary" type="submit">
              {teacher.status === 'active' ? 'Désactiver l’enseignant' : 'Réactiver l’enseignant'}
            </button>
          </form>
        </div>
      </section>

      <section className="card">
        <div className="page-header" style={{ marginBottom: 12 }}>
          <div>
            <h2>Affectations</h2>
            <p className="page-subtitle">Classe, matière et année scolaire.</p>
          </div>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Année</th><th>Classe</th><th>Matière</th><th>H/semaine</th><th>Principal</th></tr></thead>
            <tbody>
              {(assignments ?? []).map((a: any) => (
                <tr key={a.id}>
                  <td>{a.school_years?.name ?? '—'}</td>
                  <td>{a.classes?.name ?? '—'} {a.classes?.code ? `(${a.classes.code})` : ''}</td>
                  <td>{a.subjects?.name ?? '—'} {a.subjects?.code ? `(${a.subjects.code})` : ''}</td>
                  <td>{a.weekly_hours ?? '—'}</td>
                  <td>{a.is_primary ? 'Oui' : 'Non'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!assignments?.length ? <p className="empty">Aucune affectation pédagogique.</p> : null}
      </section>
    </main>
  )
}
