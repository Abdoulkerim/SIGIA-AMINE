# SIGIA-AMINE — ÉTAPE 11 : ENSEIGNANTS / AFFECTATIONS

## Objectif
Gérer le personnel enseignant, son profil pédagogique et ses affectations à une classe et une matière pour une année scolaire.

Le cahier des charges prévoit :
- affectation aux classes et matières ;
- volume horaire ;
- responsabilités pédagogiques ;
- suivi des enseignements assurés.

## Modèle
`employees` = identité administrative.
`teacher_profiles` = informations pédagogiques.
`teacher_assignments` = enseignant + classe + matière + année.

## Règles métier
Une affectation est refusée si :
- l'enseignant n'appartient pas à l'école ;
- l'enseignant n'est pas actif ;
- aucun `teacher_profile` n'existe ;
- la classe n'appartient pas à la même école ;
- l'année de la classe est différente de l'année d'affectation ;
- la matière n'appartient pas à la même école ;
- la matière n'est pas active pour le niveau et l'année de la classe ;
- le volume horaire est non positif ;
- une autre affectation principale existe déjà pour classe + matière + année.

Les conflits d'emploi du temps ne sont pas encore contrôlés ici ; ils seront traités avec le module emploi du temps.

## Permissions
- `teachers.view`
- `teachers.manage`
- `hr.manage` reste réservé au module RH.

Un enseignant connecté peut consulter son propre périmètre ; il ne peut pas créer des affectations.

## Routes
- `/personnel`
- `/personnel/enseignants`
- `/personnel/enseignants/nouveau`
- `/personnel/enseignants/[id]`
- `/pedagogie/affectations`
- `/pedagogie/affectations/nouveau`

## Validation locale
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

## Test fonctionnel recommandé
1. Créer un enseignant local de test.
2. Créer ou utiliser une matière et une classe de test des étapes 9-10.
3. Créer une affectation.
4. Vérifier que la classe et la matière sont compatibles avec la même année/niveau.
5. Marquer une affectation principale.
6. Vérifier qu'une deuxième affectation principale pour la même classe/matière/année est refusée.
7. Vérifier qu'un enseignant inactif ne peut pas recevoir d'affectation.
8. Vérifier que l'enseignant connecté ne voit que ses propres affectations, tandis qu'un responsable habilité voit celles de son établissement.

## Note de sécurité
Les policies `employees`, `teacher_profiles` et `teacher_assignments` utilisent des helpers `SECURITY DEFINER` pour vérifier le lien entre un compte, un employé et son profil enseignant sans créer de récursion RLS.
