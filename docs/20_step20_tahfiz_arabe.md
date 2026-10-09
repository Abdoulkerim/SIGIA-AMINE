# Étape 20 — Tahfiz / Arabe

## Périmètre
Cette étape met en œuvre le suivi spécialisé demandé pour Al Amine : niveau de l’élève, nouvelles mémorisations, révisions, sourates acquises, invocations/hadiths et évaluations/progression côté Tahfiz ; niveaux, parcours, séances, évaluations et progression côté Arabe. Le cahier des charges ne fournit pas de référentiel détaillé des niveaux, contenus ou échelles de notation : ces éléments sont donc paramétrables.

## Base de données
- Migration : `202609260028_tahfiz_arabe_workflows.sql`
- Réutilise `tahfiz_levels`, `student_tahfiz`, `tahfiz_sessions`, `quran_surahs`.
- Ajoute l’historique de progression Tahfiz.
- Ajoute `arabic_levels`, `student_arabic`, `arabic_sessions`, `arabic_evaluations`, `arabic_progress_history`.
- Ajoute RLS spécialisée et permissions `tahfiz.view/manage` et `arabic.view/manage`.
- Les écritures sensibles passent par RPC ; les tables spécialisées ne sont pas modifiables directement par `authenticated`.

## Fonctionnalités
### Tahfiz
- Niveaux configurables.
- Affectation de l’élève et du responsable.
- Suivi de progression 0–100 %.
- Séances : nouvelle mémorisation, révision, récitation, évaluation.
- Sourate + plage de versets lorsque renseignée.
- Présence à la séance.
- Publication des séances pour les espaces autorisés.
- Historique de progression.

### Arabe
- Niveaux configurables.
- Affectation de l’élève et du responsable.
- Séances avec activité et thème libres.
- Présence à la séance.
- Progression 0–100 %.
- Évaluations par période/domaine.
- Publication des évaluations.
- Historique de progression.

## Dossier élève
La fonction `get_student_tahfiz_arabic()` permet d’intégrer les données Tahfiz/Arabe au dossier numérique de l’élève, avec respect de la RLS.

## Référentiel des sourates
Le seed `supabase/seed/020_quran_surahs.sql` fournit les 114 sourates avec nom arabe, nom français/translittéré et numéro. Le nombre de versets n’est volontairement pas inventé dans ce seed ; si un référentiel institutionnel doit contrôler les plages de versets, les `verse_count` doivent être renseignés à partir de la source retenue par Al Amine.

## Routes
- `/tahfiz-arabe`
- `/tahfiz-arabe/tahfiz`
- `/tahfiz-arabe/arabe`

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

## Test contractuel
`supabase/tests/database/017_tahfiz_arabe_contract.sql` vérifie les tables, contraintes, permissions, fonctions RPC et protections de mutation.
