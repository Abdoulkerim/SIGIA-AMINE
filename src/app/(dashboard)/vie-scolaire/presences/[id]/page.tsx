import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { saveAttendanceRecords } from '../../vie-scolaire-actions'

const labels: Record<string, string> = { present: 'Présent', absent: 'Absent', late: 'Retard', excused: 'Excusé' }

export default async function AttendanceSessionPage({ params: paramsPromise, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; saved?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const { id } = await paramsPromise
  const params = await searchParams
  const supabase = await createClient()
  const { data: session } = await supabase.from('attendance_sessions').select('id,school_year_id,session_date,start_time,end_time,activity_type,notes,class_id,classes!attendance_sessions_class_id_fkey(name,code),subjects!attendance_sessions_subject_id_fkey(name,code),employees!attendance_sessions_employee_id_fkey(first_name,last_name)').eq('id', id).single().overrideTypes<{
    classes: { name: string; code: string } | null
    subjects: { name: string; code: string } | null
    employees: { first_name: string; last_name: string } | null
  }>()
  if (!session) notFound()
  const { data: enrollments, error } = await supabase.from('enrollments').select('student_id,students(id,student_number,first_name,last_name)').eq('class_id', session.class_id).eq('school_year_id', session.school_year_id).eq('status', 'enrolled').order('student_id')
  const { data: existing } = await supabase.from('attendance_records').select('student_id,status,arrival_time,departure_time,reason').eq('session_id', id)
  const byStudent = new Map((existing ?? []).map((r: any) => [r.student_id, r]))

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Appel — {session.classes?.name ?? 'Classe'}</h1><p className="page-subtitle">{session.session_date} • {session.activity_type} • {session.start_time ?? '—'} {session.end_time ? `→ ${session.end_time}` : ''}</p></div><Link className="button button-secondary" href="/vie-scolaire/presences">Retour</Link></div>
      {params.saved ? <p className="success">La saisie a été enregistrée.</p> : null}{params.error ? <p className="error">{params.error}</p> : null}{error ? <p className="error">{error.message}</p> : null}
      <section className="card" style={{ marginBottom: 16 }}><p><strong>Matière :</strong> {session.subjects?.name ?? 'Activité générale'}</p><p><strong>Responsable :</strong> {session.employees ? `${session.employees.last_name} ${session.employees.first_name}` : '—'}</p>{session.notes ? <p><strong>Notes :</strong> {session.notes}</p> : null}</section>
      <form action={saveAttendanceRecords}><input type="hidden" name="sessionId" value={id} /><section className="card"><div className="table-wrap"><table><thead><tr><th>Élève</th><th>Statut</th><th>Arrivée</th><th>Départ</th><th>Motif / remarque</th></tr></thead><tbody>
        {(enrollments ?? []).map((row: any) => { const s = row.students; const current = byStudent.get(row.student_id) as any; return <tr key={row.student_id}><td><strong>{s?.last_name} {s?.first_name}</strong><div style={{fontSize:12,color:'var(--muted)'}}>{s?.student_number}</div></td><td><select className="select" name={`status_${row.student_id}`} defaultValue={current?.status ?? 'present'}>{Object.entries(labels).map(([value,label]) => <option key={value} value={value}>{label}</option>)}</select></td><td><input className="input" type="time" name={`arrival_${row.student_id}`} defaultValue={current?.arrival_time ?? ''} /></td><td><input className="input" type="time" name={`departure_${row.student_id}`} defaultValue={current?.departure_time ?? ''} /></td><td><input className="input" name={`reason_${row.student_id}`} defaultValue={current?.reason ?? ''} placeholder="Optionnel" /></td></tr> })}
      </tbody></table></div>{!enrollments?.length ? <p className="empty">Aucun élève actuellement inscrit dans cette classe/année.</p> : null}<button className="button button-primary" type="submit" style={{ marginTop: 16 }}>Enregistrer l’appel</button></section></form>
    </main>
  )
}
