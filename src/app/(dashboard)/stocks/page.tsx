import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

const money = (n: unknown) => `${Number(n ?? 0).toLocaleString('fr-FR')} FCFA`

export default async function StocksPage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const [{ count: products }, { count: locations }, { count: lowStock }, { count: openOrders }, { data: movements }, { data: orders }] = await Promise.all([
    supabase.from('products').select('id', { count: 'exact', head: true }).eq('school_id', schoolId).eq('is_active', true),
    supabase.from('stock_locations').select('id', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('stock_low_stock_v').select('product_id', { count: 'exact', head: true }),
    supabase.from('purchase_orders').select('id', { count: 'exact', head: true }).eq('school_id', schoolId).in('status', ['draft','submitted','approved']),
    supabase.from('stock_movements').select('id,product_id,location_id,movement_type,quantity,movement_date,notes').eq('school_id', schoolId).order('movement_date', { ascending: false }).limit(8),
    supabase.from('purchase_order_status_v').select('*').eq('school_id', schoolId).order('order_date', { ascending: false }).limit(8),
  ])
  return <main className="page">
    <div className="page-header"><div><p className="page-subtitle">Étape 19 • Stocks / Achats</p><h1 className="page-title">Stocks & achats</h1><p className="page-subtitle">Maîtrise des articles, niveaux de stock, inventaires, fournisseurs et cycle d’achat.</p></div><div style={{display:'flex',gap:8,flexWrap:'wrap'}}><Link className="button button-primary" href="/stocks/produits">Gérer les produits</Link><Link className="button button-secondary" href="/stocks/commandes">Nouvelle commande</Link></div></div>
    <section className="grid grid-4" style={{marginBottom:16}}>
      <article className="card"><div className="stat-label">Produits actifs</div><div className="stat-value">{products ?? 0}</div></article>
      <article className="card"><div className="stat-label">Emplacements</div><div className="stat-value">{locations ?? 0}</div></article>
      <article className="card"><div className="stat-label">Sous le minimum</div><div className="stat-value">{lowStock ?? 0}</div><p className="page-subtitle"><Link href="/stocks/produits">Voir les alertes →</Link></p></article>
      <article className="card"><div className="stat-label">Achats ouverts</div><div className="stat-value">{openOrders ?? 0}</div></article>
    </section>
    <section className="grid grid-4" style={{marginBottom:16}}>
      <Link className="card" href="/stocks/produits"><strong>Produits & emplacements</strong><p className="page-subtitle">Articles, catégories, seuils et magasins.</p></Link>
      <Link className="card" href="/stocks/demandes"><strong>Demandes d’achat</strong><p className="page-subtitle">Besoins, soumission et validation.</p></Link>
      <Link className="card" href="/stocks/commandes"><strong>Commandes</strong><p className="page-subtitle">Fournisseurs, lignes, validation et suivi.</p></Link>
      <Link className="card" href="/stocks/receptions"><strong>Réceptions</strong><p className="page-subtitle">Entrées stock et contrôle des quantités.</p></Link>
      <Link className="card" href="/stocks/inventaires"><strong>Inventaires</strong><p className="page-subtitle">Comptage, écarts et ajustements.</p></Link>
      <Link className="card" href="/stocks/mouvements"><strong>Mouvements</strong><p className="page-subtitle">Entrées, sorties, pertes et ajustements.</p></Link>
      <Link className="card" href="/stocks/transferts"><strong>Transferts</strong><p className="page-subtitle">Déplacements entre emplacements.</p></Link>
      <Link className="card" href="/stocks/factures"><strong>Factures fournisseurs</strong><p className="page-subtitle">Dettes, paiements et liaison caisse.</p></Link>
    </section>
    <section className="grid grid-2">
      <article className="card"><h2 style={{marginTop:0}}>Derniers mouvements</h2>{movements?.length ? <div className="table-wrap"><table><thead><tr><th>Type</th><th>Quantité</th><th>Date</th></tr></thead><tbody>{movements.map((m:any)=><tr key={m.id}><td>{m.movement_type}</td><td>{m.quantity}</td><td>{new Date(m.movement_date).toLocaleString('fr-FR')}</td></tr>)}</tbody></table></div> : <p className="empty">Aucun mouvement.</p>}</article>
      <article className="card"><h2 style={{marginTop:0}}>Commandes récentes</h2>{orders?.length ? <div className="table-wrap"><table><thead><tr><th>N°</th><th>Fournisseur</th><th>Statut</th><th>Total</th></tr></thead><tbody>{orders.map((o:any)=><tr key={o.id}><td>{o.order_number}</td><td>{o.supplier_name}</td><td>{o.status}</td><td>{money(o.total)}</td></tr>)}</tbody></table></div> : <p className="empty">Aucune commande.</p>}</article>
    </section>
  </main>
}
