import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'

export default async function AgrPage() {
  const supabase = await createClient()
  const [{ data: activities }, { data: performance }] = await Promise.all([
    supabase.from('economic_activities').select('id,code,name,status,responsible_employee_id,location,budget_amount').eq('activity_type','agr').eq('status','active').order('name'),
    supabase.rpc('get_economic_activities_dashboard'),
  ])
  return <main className="page"><div className="page-header"><div><p className="page-subtitle">Activités génératrices de revenus</p><h1 className="page-title">AGR</h1><p className="page-subtitle">Production, transformation, services, commercialisation et autres activités paramétrables.</p></div><Link className="button button-secondary" href="/activites">Tableau de bord</Link></div>
    <section className="grid grid-3" style={{marginBottom:16}}><article className="card"><div className="stat-label">AGR actives</div><div className="stat-value">{(performance as any)?.agr ?? 0}</div></article><article className="card"><div className="stat-label">Revenus globaux</div><div className="stat-value">{Number((performance as any)?.revenue ?? 0).toLocaleString('fr-FR')}</div></article><article className="card"><div className="stat-label">Résultat global</div><div className="stat-value">{Number((performance as any)?.result ?? 0).toLocaleString('fr-FR')}</div></article></section>
    <section className="card"><h2>Activités AGR</h2>{activities?.length?<div className="table-wrap"><table><thead><tr><th>Code</th><th>Activité</th><th>Lieu</th><th>Budget</th></tr></thead><tbody>{activities.map((a:any)=><tr key={a.id}><td>{a.code}</td><td>{a.name}</td><td>{a.location||'—'}</td><td>{Number(a.budget_amount||0).toLocaleString('fr-FR')}</td></tr>)}</tbody></table></div>:<p className="empty">Aucune AGR active.</p>}</section>
    <section className="card" style={{marginTop:16}}><h2>Règle de pilotage</h2><p>Le résultat affiché par activité est calculé à partir des ventes enregistrées moins les dépenses d'activité et, pour les campagnes agricoles, les dépenses agricoles associées. Les règles de coût de revient, prix de vente, marges et catégories comptables restent paramétrables.</p></section>
  </main>
}
