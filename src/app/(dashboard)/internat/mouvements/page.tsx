import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { recordBoardingMovement } from '../boarding-actions'

export default async function MouvementsPage({ searchParams }: { searchParams: Promise<Record<string,string|undefined>> }) {
  const sp=await searchParams
  const supabase=await createClient(); const claims=await supabase.auth.getClaims(); const userId=claims.data?.claims?.sub
  const { data: profile }=userId ? await supabase.from('users').select('school_id').eq('id',userId).single() : {data:null}
  const schoolId=profile?.school_id
  const [{data: students},{data: movements}] = schoolId ? await Promise.all([
    supabase.from('boarding_assignments').select('student_id,students(student_number,first_name,last_name)').eq('school_id',schoolId).eq('status','active').order('start_date',{ascending:false}),
    supabase.from('boarding_movements').select('id,movement_type,movement_at,authorization,destination,reason,students(student_number,first_name,last_name)').eq('school_id',schoolId).order('movement_at',{ascending:false}).limit(100),
  ]) : [{data:[]},{data:[]}]
  const uniqueStudents=Array.from(new Map((students??[]).map((x:any)=>[x.student_id,x.students])).entries()).map(([id,s])=>({id,...(s as object)}))
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Sorties et retours</h1><p className="page-subtitle">Entrées, sorties temporaires, retours et autorisations.</p></div><Link className="button button-secondary" href="/internat">Retour</Link></div>
    {sp.error && <div className="error">{sp.error}</div>}{sp.created && <div className="success">Mouvement enregistré.</div>}
    <form className="card" action={recordBoardingMovement}>
      <h2 style={{ marginTop:0 }}>Enregistrer un mouvement</h2>
      <div className="grid grid-4">
        <div className="field"><label className="label">Élève</label><select className="select" name="studentId" required>{uniqueStudents.map((s:any)=><option key={s.id} value={s.id}>{s.student_number} — {s.first_name} {s.last_name}</option>)}</select></div>
        <div className="field"><label className="label">Type</label><select className="select" name="movementType" required><option value="entry">Entrée</option><option value="temporary_leave">Sortie temporaire</option><option value="exit">Sortie</option><option value="return">Retour</option></select></div>
        <div className="field"><label className="label">Date / heure</label><input className="input" type="datetime-local" name="movementAt" required /></div>
        <div className="field"><label className="label">Autorisation</label><input className="input" name="authorization" /></div>
      </div>
      <div className="grid grid-2"><div className="field"><label className="label">Destination</label><input className="input" name="destination" /></div><div className="field"><label className="label">Motif</label><input className="input" name="reason" /></div></div>
      <div className="field"><label className="label">Notes</label><textarea className="input" name="notes" /></div>
      <button className="button button-primary">Enregistrer</button>
    </form>
    <section className="card" style={{marginTop:16}}><h2 style={{marginTop:0}}>Historique récent</h2><div className="table-wrap"><table className="table"><thead><tr><th>Date</th><th>Élève</th><th>Type</th><th>Autorisation</th><th>Destination</th><th>Motif</th></tr></thead><tbody>{(movements??[]).map((m:any)=><tr key={m.id}><td>{new Date(m.movement_at).toLocaleString('fr-FR')}</td><td>{m.students?.student_number} — {m.students?.first_name} {m.students?.last_name}</td><td><span className="badge">{m.movement_type}</span></td><td>{m.authorization ?? '—'}</td><td>{m.destination ?? '—'}</td><td>{m.reason ?? '—'}</td></tr>)}{(movements??[]).length===0&&<tr><td colSpan={6}><div className="empty">Aucun mouvement.</div></td></tr>}</tbody></table></div></section>
  </main>
}
