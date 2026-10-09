# Étape 18 — Personnel / RH / Paie

## Périmètre source
Le cahier des charges Al Amine demande pour le personnel :
- dossier administratif ;
- fonction et service ;
- contrat ;
- présence et absences ;
- congés ;
- rémunération ;
- formations et compétences ;
- historique professionnel.

La base existante possédait déjà les tables `employees`, `employee_contracts`, `employee_attendance`, `employee_leaves`, `payroll_periods` et `payroll_items`. Cette étape les renforce et ajoute les tables complémentaires `employee_skills` et `employee_trainings`.

## Migration
`supabase/migrations/202609260026_hr_payroll_workflows.sql`

## Workflows
1. Dossier employé → fonction/service → statut.
2. Contrat → période → salaire contractuel.
3. Présence → présent/absent/retard/excusé.
4. Congé → soumis → approuvé/refusé/annulé.
5. Compétence / formation → historique professionnel.
6. Paie → période → génération depuis les contrats actifs → ajustements manuels → validation → paiement → clôture.

## Sécurité
Les informations RH et salariales sont protégées par des permissions fines : `hr.view`, `hr.manage`, `payroll.view`, `payroll.manage`. Les tables RH/paie sont exposées en lecture via le Data API ; les écritures passent par des RPC `SECURITY DEFINER` avec `search_path=''` et contrôles d'école/permission.

Le rôle `accountant` reçoit uniquement `payroll.view`; il n'obtient pas automatiquement les droits RH de modification. Le rôle `hr_manager` gère RH et paie. La Direction dispose des permissions RH/paie prévues par cette étape.

## Règles métier
- Un employé ne peut pas avoir deux contrats actifs/draft/suspendus qui se chevauchent.
- Un congé soumis ou approuvé ne peut pas chevaucher un autre congé soumis/approuvé du même employé.
- Une présence est unique par employé et par date.
- Les horaires d'arrivée et de départ sont contrôlés.
- Une période de paie ne peut pas chevaucher une autre période non annulée de la même école.
- La paie est construite à partir des contrats actifs couvrant la période.
- Une période approuvée ne peut plus être modifiée par les RPC de préparation.
- Lorsque toutes les lignes sont payées ou annulées, la période passe à `paid`.
- La clôture exige que les lignes soient payées ou annulées.
- Les montants base/indemnités/retenues sont non négatifs et le net ne peut pas devenir négatif.

## Paie : point volontairement paramétrable
Le cahier des charges indique simplement « rémunération ». Il ne fournit ni barème salarial officiel, ni formule fiscale, ni cotisations, ni retenues réglementaires précises. L'étape n'invente donc pas de réglementation : les montants de base, indemnités et retenues sont paramétrables. Une future règle officielle pourra être ajoutée comme module métier séparé.

## Pages
- `/personnel`
- `/personnel/employes`
- `/personnel/employes/nouveau`
- `/personnel/employes/[id]`
- `/personnel/contrats`
- `/personnel/presences`
- `/personnel/conges`
- `/personnel/formations`
- `/personnel/paie`

## Test contractuel
`supabase/tests/database/015_hr_payroll_contract.sql`

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
