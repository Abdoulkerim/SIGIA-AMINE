import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { assignBoarding, closeBoarding } from '../boarding-actions'

export default async function AffectationsPage({ searchParams }: { searchParams: Promise<Record<string,string|undefined>> }) {
  const sp = await searchParams
  const supabase = await createClient(); const claims = await supabase.auth.getClaims(); const userId=claims.data?.claims?.sub
  const { data: profile } = userId ? await supabase.from('users').select('school_id').eq('id',userId).single() : { data: null }
  const schoolId=profile?.school_id
  const [{ data: students }, { data: beds }, { data: assignments }] = schoolId ? await Promise.all([
    supabase.from('students').select('id,student_number,first_name,last_name,residence_type,status,gender').eq('school_id',schoolId).eq('status','active').eq('residence_type','internal').order('last_name'),
    supabase.from('boarding_beds').select('id,bed_number,status,boarding_rooms(name,boarding_dormitories(name,boarding_buildings(name,code)))').order('bed_number'),
    supabase.from('boarding_assignments').select('id,start_date,end_date,status,notes,student_id,bed_id,students(student_number,first_name,last_name),boarding_beds(bed_number,boarding_rooms(name,boarding_dormitories(name,boarding_buildings(name,code))))').eq('school_id',schoolId).order('start_date',{ascending:false}).limit(100),
  ]) : [{data:[]},{data:[]},{data:[]}]
  const availableBeds=(beds??[]).filter((b:any)=>b.status==='available')
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Affectations internat</h1><p className="page-subtitle">Un élève interne = une affectation active et un lit disponible.</p></div><Link className="button button-secondary" href="/internat">Retour</Link></div>
    {sp.error && <div className="error">{sp.error}</div>}{sp.created && <div className="success">Affectation créée.</div>}{sp.closed && <div className="success">Affectation clôturée.</div>}
    <form className="card" action={assignBoarding}>
      <h2 style={{ marginTop: 0 }}>Nouvelle affectation</h2>
      <div className="grid grid-4">
        <div className="field"><label className="label">Élève interne</label><select className="select" name="studentId" required>{(students??[]).map((s:any)=><option key={s.id} value={s.id}>{s.student_number} — {s.first_name} {s.last_name}</option>)}</select></div>
        <div className="field"><label className="label">Lit disponible</label><select className="select" name="bedId" required>{availableBeds.map((b:any)=><option key={b.id} value={b.id}>{b.bed_number} — {b.boarding_rooms?.name} / {b.boarding_rooms?.boarding_dormitories?.name}</option>)}</select></div>
        <div className="field"><label className="label">Date de début</label><input className="input" type="date" name="startDate" required /></div>
        <div className="field"><label className="label">Notes</label><input className="input" name="notes" /></div>
      </div>
      <button className="button button-primary">Affecter le lit</button>
    </form>
    <section className="card" style={{ marginTop: 16 }}><h2 style={{ marginTop: 0 }}>Historique</h2><div className="table-wrap"><table className="table"><thead><tr><th>Élève</th><th>Lit</th><th>Début</th><th>Fin</th><th>Statut</th><th>Action</th></tr></thead><tbody>{(assignments??[]).map((a:any)=><tr key={a.id}><td>{a.students?.student_number} — {a.students?.first_name} {a.students?.last_name}</td><td>{a.boarding_beds?.bed_number} — {a.boarding_beds?.boarding_rooms?.name}</td><td>{a.start_date}</td><td>{a.end_date ?? '—'}</td><td><span className="badge">{a.status}</span></td><td>{a.status==='active' ? <form action={closeBoarding} style={{ display:'flex', gap:6 }}><input type="hidden" name="assignmentId" value={a.id}/><input className="input" type="date" name="endDate" required/><button className="button button-secondary">Clôturer</button></form> : '—'}</td></tr>)}{(assignments??[]).length===0 && <tr><td colSpan={6}><div className="empty">Aucune affectation.</div></td></tr>}</tbody></table></div></section>
  </main>
}
