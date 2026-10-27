import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { ReportActions } from '@/components/reports/report-actions'

export default async function StudentsPage({ searchParams }: { searchParams: Promise<{ created?: string; classAssigned?: string; classId?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const params = await searchParams
  const supabase = await createClient()
  const [{ data: years }, { data: students, error }] = await Promise.all([supabase
    .from('school_years').select('id,name,is_current').eq('school_id', context.profile.school_id).order('start_date', { ascending: false }), supabase
    .from('students')
    .select('id, student_number, first_name, last_name, gender, date_of_birth, residence_type, status')
    .eq('school_id', context.profile.school_id)
    .order('last_name', { ascending: true })
    .order('first_name', { ascending: true })
    .limit(1000)])
  const currentYear = years?.find((year) => year.is_current) ?? years?.[0]
  const { data: classes } = currentYear ? await supabase.from('classes').select('id,name,code').eq('school_id', context.profile.school_id).eq('school_year_id', currentYear.id).order('name') : { data: [] }
  const { data: enrollments } = currentYear ? await supabase.from('enrollments').select('student_id,class_id,classes(name,code)').eq('school_id', context.profile.school_id).eq('school_year_id', currentYear.id).eq('status','enrolled') : { data: [] }
  const classByStudent = new Map((enrollments ?? []).map((row: any) => [row.student_id, row.classes?.name ?? '—']))
  const shownStudents = (students ?? []).filter((student) => !params.classId || (enrollments ?? []).some((row: any) => row.student_id === student.id && row.class_id === params.classId))

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Élèves</h1>
          <p className="page-subtitle">Dossier administratif numérique des élèves du Complexe Scolaire Al Amine.</p>
        </div>
        <Link className="button button-primary" href="/administration/eleves/nouveau">+ Nouvel élève</Link>
      </div>

      {params.created ? <p className="success">Élève enregistré avec succès.</p> : null}
      {params.classAssigned ? <p className="success">L’élève a aussi été inscrit dans la classe choisie.</p> : null}
      {error ? <p className="error">Erreur de lecture : {error.message}</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <form method="get" className="grid grid-3">
          <label className="field"><span className="label">Classe — {currentYear?.name ?? 'année actuelle'}</span><select className="select" name="classId" defaultValue={params.classId ?? ''}><option value="">Tous les élèves</option>{(classes ?? []).map((item: any) => <option key={item.id} value={item.id}>{item.name} ({item.code})</option>)}</select></label>
          <div className="field"><span className="label">Élèves affichés</span><span>{shownStudents.length}</span></div>
          <div className="field" style={{ alignSelf: 'end' }}><button className="button button-secondary" type="submit">Afficher</button></div>
        </form>
      </section>
      <ReportActions title={`Liste des élèves${params.classId ? ` — ${(classes ?? []).find((item: any) => item.id === params.classId)?.name ?? ''}` : ''}`} fileName="liste-eleves" headers={['Matricule', 'Nom', 'Prénom', 'Classe', 'Genre', 'Naissance', 'Régime', 'Statut']} rows={shownStudents.map((student) => [student.student_number, student.last_name, student.first_name, classByStudent.get(student.id) ?? 'Non inscrit', student.gender, student.date_of_birth, student.residence_type, student.status])} />

      {!shownStudents.length ? (
        <section className="card empty">
          <h2 style={{ marginTop: 0, color: 'var(--text)' }}>Aucun élève enregistré</h2>
          <p>Le seed officiel ne contient volontairement aucune donnée personnelle. Commence par créer le premier dossier.</p>
          <Link className="button button-primary" href="/administration/eleves/nouveau">Créer le premier dossier</Link>
        </section>
      ) : (
        <section className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Matricule</th>
                <th>Nom</th>
                <th>Prénom</th>
                <th>Classe</th>
                <th>Genre</th>
                <th>Naissance</th>
                <th>Régime</th>
                <th>Statut</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {shownStudents.map((student) => (
                <tr key={student.id}>
                  <td>{student.student_number}</td>
                  <td>{student.last_name}</td>
                  <td>{student.first_name}</td>
                  <td>{classByStudent.get(student.id) ?? '—'}</td>
                  <td>{student.gender ?? '—'}</td>
                  <td>{student.date_of_birth ?? '—'}</td>
                  <td>{student.residence_type}</td>
                  <td><span className="badge">{student.status}</span></td>
                  <td><Link className="button button-secondary" href={`/administration/eleves/${student.id}`}>Ouvrir</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </main>
  )
}
