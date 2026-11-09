import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { updatePaymentDetails } from '../../../finance-actions'
import { canManageFinance } from '@/lib/auth/finance-access'

export default async function EditPaymentPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; updated?: string }> }) {
  const [{ id }, query, canEdit] = await Promise.all([params, searchParams, canManageFinance()])
  if (!canEdit) notFound()
  const supabase = await createClient()
  const { data: payment } = await supabase.from('payments').select('id,payment_number,payment_date,amount,method,reference,notes,students(first_name,last_name,student_number)').eq('id', id).maybeSingle()
  if (!payment) notFound()
  const student: any = Array.isArray(payment.students) ? payment.students[0] : payment.students
  const date = new Date(payment.payment_date)
  const dateValue = new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Modifier le paiement {payment.payment_number}</h1><p className="page-subtitle">{student ? `${student.student_number} · ${student.first_name} ${student.last_name}` : 'Élève'} · {Number(payment.amount).toLocaleString('fr-FR')} FCFA</p></div><Link className="button button-secondary" href="/finance/paiements">Retour</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}{query.updated ? <p className="success">Paiement modifié. Le reçu reprend ces informations.</p> : null}
    <p className="page-subtitle">Le montant et l’affectation comptable sont conservés afin de préserver le rapprochement avec la facture. Si la date est liée à une caisse clôturée, le système refusera le changement.</p>
    <form className="card" action={updatePaymentDetails}><input type="hidden" name="paymentId" value={payment.id}/><div className="grid grid-2">
      <label className="field"><span className="label">Date et heure</span><input className="input" type="datetime-local" name="paymentDate" defaultValue={dateValue} required/></label>
      <label className="field"><span className="label">Mode de paiement</span><select className="select" name="method" defaultValue={payment.method}><option value="cash">Espèces</option><option value="mobile_money">Mobile Money</option><option value="bank_transfer">Virement</option><option value="card">Carte</option><option value="cheque">Chèque</option><option value="other">Autre</option></select></label>
      <label className="field"><span className="label">Référence</span><input className="input" name="reference" defaultValue={payment.reference ?? ''} maxLength={120}/></label>
    </div><label className="field"><span className="label">Notes</span><textarea className="input" rows={3} name="notes" defaultValue={payment.notes ?? ''} maxLength={500}/></label><button className="button button-primary" type="submit">Enregistrer les corrections</button></form>
  </main>
}
