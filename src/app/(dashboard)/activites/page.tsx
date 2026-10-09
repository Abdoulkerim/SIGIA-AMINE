import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { createActivity, recordProduction, recordExpense, recordSale } from './activites-actions'

export default async function ActivitiesPage() {
  const supabase = await createClient()
  const [{ data: stats }, { data: activities }, { data: employees }, { data: products }, { data: locations }] = await Promise.all([
    supabase.rpc('get_economic_activities_dashboard'),
    supabase.from('economic_activities').select('id,code,name,activity_type,status,responsible_employee_id,location,budget_amount').eq('status','active').order('name').limit(50),
    supabase.from('employees').select('id,first_name,last_name').order('last_name').limit(100),
    supabase.from('products').select('id,sku,name,unit').eq('is_active',true).order('name').limit(100),
    supabase.from('stock_locations').select('id,name').order('name').limit(100),
  ])
  const s = (stats as any) ?? {}
  return <main className="page">
    <div className="page-header"><div><p className="page-subtitle">Activités économiques de l'établissement</p><h1 className="page-title">Agriculture / Élevage / AGR</h1><p className="page-subtitle">Production, intrants, dépenses, stocks, ventes et résultats par activité.</p></div><div className="actions"><Link className="button button-secondary" href="/activites/agriculture">Agriculture</Link><Link className="button button-secondary" href="/activites/elevage">Élevage</Link><Link className="button button-secondary" href="/activites/agr">AGR</Link></div></div>
    <section className="grid grid-4" style={{marginBottom:16}}>
      <article className="card"><div className="stat-label">Activités actives</div><div className="stat-value">{s.activities ?? 0}</div></article>
      <article className="card"><div className="stat-label">Revenus</div><div className="stat-value">{Number(s.revenue ?? 0).toLocaleString('fr-FR')}</div></article>
      <article className="card"><div className="stat-label">Dépenses</div><div className="stat-value">{Number((s.expenses ?? 0)+(s.agri_expenses ?? 0)).toLocaleString('fr-FR')}</div></article>
      <article className="card"><div className="stat-label">Résultat</div><div className="stat-value">{Number(s.result ?? 0).toLocaleString('fr-FR')}</div></article>
    </section>
    <section className="grid grid-2">
      <article className="card"><h2>Nouvelle activité</h2><form action={createActivity} className="grid grid-2">
        <div className="field"><label className="label">Code</label><input className="input" name="code" required /></div>
        <div className="field"><label className="label">Nom</label><input className="input" name="name" required /></div>
        <div className="field"><label className="label">Type</label><select className="select" name="activityType"><option value="agriculture">Agriculture</option><option value="livestock">Élevage</option><option value="agr">AGR</option></select></div>
        <div className="field"><label className="label">Responsable</label><select className="select" name="responsibleEmployeeId"><option value="">—</option>{(employees ?? []).map((e:any)=><option key={e.id} value={e.id}>{e.last_name} {e.first_name}</option>)}</select></div>
        <div className="field"><label className="label">Lieu</label><input className="input" name="location" /></div>
        <div className="field"><label className="label">Budget</label><input className="input" type="number" step="0.01" min="0" name="budgetAmount" defaultValue="0" /></div>
        <div className="field" style={{gridColumn:'1/-1'}}><label className="label">Description</label><textarea className="input" name="description" rows={3} /></div>
        <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Créer</button></div>
      </form></article>
      <article className="card"><h2>Indicateurs</h2><p>Agriculture active : <strong>{s.agriculture ?? 0}</strong></p><p>Élevage actif : <strong>{s.livestock ?? 0}</strong></p><p>AGR active : <strong>{s.agr ?? 0}</strong></p><p>Campagnes : <strong>{s.campaigns ?? 0}</strong></p><p>Unités d'élevage : <strong>{Number(s.livestock_units ?? 0).toLocaleString('fr-FR')}</strong></p><p>Production enregistrée : <strong>{Number(s.productions ?? 0).toLocaleString('fr-FR')}</strong></p></article>
    </section>
    <section className="card" style={{marginTop:16}}><h2>Activités</h2>{activities?.length ? <div className="table-wrap"><table><thead><tr><th>Code</th><th>Activité</th><th>Type</th><th>Responsable</th><th>Lieu</th><th>Budget</th></tr></thead><tbody>{activities.map((a:any)=><tr key={a.id}><td>{a.code}</td><td>{a.name}</td><td>{a.activity_type}</td><td>{(employees ?? []).find((e:any)=>e.id===a.responsible_employee_id)?.last_name || '—'}</td><td>{a.location || '—'}</td><td>{Number(a.budget_amount||0).toLocaleString('fr-FR')}</td></tr>)}</tbody></table></div> : <p className="empty">Aucune activité active.</p>}</section>
    <section className="grid grid-2" style={{marginTop:16}}>
      <article className="card"><h2>Enregistrer une production</h2><form action={recordProduction} className="grid grid-2">
        <div className="field"><label className="label">Activité</label><select className="select" name="activityId" required><option value="">—</option>{(activities ?? []).map((a:any)=><option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
        <div className="field"><label className="label">Produit / production</label><input className="input" name="productName" required /></div>
        <div className="field"><label className="label">Quantité</label><input className="input" type="number" min="0" step="0.001" name="quantity" required /></div>
        <div className="field"><label className="label">Unité</label><input className="input" name="unit" required /></div>
        <div className="field"><label className="label">Produit stock (optionnel)</label><select className="select" name="productId"><option value="">Non stocké</option>{(products ?? []).map((p:any)=><option key={p.id} value={p.id}>{p.sku} — {p.name}</option>)}</select></div>
        <div className="field"><label className="label">Emplacement stock</label><select className="select" name="stockLocationId"><option value="">—</option>{(locations ?? []).map((l:any)=><option key={l.id} value={l.id}>{l.name}</option>)}</select></div>
        <div className="field"><label className="label">Date</label><input className="input" type="date" name="productionDate" required /></div>
        <div className="field"><label className="label">Coût unitaire</label><input className="input" type="number" step="0.01" min="0" name="unitCost" defaultValue="0" /></div>
        <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Enregistrer</button></div>
      </form></article>
      <article className="card"><h2>Enregistrer une dépense</h2><form action={recordExpense} className="grid grid-2">
        <div className="field"><label className="label">Activité</label><select className="select" name="activityId" required><option value="">—</option>{(activities ?? []).map((a:any)=><option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
        <div className="field"><label className="label">Catégorie</label><input className="input" name="category" required /></div>
        <div className="field"><label className="label">Montant</label><input className="input" type="number" min="0" step="0.01" name="amount" required /></div>
        <div className="field"><label className="label">Date</label><input className="input" type="date" name="expenseDate" required /></div>
        <div className="field" style={{gridColumn:'1/-1'}}><label className="label">Description</label><textarea className="input" name="description" rows={3} /></div>
        <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Enregistrer</button></div>
      </form></article>
    </section>
    <section className="card" style={{marginTop:16}}><h2>Enregistrer une vente</h2><form action={recordSale} className="grid grid-2">
      <div className="field"><label className="label">N° vente</label><input className="input" name="saleNumber" required /></div>
      <div className="field"><label className="label">Activité</label><select className="select" name="activityId"><option value="">—</option>{(activities ?? []).map((a:any)=><option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
      <div className="field"><label className="label">Date</label><input className="input" type="date" name="saleDate" required /></div>
      <div className="field"><label className="label">Client</label><input className="input" name="customerName" /></div>
      <div className="field"><label className="label">Produit stock (optionnel)</label><select className="select" name="productId"><option value="">Sans sortie stock</option>{(products ?? []).map((p:any)=><option key={p.id} value={p.id}>{p.sku} — {p.name}</option>)}</select></div>
      <div className="field"><label className="label">Emplacement</label><select className="select" name="stockLocationId"><option value="">—</option>{(locations ?? []).map((l:any)=><option key={l.id} value={l.id}>{l.name}</option>)}</select></div>
      <div className="field"><label className="label">Quantité</label><input className="input" type="number" min="0.001" step="0.001" name="quantity" required /></div>
      <div className="field"><label className="label">Unité</label><input className="input" name="unit" defaultValue="unit" required /></div>
      <div className="field"><label className="label">Prix unitaire</label><input className="input" type="number" min="0" step="0.01" name="unitPrice" required /></div>
      <div className="field"><label className="label">Mode de paiement</label><select className="select" name="paymentMethod"><option value="">—</option><option value="cash">Espèces</option><option value="mobile_money">Mobile Money</option><option value="bank_transfer">Virement</option><option value="card">Carte</option><option value="cheque">Chèque</option><option value="other">Autre</option></select></div>
      <div className="field" style={{gridColumn:'1/-1'}}><label className="label">Description</label><textarea className="input" name="description" rows={3} /></div>
      <div className="actions" style={{gridColumn:'1/-1'}}><button className="button button-primary">Enregistrer la vente</button></div>
    </form></section>
  </main>
}
