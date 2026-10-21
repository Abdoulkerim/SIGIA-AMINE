import { createClient } from '@/lib/supabase/server'
import { createWushuSession } from '../wushu-actions'

export default async function WushuSessionsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data: groups }, { data: coaches }, { data: sessions }] = await Promise.all([
    supabase.from('wushu_groups').select('id,name,level').eq('is_active',true).order('name'),
    supabase.from('employees').select('id,first_name,last_name').eq('status','active').order('last_name').limit(200),
    supabase.from('wushu_sessions').select('id,group_id,session_date,session_type,topic,coach_employee_id,is_published').order('session_date',{ascending:false}).limit(200),
  ])
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Entraînements Wushu</h1><p className="page-subtitle">Séances, thèmes techniques, préparation et progression.</p></div></div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.created ? <p className="success">Séance créée.</p> : null}
    <section className="card"><h2>Nouvelle séance</h2><p className="page-subtitle">La progression se met à jour automatiquement avec les présences et les évaluations des élèves.</p><form action={createWushuSession} className="grid grid-4"><div className="field"><label className="label">Groupe *</label><select className="select" name="groupId" required><option value="">Choisir…</option>{groups?.map(g=><option key={g.id} value={g.id}>{g.name}{g.level?` · ${g.level}`:''}</option>)}</select></div><div className="field"><label className="label">Date *</label><input className="input" type="date" name="sessionDate" required /></div><div className="field"><label className="label">Type *</label><select className="select" name="sessionType"><option value="training">Entraînement</option><option value="technique">Technique</option><option value="exam_preparation">Préparation examen</option><option value="competition_preparation">Préparation compétition</option><option value="other">Autre</option></select></div><div className="field"><label className="label">Coach</label><select className="select" name="coachEmployeeId"><option value="">—</option>{coaches?.map(c=><option key={c.id} value={c.id}>{c.last_name} {c.first_name}</option>)}</select></div><div className="field" style={{gridColumn:'span 2'}}><label className="label">Thème</label><input className="input" name="topic" /></div><div className="field" style={{gridColumn:'span 2'}}><label className="label">Notes</label><input className="input" name="notes" /></div><div><button className="button button-primary" type="submit">Créer la séance</button></div></form></section>
    <section className="card" style={{marginTop:16}}><h2>Historique</h2>{sessions?.length ? <div className="table-wrap"><table><thead><tr><th>Date</th><th>Groupe</th><th>Type</th><th>Thème</th><th>Statut</th></tr></thead><tbody>{sessions.map(s=><tr key={s.id}><td>{s.session_date}</td><td>{groups?.find(g=>g.id===s.group_id)?.name||'—'}</td><td>{s.session_type}</td><td>{s.topic||'—'}</td><td><span className="badge">{s.is_published?'Publié':'Brouillon'}</span></td></tr>)}</tbody></table></div>:<p className="empty">Aucune séance.</p>}</section>
  </main>
}
