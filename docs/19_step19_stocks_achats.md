# Étape 19 — Stocks / Achats

## Base fonctionnelle

Le cahier des charges Al Amine demande un module couvrant les **fournitures scolaires et administratives, denrées alimentaires, équipements et matériels, produits d’entretien, tenues et équipements sportifs, entrées/sorties/inventaires et seuils d’alerte**. Il demande aussi, pour les achats, les **fournisseurs, demandes et commandes, réception des produits, factures, paiements et historique des achats**.

## Architecture retenue

### Stock
- `stock_categories`
- `stock_locations`
- `products`
- `stock_balances`
- `stock_movements`
- `stock_inventories`
- `stock_inventory_items`
- `stock_transfers`
- `stock_transfer_items`

### Achats
- `suppliers`
- `purchase_requests`
- `purchase_request_items`
- `purchase_orders`
- `purchase_items`
- `purchase_receipts`
- `purchase_receipt_items`
- `purchase_invoices`
- `purchase_invoice_payments`

## Règles métier majeures

1. Un produit et son emplacement doivent appartenir à la même école.
2. Le stock disponible provient des mouvements enregistrés.
3. Une réception ne peut pas dépasser la quantité commandée restante.
4. Un inventaire clôturé devient historique ; ses écarts sont matérialisés par des mouvements d'ajustement.
5. Un transfert est atomique : sortie dans l'emplacement source + entrée dans l'emplacement cible.
6. Une facture fournisseur ne peut pas recevoir plus que son solde restant.
7. Le paiement fournisseur génère une écriture `expense` dans `cash_transactions`.
8. Les mutations sensibles sont réalisées par des fonctions SQL `SECURITY DEFINER` avec `search_path` vide et contrôle des permissions.

## Routes

- `/stocks`
- `/stocks/produits`
- `/stocks/fournisseurs`
- `/stocks/demandes`
- `/stocks/commandes`
- `/stocks/receptions`
- `/stocks/inventaires`
- `/stocks/mouvements`
- `/stocks/transferts`
- `/stocks/factures`

## Ne pas inventer

Le cahier des charges ne fournit pas de nomenclature comptable, de barème fiscal ou de règles réglementaires détaillées pour les factures fournisseurs. L'étape ne crée donc pas de telles règles en dur ; les comptes et paramètres financiers existants restent la source de configuration.

## Validation

À effectuer dans l'environnement local :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```
