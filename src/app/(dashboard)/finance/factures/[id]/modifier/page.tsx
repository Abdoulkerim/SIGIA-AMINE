import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { updateInvoice } from '../../../finance-actions'
import { canManageFinance } from '@/lib/auth/finance-access'

export default async function EditInvoicePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; updated?: string }> }) {
  const [{ id }, query, canEdit] = await Promise.all([params, searchParams, canManageFinance()])
  if (!canEdit) notFound()
  const supabase = await createClient()
  const [{ data: invoice }, { data: items }, { data: allocations }, { data: fees }] = await Promise.all([
    supabase.from('invoices').select('id,invoice_number,issue_date,due_date,notes,total,status,students(first_name,last_name,student_number)').eq('id', id).maybeSingle(),
    supabase.from('invoice_items').select('id,fee_type_id,description,quantity,unit_amount,discount').eq('invoice_id', id).order('id'),
    supabase.from('payment_allocations').select('id').eq('invoice_id', id),
    supabase.from('fee_types').select('id,code,name').order('name'),
  ])
  if (!invoice) notFound()
  const student: any = Array.isArray(invoice.students) ? invoice.students[0] : invoice.students
  const hasPayments = Boolean(allocations?.length)
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Modifier la facture {invoice.invoice_number}</h1><p className="page-subtitle">{student ? `${student.student_number} · ${student.first_name} ${student.last_name}` : 'Élève non renseigné'} · Total actuel : {Number(invoice.total).toLocaleString('fr-FR')} FCFA</p></div><Link className="button button-secondary" href="/finance/factures">Retour</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}{query.updated ? <p className="success">Facture modifiée.</p> : null}
    {hasPayments ? <p className="page-subtitle">Un paiement est affecté à cette facture. Pour préserver la comptabilité, ses montants et lignes sont verrouillés ; les dates et notes restent modifiables.</p> : <p className="page-subtitle">Vous pouvez modifier les dates, la note et les lignes de cette facture.</p>}
    <form action={updateInvoice} className="card"><input type="hidden" name="invoiceId" value={invoice.id}/>
      <div className="grid grid-2"><label className="field"><span className="label">Date d’émission</span><input className="input" type="date" name="issueDate" defaultValue={invoice.issue_date} required/></label><label className="field"><span className="label">Date d’échéance</span><input className="input" type="date" name="dueDate" defaultValue={invoice.due_date ?? ''}/></label></div>
      {!hasPayments ? <section><h2>Lignes facturées</h2>{items?.map((item: any) => <div className="card" style={{ marginBottom: 12 }} key={item.id}><input type="hidden" name="itemId" value={item.id}/><input type="hidden" name="itemQuantity" value={item.quantity}/><div className="grid grid-2">
        <label className="field"><span className="label">Désignation</span><input className="input" name="itemDescription" defaultValue={item.description} required maxLength={300}/></label>
        <label className="field"><span className="label">Type de frais</span><select className="select" name="itemFeeTypeId" defaultValue={item.fee_type_id ?? ''}><option value="">Autre frais</option>{fees?.map((fee: any) => <option key={fee.id} value={fee.id}>{fee.code} · {fee.name}</option>)}</select></label>
        <label className="field"><span className="label">Prix unitaire (FCFA)</span><input className="input" type="number" min="0" step="0.01" name="itemUnitAmount" defaultValue={item.unit_amount} required/></label>
        <label className="field"><span className="label">Remise (FCFA)</span><input className="input" type="number" min="0" step="0.01" name="itemDiscount" defaultValue={item.discount} required/></label>
      </div></div>)}</section> : null}
      <label className="field"><span className="label">Note</span><textarea className="input" name="notes" rows={3} defaultValue={invoice.notes ?? ''} maxLength={500}/></label>
      <button className="button button-primary" type="submit">Enregistrer les corrections</button>
    </form>
  </main>
}
