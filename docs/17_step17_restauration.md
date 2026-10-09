# Étape 17 — Restauration

## Périmètre
Cette étape couvre le module Restauration du cahier des charges Al Amine :
- effectifs et présence aux repas ;
- types de repas ;
- menus journaliers ;
- service des repas ;
- quantités servies ;
- coûts ;
- lien avec les stocks et les achats ;
- historique de consommation.

Le cahier des charges précise la chaîne « Effectif → Besoins → Achats → Préparation → Distribution → Suivi des coûts ». La présente migration implémente les briques données et workflows correspondantes sans inventer de menus, tarifs ou recettes spécifiques à Al Amine.

## Migration
`202609260025_catering_workflows.sql`

## Sécurité
Les tables de restauration sont en lecture via RLS. Les écritures sensibles passent par des RPC `SECURITY DEFINER` à `search_path=''`, avec contrôle de l'école, des permissions et des relations produit/stock/menu.

## Stock cuisine
Une consommation valide crée un mouvement `issue` dans `stock_movements`, ce qui conserve les mouvements comme source de vérité et synchronise automatiquement `stock_balances` par le trigger existant.

## Points volontairement paramétrables
Le cahier des charges ne fournit pas : recettes officielles, grammages, menus fixes, coût standard par élève, règles de facturation des repas ou normes nutritionnelles. Ils ne sont donc pas inventés dans cette étape.

## Pages
- `/restauration`
- `/restauration/types`
- `/restauration/menus`
- `/restauration/services`
- `/restauration/presences`
- `/restauration/consommations`

## Validation
```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```
