import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'

const money = (n: unknown) => `${Number(n ?? 0).toLocaleString('fr-FR')} FCFA`

export default async function FinancePage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const query = await searchParams
  const supabase = await createClient()
  const { data: dashboard, error } = await supabase.rpc('get_finance_dashboard', { p_school_id: null })
  const d = (dashboard as any) ?? {}
  return (
    <main className="page">
      <div className="page-header">
        <div><p className="page-subtitle">Étape 15 • Finance & comptabilité</p><h1 className="page-title">Pilotage financier</h1><p className="page-subtitle">Tarifs, créances, encaissements, dépenses, caisse et impayés.</p></div>
        <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
          <Link className="button button-primary" href="/finance/factures/nouvelle">Nouvelle facture</Link>
          <Link className="button button-secondary" href="/finance/paiements/nouveau">Enregistrer un paiement</Link>
        </div>
      </div>
      {error ? <p className="error">{error.message}</p> : null}
      {query.error ? <p className="error">{query.error}</p> : null}
      <section className="grid grid-4" style={{marginBottom:16}}>
        <article className="card"><div className="stat-label">Créances factures</div><div className="stat-value">{money(d.invoice_receivable)}</div></article>
        <article className="card"><div className="stat-label">Créances frais directs</div><div className="stat-value">{money(d.charge_receivable)}</div></article>
        <article className="card"><div className="stat-label">Encaissements du jour</div><div className="stat-value">{money(d.payments_today)}</div></article>
        <article className="card"><div className="stat-label">Dépenses du jour</div><div className="stat-value">{money(d.expenses_today)}</div></article>
      </section>
      <section className="grid grid-3" style={{marginBottom:16}}>
        <article className="card"><div className="stat-label">Factures impayées</div><div className="stat-value">{Number(d.unpaid_invoices ?? 0)}</div><p className="page-subtitle"><Link href="/finance/impayes">Voir les impayés →</Link></p></article>
        <article className="card"><div className="stat-label">Factures en retard</div><div className="stat-value">{Number(d.overdue_invoices ?? 0)}</div><p className="page-subtitle"><Link href="/finance/factures">Voir les factures →</Link></p></article>
        <article className="card"><div className="stat-label">Comptes de caisse actifs</div><div className="stat-value">{Array.isArray(d.cash_accounts) ? d.cash_accounts.length : 0}</div><p className="page-subtitle"><Link href="/finance/caisse">Ouvrir la caisse →</Link></p></article>
      </section>
      <section className="card" style={{marginBottom:16}}>
        <div className="page-header" style={{marginBottom:12}}><div><h2 style={{margin:0}}>Comptes financiers</h2><p className="page-subtitle">Soldes calculés à partir des mouvements enregistrés.</p></div><Link className="button button-secondary" href="/finance/caisse">Gérer la caisse</Link></div>
        {Array.isArray(d.cash_accounts) && d.cash_accounts.length ? <div className="table-wrap"><table><thead><tr><th>Compte</th><th>Type</th><th>Solde</th></tr></thead><tbody>{d.cash_accounts.map((a:any)=><tr key={a.id}><td>{a.name}</td><td>{a.account_type}</td><td>{money(a.balance)}</td></tr>)}</tbody></table></div> : <p className="empty">Aucun compte financier actif.</p>}
      </section>
      <section className="grid grid-4">
        <Link className="card" href="/finance/tarifs"><strong>Tarification</strong><p className="page-subtitle">Types de frais et grilles.</p></Link>
        <Link className="card" href="/finance/factures"><strong>Facturation</strong><p className="page-subtitle">Factures et échéances.</p></Link>
        <Link className="card" href="/finance/paiements"><strong>Paiements & reçus</strong><p className="page-subtitle">Encaissements et traçabilité.</p></Link>
        <Link className="card" href="/finance/depenses"><strong>Dépenses</strong><p className="page-subtitle">Dépenses, validation et caisse.</p></Link>
      </section>
    </main>
  )
}
