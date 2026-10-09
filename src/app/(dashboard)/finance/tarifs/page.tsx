import { createClient } from '@/lib/supabase/server'
import { createFeeType } from '../finance-actions'

export default async function TarifsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const { data: feeTypes } = await supabase.from('fee_types').select('id,code,name,category,description,is_active').order('name')
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Tarification</h1><p className="page-subtitle">Types de frais et référentiel financier.</p></div></div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.created ? <p className="success">Type de frais créé.</p> : null}
    <section className="grid grid-2" style={{marginBottom:16}}>
      <article className="card"><h2>Nouveau type de frais</h2><form action={createFeeType}>
        <div className="field"><label className="label">Code</label><input className="input" name="code" placeholder="SCOLARITE" required /></div>
        <div className="field"><label className="label">Nom</label><input className="input" name="name" placeholder="Frais de scolarité" required /></div>
        <div className="field"><label className="label">Catégorie</label><input className="input" name="category" placeholder="scolarite" required /></div>
        <div className="field"><label className="label">Description</label><textarea className="input" name="description" rows={3} /></div>
        <button className="button button-primary" type="submit">Créer</button>
      </form></article>
      <article className="card"><h2>Règles du référentiel</h2><ul><li>Les codes sont uniques par établissement.</li><li>Les montants et échéances sont rattachés à une année scolaire.</li><li>Le système conserve la séparation entre frais directs et factures.</li></ul></article>
    </section>
    <section className="card"><h2>Types de frais</h2>{feeTypes?.length ? <div className="table-wrap"><table><thead><tr><th>Code</th><th>Nom</th><th>Catégorie</th><th>Actif</th><th>Description</th></tr></thead><tbody>{feeTypes.map((f:any)=><tr key={f.id}><td>{f.code}</td><td>{f.name}</td><td>{f.category}</td><td><span className="badge">{f.is_active?'Actif':'Inactif'}</span></td><td>{f.description ?? '—'}</td></tr>)}</tbody></table></div> : <p className="empty">Aucun type de frais.</p>}</section>
  </main>
}
