# SIGIA-AMINE — ÉTAPE 10 : MATIÈRES

## Objectif
Construire le catalogue des matières et leur paramétrage par niveau et année scolaire, sans inventer les matières officielles d'Al Amine.

## Principe de conception
Deux notions sont séparées :

1. `subjects` = catalogue stable d'une matière pour l'établissement.
2. `subject_level_assignments` = activation de cette matière pour un niveau et une année, avec possibilité de définir un coefficient et un volume horaire propres à ce niveau.

`programs` reste réservé au contenu/progression pédagogique et sera exploité avec le module pédagogique.

## Permissions
- `subjects.view`
- `subjects.manage`

Administration/direction/responsable pédagogique : gestion.
Enseignant : lecture.

## Règles métier
- code et nom obligatoires ;
- code unique par établissement, insensible à la casse ;
- nom unique par établissement, insensible à la casse ;
- coefficient strictement positif ;
- volume horaire strictement positif lorsqu'il est renseigné ;
- une matière appartient à une seule école ;
- une configuration matière/niveau/année appartient à la même école que ses références ;
- une matière active peut être configurée pour plusieurs niveaux/années ;
- un même couple année/niveau/matière ne peut exister qu'une fois ;
- une matière ne peut être archivée tant qu'elle possède des affectations niveau/année actives ;
- aucune donnée réelle d'Al Amine n'est inventée dans le seed.

## Routes
- `/pedagogie/matieres`
- `/pedagogie/matieres/nouveau`
- `/pedagogie/matieres/[id]`

## RPC
- `create_subject`
- `update_subject`
- `set_subject_active`
- `assign_subject_to_level`
- `set_subject_level_active`

## Validation locale
Depuis la racine `SIGIA-AMINE` :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

## Test fonctionnel local
1. Créer une matière fictive `TEST-MATH`.
2. Lui attribuer un coefficient et un volume horaire.
3. Ouvrir sa fiche.
4. L'associer à un niveau de test et à l'année locale.
5. Modifier le coefficient de l'affectation.
6. Désactiver l'affectation.
7. Réactiver l'affectation.
8. Vérifier qu'une matière avec une affectation active ne peut pas être archivée.
9. Vérifier qu'un compte sans `subjects.manage` ne peut pas créer/modifier une matière.
10. Vérifier qu'une relation inter-écoles est refusée.

## Données officielles
Les matières réellement utilisées par Al Amine seront saisies après validation de la direction. Le cahier des charges donne des domaines possibles (général, arabe, islamique, tahfiz, EPS, Wushu, etc.) mais pas la liste officielle complète ni les coefficients/volumes par niveau.
