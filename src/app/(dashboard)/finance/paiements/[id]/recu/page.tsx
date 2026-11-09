import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { PrintButton } from '@/components/print-button'

const money = (n: unknown) => `${Number(n ?? 0).toLocaleString('fr-FR')} FCFA`
const methodLabels: Record<string, string> = { cash: 'Espèces', bank_transfer: 'Virement bancaire', mobile_money: 'Mobile Money', card: 'Carte', cheque: 'Chèque', other: 'Autre' }

export default async function StudentReceiptPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const [{ data: payment }, { data: receipt }, { data: allocations }] = await Promise.all([
    supabase.from('payments').select('id,school_id,payment_number,payment_date,amount,method,reference,students(first_name,last_name,student_number),parents(first_name,last_name)').eq('id', id).maybeSingle(),
    supabase.from('receipts').select('receipt_number,issued_at').eq('payment_id', id).maybeSingle(),
    supabase.from('payment_allocations').select('amount,invoices(invoice_number),student_charges(description,fee_types(name))').eq('payment_id', id),
  ])
  if (!payment) notFound()
  const { data: school } = await supabase.from('schools').select('name,address,phone,email').eq('id', payment.school_id).maybeSingle()
  const student = Array.isArray(payment.students) ? payment.students[0] : payment.students
  const parent = Array.isArray(payment.parents) ? payment.parents[0] : payment.parents
  return <main className="page print-surface">
    <div className="page-header no-print"><div><h1 className="page-title">Reçu de paiement</h1><p className="page-subtitle">Reçu de l’élève à imprimer ou enregistrer en PDF.</p></div><div className="actions"><Link className="button button-secondary" href="/finance/paiements">Retour aux paiements</Link><PrintButton label="Imprimer le reçu"/></div></div>
    <article className="card receipt-paper">
      <div className="receipt-heading"><div><h1>{school?.name ?? 'Établissement scolaire'}</h1><p>{school?.address ?? ''}{school?.phone ? ` · ${school.phone}` : ''}</p></div><div className="receipt-mark">REÇU</div></div>
      <hr/>
      <div className="grid grid-2 receipt-meta"><p><strong>N° de reçu :</strong> {receipt?.receipt_number ?? payment.payment_number}</p><p><strong>N° de paiement :</strong> {payment.payment_number}</p><p><strong>Date :</strong> {new Date(receipt?.issued_at ?? payment.payment_date).toLocaleString('fr-FR')}</p><p><strong>Mode :</strong> {methodLabels[payment.method] ?? payment.method}</p></div>
      <section><h2>Payé par</h2><p><strong>Élève :</strong> {student ? `${student.first_name} ${student.last_name}` : '—'} {student?.student_number ? `(${student.student_number})` : ''}</p><p><strong>Parent payeur :</strong> {parent ? `${parent.first_name} ${parent.last_name}` : '—'}</p></section>
      <section><h2>Détail du règlement</h2><div className="table-wrap"><table><thead><tr><th>Motif</th><th>Montant réglé</th></tr></thead><tbody>{allocations?.map((allocation: any, index: number) => {
        const invoice = Array.isArray(allocation.invoices) ? allocation.invoices[0] : allocation.invoices
        const charge = Array.isArray(allocation.student_charges) ? allocation.student_charges[0] : allocation.student_charges
        const fee = Array.isArray(charge?.fee_types) ? charge.fee_types[0] : charge?.fee_types
        return <tr key={index}><td>{invoice?.invoice_number ? `Facture ${invoice.invoice_number}` : fee?.name ?? charge?.description ?? 'Frais scolaire'}</td><td>{money(allocation.amount)}</td></tr>
      })}</tbody><tfoot><tr><th>Total reçu</th><th>{money(payment.amount)}</th></tr></tfoot></table></div></section>
      <p><strong>Référence :</strong> {payment.reference ?? '—'}</p>
      <div className="receipt-signatures"><span>Signature du caissier</span><span>Cachet de l’établissement</span></div>
      <p className="receipt-footer">Ce reçu atteste de l’encaissement du montant indiqué ci-dessus.</p>
    </article>
  </main>
}
