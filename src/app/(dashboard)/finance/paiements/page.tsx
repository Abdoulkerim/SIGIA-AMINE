import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { canManageFinance } from '@/lib/auth/finance-access'

const money = (n: unknown) => `${Number(n ?? 0).toLocaleString('fr-FR')} FCFA`
export default async function PaymentsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data }, canEdit] = await Promise.all([
    supabase.from('payments').select('id,payment_number,payment_date,amount,method,status,reference,students(first_name,last_name,student_number)').order('payment_date', { ascending: false }).limit(100),
    canManageFinance(),
  ])
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Paiements & reçus</h1><p className="page-subtitle">Encaissements, références et reçus des élèves.</p></div>{canEdit ? <Link className="button button-primary" href="/finance/paiements/nouveau">Enregistrer un paiement</Link> : null}</div>
    {q.error ? <p className="error">{q.error}</p> : null}{q.created ? <p className="success">Paiement enregistré et reçu généré.</p> : null}
    <section className="card"><div className="table-wrap"><table><thead><tr><th>Paiement</th><th>Élève</th><th>Date</th><th>Montant</th><th>Mode</th><th>Référence</th><th>Statut</th><th>Actions</th></tr></thead><tbody>{data?.map((p: any) => <tr key={p.id}><td>{p.payment_number}</td><td>{p.students ? `${p.students.student_number} · ${p.students.first_name} ${p.students.last_name}` : '—'}</td><td>{new Date(p.payment_date).toLocaleString('fr-FR')}</td><td>{money(p.amount)}</td><td>{p.method}</td><td>{p.reference ?? '—'}</td><td><span className="badge">{p.status}</span></td><td><div className="actions"><Link className="button button-secondary" href={`/finance/paiements/${p.id}/recu`}>Imprimer le reçu</Link>{canEdit ? <Link className="button button-secondary" href={`/finance/paiements/${p.id}/modifier`}>Modifier</Link> : null}</div></td></tr>)}</tbody></table></div>{!data?.length ? <p className="empty">Aucun paiement visible.</p> : null}</section>
  </main>
}
