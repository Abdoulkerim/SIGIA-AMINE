# SIGIA-AMINE — Étape 22 : Agriculture / Élevage / AGR

## Périmètre source
Le cahier des charges Al Amine prévoit pour ce domaine :
- activités et sites de production ;
- productions agricoles et animales ;
- intrants et dépenses ;
- stocks ;
- ventes et recettes ;
- résultats par activité ;
- personnes responsables ;
- développement progressif d'activités génératrices de revenus : production, transformation, services, commercialisation et autres AGR.

La cartographie générale présente aussi les flux :
- Agriculture : Production → Stock → Vente → Recette ;
- Élevage/aviculture : Élevage → Production → Stock → Vente → Recette ;
- autres AGR : Activité → Dépenses → Production/Service → Vente → Résultat.

## Implémentation
### Agriculture
- activités agricoles paramétrables ;
- sites de production ;
- campagnes/cultures ;
- surfaces et rendements prévisionnels/réels ;
- intrants prélevés du stock ;
- dépenses d'activité ;
- productions pouvant alimenter un stock ;
- ventes et recettes ;
- indicateurs de performance.

### Élevage
- activités d'élevage ;
- cheptel individuel ou en lot via `quantity` + `unit` ;
- type, race, sexe, date de naissance ;
- acquisition et statut ;
- événements d'élevage ;
- productions animales ;
- intrants reliés aux stocks ;
- ventes ;
- suivi de performance.

### AGR
- activité générique de type `agr` ;
- sites, responsables, budget et période ;
- dépenses ;
- production/service ;
- ventes ;
- résultat par activité.

## Intégration stock / finance
Les productions avec `product_id` créent un mouvement `production_in`.
Les intrants consomment le stock via un mouvement `issue`.
Les ventes associées à un produit créent un mouvement `sale`.
Les écritures financières peuvent être reliées à une dépense d'activité ou à une vente par identifiant de transaction, sans créer de double comptabilisation automatique.

## Sécurité
Les écritures métier passent par les RPC sécurisées. Les mutations directes de `economic_activities`, `livestock`, `productions`, `sales` et des nouvelles tables sont retirées à `authenticated`.
Les responsables Agriculture et Élevage utilisent leurs permissions dédiées.

## Paramétrage non inventé
Le cahier des charges ne fournit pas de rendement standard, de coût de revient officiel, de prix de vente, de protocole zootechnique, de nomenclature comptable ou de formule réglementaire. Ces éléments restent donc configurables par l'établissement.

## Routes
- `/activites`
- `/activites/agriculture`
- `/activites/elevage`
- `/activites/agr`

## Validation locale
```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```
