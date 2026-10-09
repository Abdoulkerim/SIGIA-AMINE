# SIGIA-AMINE — ÉTAPE 12 : DOSSIER ÉLÈVE COMPLET

## Objectif
Construire un dossier élève unifié sans créer de table de duplication.

Le dossier rassemble les données existantes :
- identité ;
- coordonnées ;
- parents / tuteurs ;
- admissions ;
- inscriptions / réinscriptions ;
- classe et niveau actuels ;
- historique des inscriptions ;
- enseignants et affectations visibles ;
- personnes autorisées ;
- documents administratifs.

Les modules non encore développés sont signalés, mais aucune donnée fictive n'est inventée :
- pédagogie : étape 13 ;
- vie scolaire : étape 14 ;
- finance : étape 15 ;
- internat : étape 16 ;
- restauration : étape 17 ;
- RH / paie : étape 18 ;
- stocks : étape 19 ;
- Tahfiz/Arabe : étape 20 ;
- Wushu : étape 21 ;
- agriculture/élevage : étape 22 ;
- communication/documents avancés : étape 23 ;
- statistiques : étape 24 ;
- IA : étape 25.

## Conception
Migration :
`supabase/migrations/202609250020_student_dossier.sql`

RPC :
`public.get_student_dossier(uuid)`

La fonction est `SECURITY INVOKER` : elle ne contourne pas les RLS des tables sources.

Aucun mot de passe n'est stocké dans le dossier élève.

## Route
Le dossier complet est maintenant accessible via :
`/administration/eleves/[id]`

## Validation
Depuis la racine :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

## Tests fonctionnels
1. Ouvrir un élève de test.
2. Vérifier l'identité.
3. Vérifier l'inscription et la classe actuelle.
4. Vérifier les parents/tuteurs.
5. Vérifier les admissions liées.
6. Vérifier les enseignants visibles pour cet élève.
7. Vérifier l'historique d'inscription.
8. Vérifier les personnes autorisées.
9. Vérifier les documents.
10. Tester avec un compte parent, un compte élève et un compte enseignant lorsque ces comptes seront disponibles.
11. Vérifier qu'un utilisateur ne peut pas obtenir le dossier d'un élève d'une autre école ou hors de son périmètre.

## Finance
Le dossier ne calcule pas encore les soldes financiers : le module Finance est planifié en étape 15. Les futures informations financières devront être ajoutées via les tables `invoices`, `payments`, `payment_allocations` et les vues/RPC dédiées, sans dupliquer les montants dans `students`.
