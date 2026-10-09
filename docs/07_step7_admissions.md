# SIGIA-AMINE — Étape 7 : Admissions / Préinscriptions

## Objectif
Gérer le passage candidat → préinscription → examen du dossier → décision d'admission, sans créer prématurément une inscription.

## Règles
- Une préinscription appartient à une seule école.
- La référence de candidature est unique par école.
- Les relations `student_id`, `desired_level_id`, `desired_year_id`, `primary_parent_id` et `reviewed_by` doivent appartenir à la même école.
- Une nouvelle candidature commence en `pending`.
- Les transitions de statut sont limitées par PostgreSQL.
- `approved`, `rejected` et `cancelled` nécessitent `reviewed_at` et `reviewed_by`.
- `enrolled` sera utilisé par l'étape 8, pas par la simple décision d'admission.
- Les niveaux non encore paramétrés peuvent être saisis dans `desired_level_label` sans inventer le référentiel officiel.
- Les données personnelles réelles ne doivent pas être ajoutées au seed.

## Workflow utilisateur
1. Administration ouvre `Administration > Admissions`.
2. Cliquer `Nouvelle préinscription`.
3. Saisir le candidat, l'année souhaitée, le niveau souhaité, le régime et éventuellement le parent principal.
4. Enregistrer : statut `pending`.
5. Ouvrir le dossier.
6. `Approuver`, `Rejeter`, `Annuler` ou `Réouvrir` selon le statut.
7. L'étape 8 transformera une admission approuvée en élève/inscription selon les règles de dédoublonnage.

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
