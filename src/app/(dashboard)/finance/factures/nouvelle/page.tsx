import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { createInvoice } from '../../finance-actions'
export default async function NewInvoicePage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const q=await searchParams; const supabase=await createClient()
  const [{data:students},{data:parents},{data:fees}]=await Promise.all([
    supabase.from('students').select('id,student_number,first_name,last_name').eq('status','active').order('last_name').limit(500),
    supabase.from('parents').select('id,first_name,last_name,phone').order('last_name').limit(500),
    supabase.from('fee_types').select('id,code,name').eq('is_active',true).order('name'),
  ])
  const today=new Date().toISOString().slice(0,10)
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Nouvelle facture</h1><p className="page-subtitle">Une facture peut contenir plusieurs lignes ; ce formulaire crée une première ligne.</p></div><Link className="button button-secondary" href="/finance/factures">Retour</Link></div>{q.error?<p className="error">{q.error}</p>:null}
  <form className="card" action={createInvoice}><div className="grid grid-2">
    <div className="field"><label className="label">Élève</label><select className="select" name="studentId" required><option value="">Sélectionner</option>{students?.map((s:any)=><option key={s.id} value={s.id}>{s.student_number} • {s.first_name} {s.last_name}</option>)}</select></div>
    <div className="field"><label className="label">Parent payeur (facultatif)</label><select className="select" name="parentId"><option value="">—</option>{parents?.map((p:any)=><option key={p.id} value={p.id}>{p.last_name} {p.first_name} {p.phone?`• ${p.phone}`:''}</option>)}</select></div>
    <div className="field"><label className="label">Type de frais</label><select className="select" name="feeTypeId"><option value="">—</option>{fees?.map((f:any)=><option key={f.id} value={f.id}>{f.code} • {f.name}</option>)}</select></div>
    <div className="field"><label className="label">Date d’émission</label><input className="input" type="date" name="issueDate" defaultValue={today} required /></div>
    <div className="field"><label className="label">Date d’échéance</label><input className="input" type="date" name="dueDate" /></div>
    <div className="field"><label className="label">Quantité</label><input className="input" type="number" step="0.01" name="quantity" defaultValue="1" required /></div>
    <div className="field"><label className="label">Montant unitaire (FCFA)</label><input className="input" type="number" step="0.01" name="unitAmount" required /></div>
    <div className="field"><label className="label">Remise (FCFA)</label><input className="input" type="number" step="0.01" name="discount" defaultValue="0" /></div>
  </div><div className="field"><label className="label">Désignation</label><input className="input" name="description" placeholder="Scolarité — période 1" required /></div>
  <div className="field"><label className="label">Note</label><textarea className="input" name="notes" rows={3} /></div>
  <button className="button button-primary" type="submit">Créer la facture</button></form></main>
}
