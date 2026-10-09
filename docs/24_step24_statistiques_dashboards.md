# SIGIA-AMINE — Étape 24 : Statistiques / Dashboards

## 1. Périmètre

Cette étape implémente les tableaux de bord prévus par le cahier des charges :
- Direction / Coordination : effectifs, résultats, finances, personnel, internat, activités et indicateurs clés ;
- Pédagogie : moyennes/résultats, progression, absences, performances par classe et matière ;
- Finance : recettes, dépenses, encaissements, impayés et soldes ;
- Internat : effectifs, présence/absence, chambres et restauration/incidents liés aux données déjà structurées ;
- Activités : agriculture, élevage et AGR, avec résultats issus des modules opérationnels.

Le cahier des charges demande des statistiques fiables et des tableaux de bord, mais ne fournit pas une maquette graphique ni un dictionnaire complet des indicateurs. Les écrans utilisent donc uniquement des données déjà présentes dans SIGIA-AMINE et rendent les agrégations explicites.

## 2. Migration

`supabase/migrations/202609260032_statistics_dashboards_workflows.sql`

La migration ajoute les permissions fines :
- `dashboard.direction`
- `dashboard.pedagogy`
- `dashboard.finance`
- `dashboard.boarding`
- `dashboard.activities`

Elle ajoute des index de lecture, les RPC sécurisées de dashboard et leurs restrictions d'exécution.

## 3. Sécurité

Les dashboards ne s'appuient pas uniquement sur le lien de l'URL. Chaque RPC vérifie :
1. l'école demandée appartient aux écoles visibles de l'utilisateur ;
2. l'utilisateur possède la permission du dashboard concerné ;
3. les fonctions sont exécutables uniquement par `authenticated`.

Les parents et élèves ne reçoivent pas automatiquement les nouvelles permissions de dashboards : leur permission `reports.view` existante ne suffit pas à ouvrir ces vues globales.

## 4. Routes

- `/statistiques` — index des dashboards autorisés
- `/statistiques/direction`
- `/statistiques/pedagogie`
- `/statistiques/finance`
- `/statistiques/internat`
- `/statistiques/activites`

## 5. Validation

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

Puis tester les profils suivants : Direction, Direction des études, Enseignant, Comptable, Responsable internat, Responsable agriculture/élevage.

## 6. Limites volontairement conservées

Aucun indicateur réglementaire, coefficient statistique ou seuil d'alerte non fourni par le cahier des charges n'est inventé dans cette étape. Les futurs besoins de pilotage devront être ajoutés par migrations et tests dédiés.
