import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { canManageFinance } from '@/lib/auth/finance-access'
import { loadFinanceDirectory } from '@/lib/finance/finance-directory'

const money = (n: unknown) => `${Number(n ?? 0).toLocaleString('fr-FR')} FCFA`
export default async function PaymentsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data }, summary, directory, canEdit] = await Promise.all([
    supabase.from('payments').select('id,payment_number,payment_date,amount,method,status,reference,student_id').order('payment_date', { ascending: false }).limit(100),
    supabase.rpc('get_payment_summary'),
    loadFinanceDirectory(supabase),
    canManageFinance(),
  ])
  const students = new Map((directory.data?.students ?? []).map((student) => [student.id, student]))
  const payments = (data ?? []).map((payment) => ({ ...payment, students: students.get(payment.student_id) ?? null }))
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Paiements & reçus</h1><p className="page-subtitle">Encaissements, références et reçus des élèves.</p></div>{canEdit ? <Link className="button button-primary" href="/finance/paiements/nouveau">Enregistrer un paiement</Link> : null}</div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.created ? <p className="success">Paiement enregistré et reçu généré.</p> : null}
    {directory.error ? <p className="error">{directory.error}</p> : null}
    {summary.error ? <p className="error">Impossible de charger le cumul des paiements : {summary.error.message}</p> : <section className="grid grid-2" style={{ marginBottom: 16 }}>
      <article className="card"><div className="stat-label">Cumul des paiements encaissés</div><div className="stat-value">{money(summary.data?.total_paid)}</div><p className="page-subtitle">Total des paiements au statut « payé » pour cet établissement.</p></article>
      <article className="card"><div className="stat-label">Encaissements du jour</div><div className="stat-value">{money(summary.data?.received_today)}</div><p className="page-subtitle">Paiements enregistrés aujourd’hui au statut « payé ».</p></article>
    </section>}
    <section className="card"><div className="table-wrap"><table><thead><tr><th>Paiement</th><th>Élève</th><th>Date</th><th>Montant</th><th>Mode</th><th>Référence</th><th>Statut</th><th>Actions</th></tr></thead><tbody>{payments.map((p: any) => <tr key={p.id}><td>{p.payment_number}</td><td>{p.students ? `${p.students.student_number} · ${p.students.first_name} ${p.students.last_name}` : '—'}</td><td>{new Date(p.payment_date).toLocaleString('fr-FR')}</td><td>{money(p.amount)}</td><td>{p.method}</td><td>{p.reference ?? '—'}</td><td><span className="badge">{p.status}</span></td><td><div className="actions"><Link className="button button-secondary" href={`/finance/paiements/${p.id}/recu`}>Imprimer le reçu</Link>{canEdit ? <Link className="button button-secondary" href={`/finance/paiements/${p.id}/modifier`}>Modifier</Link> : null}</div></td></tr>)}</tbody></table></div>{!payments.length ? <p className="empty">Aucun paiement visible.</p> : null}</section>
  </main>
}
