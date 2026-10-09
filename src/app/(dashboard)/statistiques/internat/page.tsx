import Link from 'next/link'
import { getDashboard } from '../dashboard-actions'

function n(v:unknown){return typeof v==='number'?v.toLocaleString('fr-FR'):'0'}
export default async function BoardingDashboardPage(){
 const data=await getDashboard('boarding'); const attendance=Array.isArray(data.attendance_7d)?data.attendance_7d:[]; const movements=Array.isArray(data.movements_30d)?data.movements_30d:[]; const dorms=Array.isArray(data.dormitories)?data.dormitories:[]
 return <main className="page"><div className="page-header"><div><h1 className="page-title">Tableau de bord internat</h1><p className="page-subtitle">Effectifs, occupation, présences et mouvements.</p></div><Link href="/statistiques" className="button button-secondary">← Dashboards</Link></div>
 <section className="grid grid-4">{[['Internes actifs',n(data.active_boarders)],['Lits',n(data.total_beds)],['Lits occupés',n(data.occupied_beds)],['Lits disponibles',n(data.available_beds)],['Occupation',`${n(data.occupancy_rate)} %`]].map(([l,v])=><div className="card" key={l}><div className="stat-label">{l}</div><div className="stat-value">{v}</div></div>)}</section>
 <section className="grid grid-2" style={{marginTop:16}}><div><h2>Présence — 7 jours</h2><div className="table-wrap"><table><thead><tr><th>Statut</th><th>Nombre</th></tr></thead><tbody>{attendance.map((r:any)=><tr key={r.status}><td>{r.status}</td><td>{n(r.count)}</td></tr>)}</tbody></table></div></div><div><h2>Mouvements — 30 jours</h2><div className="table-wrap"><table><thead><tr><th>Type</th><th>Nombre</th></tr></thead><tbody>{movements.map((r:any)=><tr key={r.movement_type}><td>{r.movement_type}</td><td>{n(r.count)}</td></tr>)}</tbody></table></div></div></section>
 <section style={{marginTop:16}}><h2>Occupation par dortoir</h2><div className="table-wrap"><table><thead><tr><th>Bâtiment</th><th>Dortoir</th><th>Lits</th><th>Occupés</th></tr></thead><tbody>{dorms.map((r:any)=><tr key={`${r.building_name}-${r.dormitory_name}`}><td>{r.building_name}</td><td>{r.dormitory_name}</td><td>{n(r.beds)}</td><td>{n(r.occupied)}</td></tr>)}</tbody></table></div></section>
 </main>
}
