import Link from 'next/link'
import { getDashboard } from '../dashboard-actions'

function n(v:unknown){return typeof v==='number'?v.toLocaleString('fr-FR'):'0'}
function money(v:unknown){return typeof v==='number'?v.toLocaleString('fr-FR',{maximumFractionDigits:2}):'0'}
export default async function ActivitiesDashboardPage(){
 const data=await getDashboard('activities'); const types=Array.isArray(data.by_type)?data.by_type:[]; const sales=Array.isArray(data.recent_sales)?data.recent_sales:[]
 return <main className="page"><div className="page-header"><div><h1 className="page-title">Tableau de bord des activités</h1><p className="page-subtitle">Agriculture, élevage et AGR.</p></div><Link href="/statistiques" className="button button-secondary">← Dashboards</Link></div>
 <section className="grid grid-4">{[['Activités',n(data.activities)],['Agriculture',n(data.agriculture)],['Élevage',n(data.livestock)],['AGR',n(data.agr)],['Productions',n(data.productions)],['Cheptel actif',n(data.livestock_units)],['Recettes',money(data.revenue)],['Résultat',money(data.result)]].map(([l,v])=><div className="card" key={l}><div className="stat-label">{l}</div><div className="stat-value">{v}</div></div>)}</section>
 <section className="grid grid-2" style={{marginTop:16}}><div><h2>Par type d’activité</h2><div className="table-wrap"><table><thead><tr><th>Type</th><th>Activités</th><th>Recettes</th><th>Dépenses</th></tr></thead><tbody>{types.map((r:any)=><tr key={r.activity_type}><td>{r.activity_type}</td><td>{n(r.activities)}</td><td>{money(r.revenue)}</td><td>{money(r.expenses)}</td></tr>)}</tbody></table></div></div><div><h2>Ventes récentes</h2><div className="table-wrap"><table><thead><tr><th>Date</th><th>Activité</th><th>Montant</th></tr></thead><tbody>{sales.map((r:any)=><tr key={`${r.sale_number}-${r.sale_date}`}><td>{String(r.sale_date).slice(0,10)}</td><td>{r.activity_name ?? '—'}</td><td>{money(r.amount)}</td></tr>)}</tbody></table></div></div></section>
 </main>
}
