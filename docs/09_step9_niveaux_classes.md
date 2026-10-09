# SIGIA-AMINE — ÉTAPE 9 : NIVEAUX / CLASSES

## Objectif
Créer le référentiel académique qui permettra de finaliser les inscriptions de l'étape 8 et d'alimenter ensuite les matières, enseignants, emplois du temps et pédagogie.

## Principe
Le cahier des charges confirme l'existence des niveaux et classes mais ne fournit pas la liste officielle complète. Aucun niveau/classe réel n'est donc inventé dans `seed.sql`.

## Base de données
Migration :
`supabase/migrations/202609250017_academic_levels_classes.sql`

Protections :
- code et nom non vides ;
- codes uniques sans tenir compte de la casse ;
- classes uniques par année ;
- niveau et année scolaire de la même école ;
- classe active obligatoirement rattachée à un niveau ;
- capacité positive ;
- RLS et permissions distinctes ;
- opérations métier atomiques via RPC.

## Permissions
- `levels.view`
- `levels.manage`
- `classes.view`
- `classes.manage`

Les rôles administratifs/pédagogiques reçoivent les droits appropriés. Les enseignants et responsables de vie scolaire reçoivent la lecture des classes sans pouvoir les modifier.

## Pages
- `/administration/niveaux`
- `/administration/niveaux/nouveau`
- `/administration/classes`
- `/administration/classes/nouveau`
- `/administration/classes/[id]`

## Workflow
Niveau :
Créer → modifier → archiver si aucune classe active ne dépend du niveau.

Classe :
Créer → modifier → archiver.

Une classe contient au minimum :
- année scolaire ;
- niveau ;
- nom ;
- code ;
- éventuellement section ;
- salle ;
- capacité.

## Validation
Dans la racine `SIGIA-AMINE` :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

Tests fonctionnels :
1. créer un niveau fictif local ;
2. créer une classe fictive liée à ce niveau et à l'année locale ;
3. vérifier la liste ;
4. modifier la classe ;
5. archiver la classe ;
6. vérifier qu'un niveau ne peut pas être archivé tant qu'une classe active lui est rattachée ;
7. vérifier que les relations inter-écoles sont refusées.

## Données officielles
Les vraies listes de niveaux/classes d'Al Amine seront ajoutées ultérieurement dans un script de données administratives contrôlé, après validation par l'établissement.
