import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { recordPayrollPayment } from '../finance-actions'

const money = (value: unknown) => `${Number(value ?? 0).toLocaleString('fr-FR')} FCFA`

export default async function FinancePayrollPage({ searchParams }: { searchParams: Promise<Record<string,string|undefined>> }) {
  const query = await searchParams
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) return null
  const supabase = await createClient()
  const [{ data: periods }, { data: accounts }] = await Promise.all([
    supabase.from('payroll_periods').select('id,period_label,start_date,end_date,status,payroll_items(id,employee_id,base_salary,allowances,deductions,net_salary,payment_status,employees(employee_number,first_name,last_name))').eq('school_id', schoolId).in('status', ['approved','paid','closed']).order('start_date', { ascending: false }),
    supabase.from('cash_accounts').select('id,name,account_type').eq('school_id', schoolId).eq('is_active', true).order('name'),
  ])
  const today = new Date().toISOString().slice(0,10)
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Paiement des employés</h1><p className="page-subtitle">Réglez les bulletins validés et enregistrez chaque sortie sur un compte de caisse ou de banque.</p></div><Link className="button button-secondary" href="/finance">Retour à Finance</Link></div>
    {query.error && <p className="error">{query.error}</p>}{query.paid && <p className="success">Paiement enregistré.</p>}
    {!(accounts??[]).length && <p className="error">Créez d’abord un compte dans la section Caisse pour enregistrer un paiement.</p>}
    {(periods??[]).map((period:any)=><section className="card" style={{marginTop:16}} key={period.id}>
      <div className="page-header"><div><h2>{period.period_label}</h2><p className="page-subtitle">{period.start_date} au {period.end_date} · {period.status}</p></div></div>
      <div className="table-wrap"><table className="table"><thead><tr><th>Employé</th><th>Salaire net</th><th>État</th><th>Enregistrer le paiement</th></tr></thead><tbody>
        {(period.payroll_items??[]).map((item:any)=><tr key={item.id}><td>{item.employees?.employee_number} — {item.employees?.first_name} {item.employees?.last_name}</td><td>{money(item.net_salary)}</td><td>{item.payment_status==='paid'?'Payé':'À payer'}</td><td>{item.payment_status==='paid'?'Paiement enregistré':period.status==='approved'?<form action={recordPayrollPayment} className="grid grid-4"><input type="hidden" name="payrollItemId" value={item.id}/><div className="field"><label className="label">Date</label><input className="input" type="date" name="paymentDate" defaultValue={today} required/></div><div className="field"><label className="label">Mode de paiement</label><select className="select" name="method" required><option value="bank_transfer">Virement</option><option value="cash">Espèces</option><option value="mobile_money">Mobile Money</option><option value="cheque">Chèque</option><option value="card">Carte</option><option value="other">Autre</option></select></div><div className="field"><label className="label">Compte débité</label><select className="select" name="cashAccountId" required defaultValue=""><option value="" disabled>Choisir un compte</option>{(accounts??[]).map((account:any)=><option key={account.id} value={account.id}>{account.name} · {account.account_type}</option>)}</select></div><div className="field"><label className="label">Référence</label><input className="input" name="reference" placeholder="N° de virement, reçu…"/></div><button className="button button-primary" disabled={!accounts?.length}>Payer {money(item.net_salary)}</button></form>:'Période clôturée'}</td></tr>)}
        {!(period.payroll_items??[]).length&&<tr><td colSpan={4}><div className="empty">Aucun bulletin dans cette période.</div></td></tr>}
      </tbody></table></div>
    </section>)}
    {!(periods??[]).length&&<div className="card empty">Aucune paie validée à payer. Préparez et validez les bulletins dans <Link href="/personnel/paie">Personnel → Paie</Link>.</div>}
  </main>
}
