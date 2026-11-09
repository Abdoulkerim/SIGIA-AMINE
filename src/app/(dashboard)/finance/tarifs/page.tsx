import { createClient } from '@/lib/supabase/server'
import { createFeeType, updateFeeType } from '../finance-actions'
import { canManageFinance } from '@/lib/auth/finance-access'

export default async function TarifsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string; updated?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data: feeTypes }, canEdit] = await Promise.all([
    supabase.from('fee_types').select('id,code,name,category,description,default_amount,is_active').order('name'),
    canManageFinance(),
  ])
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Tarification</h1><p className="page-subtitle">Types de frais et référentiel financier.</p></div></div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.created ? <p className="success">Type de frais créé.</p> : null}{q.updated ? <p className="success">Type de frais modifié.</p> : null}
    {canEdit ? <section className="grid grid-2" style={{ marginBottom: 16 }}>
      <article className="card"><h2>Nouveau type de frais</h2><form action={createFeeType}>
        <div className="field"><label className="label">Code</label><input className="input" name="code" placeholder="SCOLARITE" required /></div>
        <div className="field"><label className="label">Nom</label><input className="input" name="name" placeholder="Frais de scolarité" required /></div>
        <div className="field"><label className="label">Catégorie</label><input className="input" name="category" placeholder="scolarite" required /></div>
        <div className="field"><label className="label" htmlFor="price">Prix par défaut</label><input className="input" id="price" name="price" type="number" min="0" step="0.01" placeholder="50000" required /></div>
        <div className="field"><label className="label">Description</label><textarea className="input" name="description" rows={3} /></div>
        <button className="button button-primary" type="submit">Créer</button>
      </form></article>
      <article className="card"><h2>Règles du référentiel</h2><ul><li>Les codes sont uniques par établissement.</li><li>Les montants et échéances sont rattachés à une année scolaire.</li><li>La modification du prix par défaut ne modifie pas les factures déjà émises.</li></ul></article>
    </section> : null}
    <section className="card"><h2>Types de frais</h2>{feeTypes?.length ? <div className="table-wrap"><table><thead><tr><th>Code</th><th>Nom</th><th>Catégorie</th><th>Prix</th><th>Actif</th><th>Description</th><th>Modification</th></tr></thead><tbody>{feeTypes.map((f: any) => <tr key={f.id}>
      <td>{f.code}</td><td>{f.name}</td><td>{f.category}</td><td>{Number(f.default_amount).toLocaleString('fr-FR')} FCFA</td><td><span className="badge">{f.is_active ? 'Actif' : 'Inactif'}</span></td><td>{f.description ?? '—'}</td>
      <td>{canEdit ? <details><summary className="button button-secondary">Modifier</summary><form action={updateFeeType} className="grid" style={{ minWidth: 260, marginTop: 8 }}><input type="hidden" name="feeTypeId" value={f.id}/>
        <label className="field"><span className="label">Code</span><input className="input" name="code" defaultValue={f.code} required maxLength={40}/></label>
        <label className="field"><span className="label">Nom</span><input className="input" name="name" defaultValue={f.name} required maxLength={160}/></label>
        <label className="field"><span className="label">Catégorie</span><input className="input" name="category" defaultValue={f.category} required maxLength={80}/></label>
        <label className="field"><span className="label">Prix par défaut</span><input className="input" name="price" type="number" min="0" step="0.01" defaultValue={f.default_amount} required/></label>
        <label className="field"><span className="label">Description</span><textarea className="input" name="description" defaultValue={f.description ?? ''} maxLength={500}/></label>
        <label><input type="checkbox" name="isActive" defaultChecked={f.is_active}/> Type actif</label><button className="button button-primary" type="submit">Enregistrer</button>
      </form></details> : '—'}</td>
    </tr>)}</tbody></table></div> : <p className="empty">Aucun type de frais.</p>}</section>
  </main>
}
