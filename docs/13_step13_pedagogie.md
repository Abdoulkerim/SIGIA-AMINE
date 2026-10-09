# SIGIA-AMINE — ÉTAPE 13 : PÉDAGOGIE

## 1. Périmètre livré

Cette étape rend opérationnelle la chaîne pédagogique :

`Classe → Matière → Enseignant → Évaluation → Note → Moyenne → Bulletin`.

Routes ajoutées :
- `/pedagogie`
- `/pedagogie/emploi-du-temps`
- `/pedagogie/emploi-du-temps/nouveau`
- `/pedagogie/types-evaluations`
- `/pedagogie/evaluations`
- `/pedagogie/evaluations/nouveau`
- `/pedagogie/evaluations/[id]/notes`
- `/pedagogie/bulletins`
- `/pedagogie/bulletins/[id]`

## 2. Migration

`supabase/migrations/202609250021_pedagogy_workflows.sql`

Elle complète les tables pédagogiques déjà présentes depuis la migration 008 sans recréer de tables concurrentes.

### Contrôles ajoutés
- cohérence école / année / classe / niveau / matière / enseignant ;
- affectation réelle enseignant + classe + matière ;
- enseignant actif + profil enseignant ;
- période liée à l'année scolaire ;
- période clôturée = aucun changement pédagogique sensible ;
- date d'évaluation dans la période ;
- matière active et affectée au niveau de la classe ;
- types d'évaluations actifs et propres à l'école ;
- conflits de salle, d'enseignant et de classe sur l'emploi du temps ;
- notes limitées au barème ;
- normalisation des notes sur 20 ;
- élève obligatoirement inscrit dans la classe pour recevoir une note ;
- verrouillage des notes après publication de l'évaluation ;
- verrouillage des bulletins après publication.

## 3. Permissions

Permissions fines :
- `timetable.view`
- `timetable.manage`
- `assessments.view`
- `assessments.manage`
- `grades.view`
- `grades.enter`
- `grades.publish`
- `report_cards.view`
- `report_cards.generate`
- `report_cards.publish`

Les enseignants peuvent saisir les notes de leurs évaluations. La publication reste réservée aux profils disposant de `grades.publish`.

## 4. RPC principales

- `create_timetable_slot`
- `update_timetable_slot`
- `set_timetable_slot_active`
- `create_assessment_type`
- `create_assessment`
- `set_assessment_published`
- `save_assessment_grades`
- `generate_report_card_draft`
- `publish_report_card`

Les RPC critiques sont `SECURITY DEFINER`, avec `search_path` contrôlé et `EXECUTE` retiré de `anon`/`public`.

## 5. Règles de bulletin

Le brouillon de bulletin :
1. récupère l'inscription active de l'élève pour l'année ;
2. récupère les matières actives du niveau via `subject_level_assignments` ;
3. calcule les moyennes à partir des notes publiées de la période ;
4. applique le coefficient effectif de la matière ;
5. calcule `general_average` comme moyenne pondérée des matières disponibles ;
6. laisse `rank` et `decision` à `NULL`.

### Pourquoi `rank` et `decision` restent null ?
Le cahier des charges prévoit l'évaluation/classification, mais les règles numériques officielles détaillées d'Al Amine ne sont pas fournies dans la source actuelle. Il serait incorrect de fabriquer une formule de classement ou une décision de passage.

Même principe pour les types d'évaluation : l'interface permet de les paramétrer, mais aucun type officiel n'est injecté automatiquement.

## 6. Tests

Le contrat SQL ajouté est :

`supabase/tests/database/010_pedagogy_contract.sql`

Validation recommandée depuis PowerShell :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

## 7. Tests fonctionnels

### Emploi du temps
1. Créer une affectation enseignant/classe/matière existante.
2. Créer un créneau valide.
3. Créer un deuxième créneau avec la même classe et une heure qui chevauche le premier : l'insertion doit être refusée.
4. Refaire avec le même enseignant : refus.
5. Refaire avec la même salle : refus.

### Évaluation
1. Créer un type d'évaluation.
2. Créer une évaluation pour une affectation valide.
3. Saisir plusieurs notes.
4. Vérifier la normalisation sur 20.
5. Publier l'évaluation.
6. Vérifier que la saisie/modification de note est ensuite bloquée.

### Bulletin
1. Vérifier qu'une période possède des notes publiées.
2. Générer le brouillon.
3. Vérifier les lignes matières et la moyenne générale.
4. Clôturer la période.
5. Publier le bulletin.
6. Vérifier qu'il devient immuable sauf droits d'administration prévus.

## 8. Données réelles Al Amine

Aucun élève, parent, enseignant ou résultat réel n'est ajouté par cette étape. Les écrans sont prêts à consommer les données introduites lors des étapes précédentes.
