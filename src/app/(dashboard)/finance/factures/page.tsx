import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { canManageFinance } from '@/lib/auth/finance-access'
import { loadFinanceDirectory } from '@/lib/finance/finance-directory'

const money = (n: unknown) => `${Number(n ?? 0).toLocaleString('fr-FR')} FCFA`
export default async function InvoicesPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data }, directory, canEdit] = await Promise.all([
    supabase.from('invoices').select('id,invoice_number,student_id,issue_date,due_date,total,status').order('issue_date', { ascending: false }).limit(100),
    loadFinanceDirectory(supabase),
    canManageFinance(),
  ])
  const students = new Map((directory.data?.students ?? []).map((student) => [student.id, student]))
  const invoices = (data ?? []).map((invoice) => ({ ...invoice, students: students.get(invoice.student_id) ?? null }))
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Factures</h1><p className="page-subtitle">Facturation des élèves et échéances.</p></div>{canEdit ? <Link className="button button-primary" href="/finance/factures/nouvelle">Nouvelle facture</Link> : null}</div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.created ? <p className="success">Facture enregistrée.</p> : null}
    {directory.error ? <p className="error">{directory.error}</p> : null}<section className="card"><div className="table-wrap"><table><thead><tr><th>Facture</th><th>Élève</th><th>Émission</th><th>Échéance</th><th>Total</th><th>Statut</th><th>Action</th></tr></thead><tbody>{invoices.map((i: any) => <tr key={i.id}><td>{i.invoice_number}</td><td>{i.students ? `${i.students.student_number} • ${i.students.first_name} ${i.students.last_name}` : '—'}</td><td>{i.issue_date}</td><td>{i.due_date ?? '—'}</td><td>{money(i.total)}</td><td><span className="badge">{i.status}</span></td><td>{canEdit ? <Link className="button button-secondary" href={`/finance/factures/${i.id}/modifier`}>Modifier</Link> : '—'}</td></tr>)}</tbody></table></div>{!invoices.length ? <p className="empty">Aucune facture visible.</p> : null}</section>
  </main>
}
