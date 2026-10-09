import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'

export default async function RestaurationPage() {
  const supabase = await createClient()
  const claims = await supabase.auth.getClaims()
  const userId = claims.data?.claims?.sub
  const { data: profile } = userId ? await supabase.from('users').select('school_id').eq('id', userId).single() : { data: null }
  const schoolId = profile?.school_id
  const today = new Date().toISOString().slice(0,10)
  const { data: dashboard } = schoolId ? await supabase.rpc('get_catering_dashboard',{p_school_id:schoolId,p_date:today}) : {data:null}
  const {data: menus}=schoolId ? await supabase.from('menus').select('id,menu_date,status,notes').eq('school_id',schoolId).order('menu_date',{ascending:false}).limit(10) : {data:[]}
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Restauration</h1><p className="page-subtitle">Menus, service des repas, présences, consommations et coûts cuisine.</p></div><div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
      <Link className="button button-secondary" href="/restauration/types">Types de repas</Link><Link className="button button-primary" href="/restauration/menus">Menus</Link><Link className="button button-secondary" href="/restauration/services">Services</Link><Link className="button button-secondary" href="/restauration/presences">Présences</Link><Link className="button button-secondary" href="/restauration/consommations">Stock cuisine</Link>
    </div></div>
    <section className="grid grid-4">{[['Menus',dashboard?.menus??0],['Menus publiés',dashboard?.published_menus??0],['Repas servis',dashboard?.served_quantity??0],['Présences repas',dashboard?.meal_attendance??0]].map(([l,v])=><div className="card" key={l as string}><strong>{l}</strong><div style={{fontSize:30,marginTop:8}}>{v as any}</div></div>)}</section>
    <section className="grid grid-2" style={{marginTop:16}}><div className="card"><h2 style={{marginTop:0}}>Coûts du jour</h2><p>Service : <strong>{dashboard?.service_cost??0} FCFA</strong></p><p>Consommation stock : <strong>{dashboard?.stock_consumption_cost??0} FCFA</strong></p><p>Quantité servie : <strong>{dashboard?.served_quantity??0}</strong></p></div><div className="card"><h2 style={{marginTop:0}}>Workflow</h2><p>Menu → repas → service → présence → consommation stock → coût.</p><p className="page-subtitle" style={{marginBottom:0}}>Les mouvements de stock cuisine passent par une RPC transactionnelle.</p></div></section>
    <section className="card" style={{marginTop:16}}><h2 style={{marginTop:0}}>Derniers menus</h2><div className="table-wrap"><table className="table"><thead><tr><th>Date</th><th>Statut</th><th>Notes</th></tr></thead><tbody>{(menus??[]).map((m:any)=><tr key={m.id}><td>{m.menu_date}</td><td><span className="badge">{m.status}</span></td><td>{m.notes??'—'}</td></tr>)}{(!menus||menus.length===0)&&<tr><td colSpan={3}><div className="empty">Aucun menu.</div></td></tr>}</tbody></table></div></section>
  </main>
}
