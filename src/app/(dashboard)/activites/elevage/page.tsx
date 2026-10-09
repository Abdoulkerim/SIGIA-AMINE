import { createClient } from '@/lib/supabase/server'
import { createLivestock, recordLivestockEvent } from '../activites-actions'

export default async function ElevagePage() {
  const supabase = await createClient()
  const [{ data: activities }, { data: livestock }] = await Promise.all([
    supabase.from('economic_activities').select('id,code,name,activity_type,status').eq('activity_type','livestock').eq('status','active').order('name'),
    supabase.from('livestock').select('id,activity_id,animal_type,tag_number,breed,quantity,unit,sex,birth_date,acquisition_date,acquisition_cost,status,notes').eq('status','active').order('animal_type').limit(150),
  ])
  return <main className="page"><div className="page-header"><div><p className="page-subtitle">Cheptel et suivi de production</p><h1 className="page-title">Élevage</h1><p className="page-subtitle">Animaux, lots, événements, production et charges.</p></div></div>
    <section className="grid grid-2"><article className="card"><h2>Nouveau cheptel / lot</h2><form action={createLivestock} className="grid grid-2">
      <div className="field"><label className="label">Activité</label><select className="select" name="activityId" required><option value="">—</option>{(activities??[]).map((a:any)=><option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
      <div className="field"><label className="label">Type d'animal</label><input className="input" name="animalType" required /></div>
      <div className="field"><label className="label">Race</label><input className="input" name="breed" /></div><div className="field"><label className="label">N° / tag</label><input className="input" name="tagNumber" /></div>
      <div className="field"><label className="label">Quantité</label><input className="input" type="number" min="0.001" step="0.001" name="quantity" defaultValue="1" required /></div><div className="field"><label className="label">Unité</label><input className="input" name="unit" defaultValue="head" required /></div>
      <div className="field"><label className="label">Sexe</label><input className="input" name="sex" /></div><div className="field"><label className="label">Date naissance</label><input className="input" type="date" name="birthDate" /></div>
      <div className="field"><label className="label">Date acquisition</label><input className="input" type="date" name="acquisitionDate" /></div><div className="field"><label className="label">Coût acquisition</label><input className="input" type="number" min="0" step="0.01" name="acquisitionCost" defaultValue="0" /></div>
      <div className="field" style={{gridColumn:'1/-1'}}><label className="label">Notes</label><textarea className="input" name="notes" rows={3} /></div>
      <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Créer</button></div>
    </form></article>
    <article className="card"><h2>Nouvel événement</h2><form action={recordLivestockEvent} className="grid grid-2">
      <div className="field"><label className="label">Cheptel</label><select className="select" name="livestockId" required><option value="">—</option>{(livestock??[]).map((l:any)=><option key={l.id} value={l.id}>{l.animal_type}{l.breed ? ` — ${l.breed}`:''}{l.tag_number ? ` — ${l.tag_number}`:''}</option>)}</select></div>
      <div className="field"><label className="label">Type d'événement</label><input className="input" name="eventType" placeholder="production, naissance, soin, mortalité..." required /></div>
      <div className="field"><label className="label">Date</label><input className="input" type="date" name="eventDate" required /></div><div className="field"><label className="label">Quantité</label><input className="input" type="number" min="0" step="0.001" name="quantity" /></div>
      <div className="field"><label className="label">Montant</label><input className="input" type="number" min="0" step="0.01" name="amount" /></div>
      <div className="field" style={{gridColumn:'1/-1'}}><label className="label">Description</label><textarea className="input" name="description" rows={3} /></div>
      <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Enregistrer</button></div>
    </form></article></section>
    <section className="card" style={{marginTop:16}}><h2>Cheptel actif</h2>{livestock?.length?<div className="table-wrap"><table><thead><tr><th>Type</th><th>Race</th><th>Tag</th><th>Quantité</th><th>Sexe</th><th>Acquisition</th><th>Coût</th></tr></thead><tbody>{livestock.map((l:any)=><tr key={l.id}><td>{l.animal_type}</td><td>{l.breed||'—'}</td><td>{l.tag_number||'—'}</td><td>{l.quantity} {l.unit}</td><td>{l.sex||'—'}</td><td>{l.acquisition_date||'—'}</td><td>{Number(l.acquisition_cost||0).toLocaleString('fr-FR')}</td></tr>)}</tbody></table></div>:<p className="empty">Aucun cheptel actif.</p>}</section>
  </main>
}
