# SIGIA-AMINE — Étape 21 : Wushu

## Périmètre
Le cahier des charges Al Amine prévoit pour le Wushu : groupe et niveau, présence aux entraînements, programme technique, grades/passages de grades, examens, compétitions, résultats et progression. Il prévoit aussi un responsable spécialisé Wushu disposant d'un accès aux élèves et aux données relevant de son activité, avec saisie des présences, évaluations, résultats et rapports.

## Ce qui est implémenté
- groupes Wushu et niveaux paramétrables ;
- responsable/coach actif lié au même établissement ;
- profils Wushu élève avec statut, grade courant et progression 0–100 ;
- séances d'entraînement avec type et thème ;
- présence par séance ;
- évaluations avec score optionnel et barème optionnel ;
- publication des évaluations ;
- historique de progression ;
- compétitions ;
- résultats, rangs, médailles et observations ;
- publication des compétitions/résultats ;
- intégration du résumé Wushu dans le dossier numérique de l'élève ;
- RLS multi-établissement et RPC sécurisées ;
- écritures sensibles désactivées directement pour `authenticated`.

## Référentiel non inventé
Le cahier des charges fourni ne donne aucun barème officiel de notation Wushu, aucun tableau officiel de grades, ni aucun seuil de passage. Le logiciel laisse donc ces éléments paramétrables.

## Permissions
- `wushu.view`
- `wushu.manage`
- `wushu.publish`

## Routes
- `/wushu`
- `/wushu/groupes`
- `/wushu/eleves`
- `/wushu/entrainements`
- `/wushu/presences`
- `/wushu/evaluations`
- `/wushu/competitions`

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
