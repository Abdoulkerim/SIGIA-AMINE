import { createClient } from '@/lib/supabase/server'

const money = (amount: number) => `${amount.toLocaleString('fr-FR')} FCFA`

export default async function UnpaidPage({ searchParams }: { searchParams: Promise<{ error?: string; reminded?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data: invoices }, { data: charges }] = await Promise.all([
    supabase
      .from('invoices')
      .select('id,invoice_number,student_id,due_date,total,status,students(first_name,last_name,student_number),payment_allocations(amount)')
      .in('status', ['pending', 'partially_paid'])
      .order('due_date'),
    supabase
      .from('student_charges')
      .select('id,student_id,fee_type_id,due_date,amount_due,status,students(first_name,last_name,student_number),fee_types(name),payment_allocations(amount)')
      .in('status', ['pending', 'partially_paid'])
      .order('due_date'),
  ])

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Impayés &amp; relances</h1>
          <p className="page-subtitle">Créances à recouvrer, échéances et historique des relances.</p>
        </div>
      </div>
      {q.error ? <p className="error">{q.error}</p> : null}
      {q.reminded ? <p className="success">Relance enregistrée.</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <h2>Factures impayées</h2>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Facture</th><th>Élève</th><th>Échéance</th><th>Reste à payer</th><th>Statut</th></tr></thead>
            <tbody>
              {invoices?.map((invoice: any) => {
                const paid = (invoice.payment_allocations ?? []).reduce(
                  (sum: number, allocation: { amount: number }) => sum + Number(allocation.amount ?? 0),
                  0,
                )
                const remaining = Math.max(0, Number(invoice.total ?? 0) - paid)

                return (
                  <tr key={invoice.id}>
                    <td>{invoice.invoice_number}</td>
                    <td>{invoice.students ? `${invoice.students.student_number} • ${invoice.students.first_name} ${invoice.students.last_name}` : '—'}</td>
                    <td>{invoice.due_date ?? '—'}</td>
                    <td>{money(remaining)}</td>
                    <td><span className="badge">{invoice.status}</span></td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        {!invoices?.length ? <p className="empty">Aucune facture impayée.</p> : null}
      </section>

      <section className="card">
        <h2>Reste à payer</h2>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Élève</th><th>Frais</th><th>Échéance</th><th>Reste à payer</th><th>Statut</th></tr></thead>
            <tbody>
              {charges?.map((charge: any) => {
                const paid = (charge.payment_allocations ?? []).reduce(
                  (sum: number, allocation: { amount: number }) => sum + Number(allocation.amount ?? 0),
                  0,
                )
                const remaining = Math.max(0, Number(charge.amount_due ?? 0) - paid)

                return (
                  <tr key={charge.id}>
                    <td>{charge.students ? `${charge.students.student_number} • ${charge.students.first_name} ${charge.students.last_name}` : '—'}</td>
                    <td>{charge.fee_types?.name ?? charge.fee_type_id}</td>
                    <td>{charge.due_date ?? '—'}</td>
                    <td>{money(remaining)}</td>
                    <td><span className="badge">{charge.status}</span></td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        {!charges?.length ? <p className="empty">Aucun reste à payer sur les frais directs.</p> : null}
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Principe de calcul</h2>
        <p>Le reste à payer correspond au montant dû diminué des paiements affectés : <strong>Montant dû − Montant payé = Reste à payer</strong>.</p>
      </section>
    </main>
  )
}
