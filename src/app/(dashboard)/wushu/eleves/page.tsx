import { createClient } from '@/lib/supabase/server'
import { assignStudentWushu } from '../wushu-actions'
import { ProgressBar } from '@/components/administration/progress-bar'

export default async function WushuStudentsPage({ searchParams }: { searchParams: Promise<{ error?: string; assigned?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data: students }, { data: groups }, { data: profiles }] = await Promise.all([
    supabase.from('students').select('id,student_number,first_name,last_name').eq('status','active').order('last_name').limit(300),
    supabase.from('wushu_groups').select('id,name,level').eq('is_active',true).order('name'),
    supabase.from('student_wushu').select('id,student_id,group_id,current_grade,current_progress,start_date,status,updated_at').order('updated_at',{ascending:false}).limit(500),
  ])
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Élèves Wushu</h1><p className="page-subtitle">Affectation, grade courant, statut et progression.</p></div></div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.assigned ? <p className="success">Profil Wushu enregistré.</p> : null}
    <section className="card"><h2>Affecter / mettre à jour</h2><p className="page-subtitle">La progression se calcule automatiquement à partir des évaluations et de la présence aux entraînements (70 % / 30 % si les deux sont renseignés).</p><form action={assignStudentWushu} className="grid grid-4"><div className="field"><label className="label">Élève *</label><select className="select" name="studentId" required><option value="">Choisir…</option>{students?.map(s => <option key={s.id} value={s.id}>{s.last_name} {s.first_name} · {s.student_number}</option>)}</select></div><div className="field"><label className="label">Groupe *</label><select className="select" name="groupId" required><option value="">Choisir…</option>{groups?.map(g => <option key={g.id} value={g.id}>{g.name}{g.level ? ` · ${g.level}` : ''}</option>)}</select></div><div className="field"><label className="label">Grade actuel</label><input className="input" name="currentGrade" placeholder="Paramétrable" /></div><div className="field"><label className="label">Début</label><input className="input" type="date" name="startDate" /></div><div className="field"><label className="label">Statut</label><select className="select" name="status"><option value="active">Actif</option><option value="paused">En pause</option><option value="completed">Terminé</option><option value="inactive">Inactif</option></select></div><div className="field" style={{gridColumn:'span 2'}}><label className="label">Notes</label><input className="input" name="notes" /></div><div><button className="button button-primary" type="submit">Enregistrer</button></div></form></section>
    <section className="card" style={{marginTop:16}}><h2>Profils Wushu</h2>{profiles?.length ? <div className="table-wrap"><table><thead><tr><th>Élève</th><th>Groupe</th><th>Grade</th><th>Progression</th><th>Statut</th></tr></thead><tbody>{profiles.map(p => { const s=students?.find(x=>x.id===p.student_id); const g=groups?.find(x=>x.id===p.group_id); return <tr key={p.id}><td>{s ? `${s.last_name} ${s.first_name}` : p.student_id}</td><td>{g?.name || '—'}</td><td>{p.current_grade || '—'}</td><td><ProgressBar value={p.current_progress} /></td><td><span className="badge">{p.status}</span></td></tr> })}</tbody></table></div> : <p className="empty">Aucun profil Wushu.</p>}</section>
  </main>
}
