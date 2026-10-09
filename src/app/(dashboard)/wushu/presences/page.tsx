import { createClient } from '@/lib/supabase/server'
import { recordWushuAttendance } from '../wushu-actions'

export default async function WushuAttendancePage({ searchParams }: { searchParams: Promise<{ error?: string; ok?: string }> }) {
  const q=await searchParams; const supabase=await createClient()
  const [{data:sessions},{data:profiles},{data:students}]=await Promise.all([
    supabase.from('wushu_sessions').select('id,group_id,session_date,session_type').order('session_date',{ascending:false}).limit(100),
    supabase.from('student_wushu').select('student_id,group_id,status').in('status',['active','completed']),
    supabase.from('students').select('id,first_name,last_name,student_number').eq('status','active').order('last_name').limit(300),
  ])
  const sessionChoices = sessions ?? []
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Présences Wushu</h1><p className="page-subtitle">Présence, absence, retard ou absence justifiée pour chaque séance.</p></div></div>
    {q.error?<p className="error">{q.error}</p>:null}{q.ok?<p className="success">Présence enregistrée.</p>:null}
    <section className="card"><h2>Saisir une présence</h2><form action={recordWushuAttendance} className="grid grid-3"><div className="field"><label className="label">Séance *</label><select className="select" name="sessionId" required><option value="">Choisir…</option>{sessionChoices.map(s=><option key={s.id} value={s.id}>{s.session_date} · {s.session_type}</option>)}</select></div><div className="field"><label className="label">Élève *</label><select className="select" name="studentId" required><option value="">Choisir…</option>{(students??[]).filter(s=>(profiles??[]).some(p=>p.student_id===s.id)).map(s=><option key={s.id} value={s.id}>{s.last_name} {s.first_name} · {s.student_number}</option>)}</select></div><div className="field"><label className="label">Statut *</label><select className="select" name="status"><option value="present">Présent</option><option value="absent">Absent</option><option value="late">Retard</option><option value="excused">Excusé</option></select></div><div><button className="button button-primary" type="submit">Enregistrer</button></div></form></section>
    <section className="card" style={{marginTop:16}}><h2>Conseil</h2><p>La saisie d'une présence est validée par le groupe de la séance et l'affectation Wushu de l'élève.</p></section>
  </main>
}
