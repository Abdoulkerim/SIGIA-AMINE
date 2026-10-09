import { createClient } from '@/lib/supabase/server'
import { createWushuGroup } from '../wushu-actions'

export default async function WushuGroupsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data: groups }, { data: coaches }] = await Promise.all([
    supabase.from('wushu_groups').select('id,code,name,level,coach_employee_id,is_active,created_at').order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number').eq('status','active').order('last_name').limit(200),
  ])
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Groupes Wushu</h1><p className="page-subtitle">Organisation des groupes, niveaux et responsables.</p></div></div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.created ? <p className="success">Groupe créé.</p> : null}
    <section className="card"><h2>Nouveau groupe</h2><form action={createWushuGroup} className="grid grid-4"><div className="field"><label className="label">Code</label><input className="input" name="code" /></div><div className="field"><label className="label">Nom *</label><input className="input" name="name" required /></div><div className="field"><label className="label">Niveau</label><input className="input" name="level" /></div><div className="field"><label className="label">Coach</label><select className="select" name="coachEmployeeId"><option value="">—</option>{coaches?.map(c => <option key={c.id} value={c.id}>{c.last_name} {c.first_name} · {c.employee_number}</option>)}</select></div><div><button className="button button-primary" type="submit">Créer</button></div></form></section>
    <section className="card" style={{marginTop:16}}><h2>Groupes enregistrés</h2>{groups?.length ? <div className="table-wrap"><table><thead><tr><th>Code</th><th>Nom</th><th>Niveau</th><th>Coach</th><th>Actif</th></tr></thead><tbody>{groups.map(g => <tr key={g.id}><td>{g.code || '—'}</td><td>{g.name}</td><td>{g.level || '—'}</td><td>{coaches?.find(c => c.id===g.coach_employee_id)?.last_name || '—'}</td><td><span className="badge">{g.is_active ? 'Actif' : 'Inactif'}</span></td></tr>)}</tbody></table></div> : <p className="empty">Aucun groupe.</p>}</section></main>
}
