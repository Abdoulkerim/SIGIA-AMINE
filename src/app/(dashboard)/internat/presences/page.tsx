import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { setBoardingAttendance } from '../boarding-actions'

export default async function PresencesPage({ searchParams }: { searchParams: Promise<Record<string,string|undefined>> }) {
  const sp=await searchParams
  const supabase=await createClient(); const claims=await supabase.auth.getClaims(); const userId=claims.data?.claims?.sub
  const { data: profile }=userId ? await supabase.from('users').select('school_id').eq('id',userId).single() : {data:null}
  const schoolId=profile?.school_id
  const [{data: assignments},{data: attendance}] = schoolId ? await Promise.all([
    supabase.from('boarding_assignments').select('student_id,students(student_number,first_name,last_name)').eq('school_id',schoolId).eq('status','active').order('start_date'),
    supabase.from('boarding_attendance').select('id,student_id,attendance_date,status,notes,students(student_number,first_name,last_name)').eq('school_id',schoolId).order('attendance_date',{ascending:false}).limit(200),
  ]) : [{data:[]},{data:[]}]
  const uniqueStudents=Array.from(new Map((assignments??[]).map((x:any)=>[x.student_id,x.students])).entries()).map(([id,s])=>({id,...(s as object)}))
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Présences internat</h1><p className="page-subtitle">Présence quotidienne des élèves disposant d’une affectation active.</p></div><Link className="button button-secondary" href="/internat">Retour</Link></div>
    {sp.error && <div className="error">{sp.error}</div>}{sp.saved && <div className="success">Présence enregistrée.</div>}
    <form className="card" action={setBoardingAttendance}><h2 style={{marginTop:0}}>Saisie</h2><div className="grid grid-4"><div className="field"><label className="label">Élève</label><select className="select" name="studentId" required>{uniqueStudents.map((s:any)=><option key={s.id} value={s.id}>{s.student_number} — {s.first_name} {s.last_name}</option>)}</select></div><div className="field"><label className="label">Date</label><input className="input" type="date" name="attendanceDate" required /></div><div className="field"><label className="label">Statut</label><select className="select" name="status" required><option value="present">Présent</option><option value="late">En retard</option><option value="absent">Absent</option><option value="excused">Excusé</option></select></div><div className="field"><label className="label">Note</label><input className="input" name="notes" /></div></div><button className="button button-primary">Enregistrer</button></form>
    <section className="card" style={{marginTop:16}}><h2 style={{marginTop:0}}>Historique récent</h2><div className="table-wrap"><table className="table"><thead><tr><th>Date</th><th>Élève</th><th>Statut</th><th>Note</th></tr></thead><tbody>{(attendance??[]).map((a:any)=><tr key={a.id}><td>{a.attendance_date}</td><td>{a.students?.student_number} — {a.students?.first_name} {a.students?.last_name}</td><td><span className="badge">{a.status}</span></td><td>{a.notes ?? '—'}</td></tr>)}{(attendance??[]).length===0&&<tr><td colSpan={4}><div className="empty">Aucune présence enregistrée.</div></td></tr>}</tbody></table></div></section>
  </main>
}
