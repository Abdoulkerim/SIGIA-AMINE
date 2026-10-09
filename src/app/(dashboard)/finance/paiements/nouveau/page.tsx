import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { recordPayment } from '../../finance-actions'
export default async function NewPaymentPage({searchParams}:{searchParams:Promise<{error?:string}>}){const q=await searchParams;const s=await createClient();const[{data:students},{data:targets},{data:accounts},{data:parents}]=await Promise.all([
 s.from('students').select('id,student_number,first_name,last_name').eq('status','active').order('last_name').limit(500),
 s.from('invoices').select('id,invoice_number,student_id,total,status,due_date').in('status',['pending','partially_paid']).order('due_date').limit(500),
 s.from('cash_accounts').select('id,name,account_type').eq('is_active',true).order('name'),
 s.from('parents').select('id,first_name,last_name').order('last_name').limit(500),
]); const now=new Date().toISOString(); return <main className="page"><div className="page-header"><div><h1 className="page-title">Enregistrer un paiement</h1><p className="page-subtitle">Chaque paiement doit être affecté à une facture ou à un frais direct.</p></div><Link className="button button-secondary" href="/finance/paiements">Retour</Link></div>{q.error?<p className="error">{q.error}</p>:null}<form className="card" action={recordPayment}><div className="grid grid-2">
<div className="field"><label className="label">Élève</label><select className="select" name="studentId" required><option value="">Sélectionner</option>{students?.map((x:any)=><option key={x.id} value={x.id}>{x.student_number} • {x.first_name} {x.last_name}</option>)}</select></div>
<div className="field"><label className="label">Parent payeur</label><select className="select" name="parentId"><option value="">—</option>{parents?.map((x:any)=><option key={x.id} value={x.id}>{x.last_name} {x.first_name}</option>)}</select></div>
<div className="field"><label className="label">Cible</label><select className="select" name="targetId" required>{targets?.map((x:any)=><option key={x.id} value={x.id}>{x.invoice_number} • {Number(x.total).toLocaleString('fr-FR')} FCFA • {x.status}</option>)}</select><input type="hidden" name="targetType" value="invoice" /></div>
<div className="field"><label className="label">Montant (FCFA)</label><input className="input" type="number" step="0.01" min="0.01" name="amount" required /></div>
<div className="field"><label className="label">Date / heure</label><input className="input" type="datetime-local" name="paymentDate" defaultValue={now.slice(0,16)} required /></div>
<div className="field"><label className="label">Mode de paiement</label><select className="select" name="method" defaultValue="cash"><option value="cash">Espèces</option><option value="mobile_money">Mobile Money</option><option value="bank_transfer">Virement</option><option value="card">Carte</option><option value="cheque">Chèque</option><option value="other">Autre</option></select></div>
<div className="field"><label className="label">Compte d’encaissement</label><select className="select" name="cashAccountId"><option value="">—</option>{accounts?.map((x:any)=><option key={x.id} value={x.id}>{x.name} • {x.account_type}</option>)}</select></div>
<div className="field"><label className="label">Référence</label><input className="input" name="reference" placeholder="TXN / reçu / chèque…" /></div>
</div><div className="field"><label className="label">Notes</label><textarea className="input" rows={3} name="notes" /></div><button className="button button-primary" type="submit">Enregistrer et générer le reçu</button></form></main>}
