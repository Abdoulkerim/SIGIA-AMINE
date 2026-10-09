import Link from 'next/link'
import { getDashboard } from '../dashboard-actions'

function money(v:unknown){return typeof v==='number'?v.toLocaleString('fr-FR',{minimumFractionDigits:0,maximumFractionDigits:2}):'0'}
function n(v:unknown){return typeof v==='number'?v.toLocaleString('fr-FR'):'0'}
function obj(v:unknown){return(v&&typeof v==='object'?v:{}) as Record<string,any>}
export default async function FinanceDashboardPage(){
 const data=await getDashboard('finance'); const cash=Array.isArray(data.cash_accounts)?data.cash_accounts:[]; const monthly=Array.isArray(data.monthly)?data.monthly:[]; const cats=Array.isArray(data.expense_categories)?data.expense_categories:[]
 return <main className="page"><div className="page-header"><div><h1 className="page-title">Tableau de bord financier</h1><p className="page-subtitle">Recettes, dépenses, encaissements, impayés et soldes.</p></div><Link href="/statistiques" className="button button-secondary">← Dashboards</Link></div>
  <section className="grid grid-4">{[['Créance factures',money(data.invoice_receivable)],['Créance frais',money(data.charge_receivable)],['Paiements aujourd’hui',money(data.payments_today)],['Dépenses aujourd’hui',money(data.expenses_today)],['Factures impayées',n(data.unpaid_invoices)],['Factures en retard',n(data.overdue_invoices)],['Reçus 12 mois',n(data.receipts_12m)],['Comptes de caisse',n(cash.length)]].map(([l,v])=><div className="card" key={l}><div className="stat-label">{l}</div><div className="stat-value">{v}</div></div>)}</section>
  <section className="grid grid-2" style={{marginTop:16}}><div><h2>6 derniers mois</h2><div className="table-wrap"><table><thead><tr><th>Mois</th><th>Encaissements</th><th>Dépenses</th></tr></thead><tbody>{monthly.map((r:any)=><tr key={r.month}><td>{String(r.month).slice(0,7)}</td><td>{money(r.payments)}</td><td>{money(r.expenses)}</td></tr>)}</tbody></table></div></div>
  <div><h2>Répartition des dépenses — 12 mois</h2><div className="table-wrap"><table><thead><tr><th>Catégorie</th><th>Montant</th></tr></thead><tbody>{cats.map((r:any)=><tr key={r.name}><td>{r.name}</td><td>{money(r.amount)}</td></tr>)}</tbody></table></div></div></section>
  <section style={{marginTop:16}}><h2>Soldes des comptes</h2><div className="table-wrap"><table><thead><tr><th>Compte</th><th>Type</th><th>Solde</th></tr></thead><tbody>{cash.map((r:any)=><tr key={r.id}><td>{r.name}</td><td>{r.account_type}</td><td>{money(r.balance)}</td></tr>)}</tbody></table></div></section>
 </main>
}
