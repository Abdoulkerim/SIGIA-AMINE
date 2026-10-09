# SIGIA-AMINE — Étape 8 : Inscriptions / Réinscriptions

## Objectif
Créer le dossier d'inscription ou de réinscription, conserver l'historique et ne finaliser l'affectation à une classe qu'une fois le référentiel des classes disponible.

## Principe
Une inscription `pending` peut exister sans `class_id`. Une inscription `approved`, `enrolled` ou `completed` exige une classe cohérente avec l'année et le niveau demandé.

## Flux inscription
Admission approuvée → création/récupération élève → brouillon d'inscription → classe (étape 9) → inscription finalisée.

## Flux réinscription
Élève existant → nouvelle année scolaire → brouillon de réinscription → classe (étape 9) → finalisation.

## Sécurité
- `school_id` obligatoire et vérifié sur élève, année, niveau, classe et admission source.
- `enrollments.view` pour la consultation autorisée.
- `enrollments.manage` pour les mutations.
- Parent/élève : lecture limitée à leur périmètre.
- Mutations atomiques via RPC `public.prepare_enrollment_from_admission`, `public.create_reenrollment_draft` et `public.finalize_enrollment`.

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

## Étape suivante
Étape 9 — Niveaux / Classes : création des référentiels, capacité, sections, affectation des élèves et finalisation des inscriptions en attente.
