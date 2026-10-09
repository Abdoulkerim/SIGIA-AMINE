import { createClient } from '@/lib/supabase/server'
import { createCampaign, createSite } from '../activites-actions'

export default async function AgriculturePage() {
  const supabase = await createClient()
  const [{ data: activities }, { data: campaigns }, { data: sites }, { data: employees }] = await Promise.all([
    supabase.from('economic_activities').select('id,code,name,activity_type,status').in('activity_type',['agriculture','agr']).eq('status','active').order('name'),
    supabase.from('agriculture_campaigns').select('id,activity_id,crop,start_date,end_date,area,area_unit,expected_yield,actual_yield,notes').order('start_date',{ascending:false}).limit(80),
    supabase.from('economic_activity_sites').select('id,activity_id,code,name,site_type,location_description,area,area_unit,status').eq('status','active').order('name').limit(80),
    supabase.from('employees').select('id,first_name,last_name').order('last_name').limit(100),
  ])
  return <main className="page"><div className="page-header"><div><p className="page-subtitle">Production agricole</p><h1 className="page-title">Agriculture</h1><p className="page-subtitle">Campagnes, sites, intrants, productions et suivi des rendements.</p></div></div>
    <section className="grid grid-2"><article className="card"><h2>Nouvelle campagne</h2><form action={createCampaign} className="grid grid-2">
      <div className="field"><label className="label">Activité</label><select className="select" name="activityId" required><option value="">—</option>{(activities??[]).map((a:any)=><option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
      <div className="field"><label className="label">Culture</label><input className="input" name="crop" required /></div>
      <div className="field"><label className="label">Début</label><input className="input" type="date" name="startDate" /></div><div className="field"><label className="label">Fin</label><input className="input" type="date" name="endDate" /></div>
      <div className="field"><label className="label">Surface</label><input className="input" type="number" min="0" step="0.001" name="area" /></div><div className="field"><label className="label">Unité surface</label><input className="input" name="areaUnit" /></div>
      <div className="field"><label className="label">Rendement prévu</label><input className="input" type="number" min="0" step="0.001" name="expectedYield" /></div>
      <div className="field" style={{gridColumn:'1/-1'}}><label className="label">Observations</label><textarea className="input" name="notes" rows={3} /></div>
      <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Créer</button></div>
    </form></article>
    <article className="card"><h2>Nouveau site</h2><form action={createSite} className="grid grid-2">
      <div className="field"><label className="label">Activité</label><select className="select" name="activityId" required><option value="">—</option>{(activities??[]).map((a:any)=><option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
      <div className="field"><label className="label">Code</label><input className="input" name="code" required /></div><div className="field"><label className="label">Nom</label><input className="input" name="name" required /></div><div className="field"><label className="label">Type</label><input className="input" name="siteType" /></div>
      <div className="field"><label className="label">Surface</label><input className="input" type="number" min="0" step="0.001" name="area" /></div><div className="field"><label className="label">Unité</label><input className="input" name="areaUnit" /></div>
      <div className="field"><label className="label">Responsable</label><select className="select" name="responsibleEmployeeId"><option value="">—</option>{(employees??[]).map((e:any)=><option key={e.id} value={e.id}>{e.last_name} {e.first_name}</option>)}</select></div>
      <div className="field"><label className="label">Description du lieu</label><input className="input" name="locationDescription" /></div>
      <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Créer</button></div>
    </form></article></section>
    <section className="grid grid-2" style={{marginTop:16}}><article className="card"><h2>Campagnes</h2>{campaigns?.length?<div className="table-wrap"><table><thead><tr><th>Culture</th><th>Activité</th><th>Début</th><th>Surface</th><th>Prévu</th><th>Réel</th></tr></thead><tbody>{campaigns.map((c:any)=><tr key={c.id}><td>{c.crop}</td><td>{(activities??[]).find((a:any)=>a.id===c.activity_id)?.name||'—'}</td><td>{c.start_date||'—'}</td><td>{c.area??'—'} {c.area_unit||''}</td><td>{c.expected_yield??'—'}</td><td>{c.actual_yield??'—'}</td></tr>)}</tbody></table></div>:<p className="empty">Aucune campagne.</p>}</article><article className="card"><h2>Sites actifs</h2>{sites?.length?<div className="table-wrap"><table><thead><tr><th>Code</th><th>Site</th><th>Activité</th><th>Type</th><th>Surface</th></tr></thead><tbody>{sites.map((s:any)=><tr key={s.id}><td>{s.code}</td><td>{s.name}</td><td>{(activities??[]).find((a:any)=>a.id===s.activity_id)?.name||'—'}</td><td>{s.site_type||'—'}</td><td>{s.area??'—'} {s.area_unit||''}</td></tr>)}</tbody></table></div>:<p className="empty">Aucun site.</p>}</article></section>
  </main>
}
