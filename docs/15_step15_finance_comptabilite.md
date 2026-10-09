# Étape 15 — Finance & comptabilité

## Périmètre
Cette étape implémente le module financier du cahier des charges Al Amine :
- tarification ;
- facturation ;
- paiements et reçus ;
- situation financière par élève/famille ;
- caisse ;
- dépenses ;
- impayés et relances ;
- reporting financier.

Le cahier des charges précise notamment : « Montant dû – Montant payé = Reste à payer » et demande la traçabilité des recettes, dépenses, caisse et états financiers. Le présent module respecte cette logique tout en gardant les opérations sensibles derrière des RPC sécurisées.

## Migration
`supabase/migrations/202609260023_finance_workflows.sql`

La migration :
1. renforce les contraintes inter-écoles ;
2. protège les types de frais, factures, paiements, dépenses et comptes ;
3. empêche la surallocation d'un paiement ou d'une facture ;
4. recalcule automatiquement les totaux de facture ;
5. synchronise les statuts `pending`, `partially_paid`, `paid` ;
6. interdit l'écriture directe des mouvements de caisse via le CRUD générique ;
7. fournit des RPC de création/validation ;
8. limite les parents/élèves à leur périmètre financier ;
9. expose un tableau de bord financier sécurisé.

## RPC principales
- `create_fee_type`
- `create_fee_schedule`
- `create_student_charge`
- `create_invoice`
- `record_payment`
- `create_expense`
- `approve_expense`
- `create_cash_account`
- `close_cash_account`
- `create_collection_reminder`
- `get_finance_dashboard`

## Règles métier implémentées
- Chaque ligne de facture doit être positive après remise.
- Un paiement doit être entièrement affecté à une ou plusieurs cibles.
- Une allocation ne peut dépasser le solde de sa cible.
- Une allocation ne peut référencer simultanément une facture et un frais direct.
- Une facture parent/élève doit rester dans la même école et, lorsqu'un élève est indiqué, le parent doit être lié à cet élève.
- Les dépenses sont créées en brouillon puis validées.
- Une dépense validée peut être postée dans un compte de caisse/banque via la RPC de validation.
- Les clôtures calculent le solde théorique à partir du solde initial et des mouvements.

## Interface
Routes ajoutées :
- `/finance`
- `/finance/tarifs`
- `/finance/factures`
- `/finance/factures/nouvelle`
- `/finance/paiements`
- `/finance/paiements/nouveau`
- `/finance/depenses`
- `/finance/depenses/nouvelle`
- `/finance/caisse`
- `/finance/impayes`

## Ce qui reste volontairement paramétrable
Le cahier des charges ne fournit pas de plan comptable réglementaire détaillé, de règles fiscales ou de nomenclature locale des écritures. Aucun de ces éléments n'est inventé dans cette étape. Les catégories de recettes/dépenses, comptes, fournisseurs et échéanciers restent donc configurables par l'établissement.

## Validation locale obligatoire
```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```
