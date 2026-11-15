import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'
import { loadFinanceDirectory } from '@/lib/finance/finance-directory'
import { recordPayment } from '../../finance-actions'
import { PaymentTargetFields } from './payment-target-fields'

export default async function NewPaymentPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const [query, context] = await Promise.all([searchParams, getCurrentUserContext()])
  const schoolId = context?.profile.school_id
  if (!schoolId) return null
  const supabase = await createClient()
  const [{ data: directory, error: directoryError }, { data: invoices, error: invoicesError }, { data: accounts }] = await Promise.all([
    loadFinanceDirectory(supabase),
    fetchAllRows<{ id: string; invoice_number: string; student_id: string; total: number | string; status: string; due_date: string | null }>(() => supabase.from('invoices').select('id,invoice_number,student_id,total,status,due_date').eq('school_id', schoolId).in('status', ['pending', 'partially_paid']).order('due_date').order('id')),
    supabase.from('cash_accounts').select('id,name,account_type').eq('school_id', schoolId).eq('is_active', true).order('name'),
  ])
  const students = directory?.students.filter((student) => student.status === 'active') ?? []
  const classes = directory?.classes ?? []
  const enrollments = directory?.enrollments ?? []
  const parents = directory?.parents ?? []
  const now = new Date().toISOString()

  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Enregistrer un paiement</h1><p className="page-subtitle">Chaque paiement doit être affecté à une facture ou à un frais direct.</p></div><Link className="button button-secondary" href="/finance/paiements">Retour</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}
    {directoryError || invoicesError ? <p className="error">{directoryError ?? 'Impossible de charger les factures à régler. Réessayez après actualisation.'}</p> : null}
    <form className="card payment-form" action={recordPayment}>
      <div className="grid grid-2">
        <PaymentTargetFields students={students ?? []} classes={classes ?? []} enrollments={enrollments ?? []} invoices={(invoices ?? []).map((invoice) => ({ ...invoice, total: Number(invoice.total) }))} />
        <div className="field"><label className="label" htmlFor="parentId">Parent payeur</label><select className="select" id="parentId" name="parentId"><option value="">—</option>{parents?.map((parent) => <option key={parent.id} value={parent.id}>{parent.last_name} {parent.first_name}</option>)}</select></div>
        <div className="field"><label className="label" htmlFor="amount">Montant (FCFA)</label><input className="input" id="amount" type="number" step="0.01" min="0.01" name="amount" required /></div>
        <div className="field"><label className="label" htmlFor="paymentDate">Date / heure</label><input className="input" id="paymentDate" type="datetime-local" name="paymentDate" defaultValue={now.slice(0, 16)} required /></div>
        <div className="field"><label className="label" htmlFor="method">Mode de paiement</label><select className="select" id="method" name="method" defaultValue="cash"><option value="cash">Espèces</option><option value="mobile_money">Mobile Money</option><option value="bank_transfer">Virement</option><option value="card">Carte</option><option value="cheque">Chèque</option><option value="other">Autre</option></select></div>
        <div className="field"><label className="label" htmlFor="cashAccountId">Compte d’encaissement</label><select className="select" id="cashAccountId" name="cashAccountId"><option value="">—</option>{accounts?.map((account) => <option key={account.id} value={account.id}>{account.name} • {account.account_type}</option>)}</select></div>
        <div className="field"><label className="label" htmlFor="reference">Référence</label><input className="input" id="reference" name="reference" placeholder="TXN / reçu / chèque…" /></div>
      </div>
      <div className="field"><label className="label" htmlFor="notes">Notes</label><textarea className="input" id="notes" rows={3} name="notes" /></div>
      <button className="button button-primary" type="submit">Enregistrer et générer le reçu</button>
    </form>
  </main>
}
