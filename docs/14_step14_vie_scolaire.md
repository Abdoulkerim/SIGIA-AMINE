# Étape 14 — Vie scolaire

## Base fonctionnelle

Cette étape suit la section **8 — Module vie scolaire** du cahier des charges Al Amine : présence, absence, retard, justificatif, discipline et suivi éducatif. Le cahier des charges précise également que ces informations doivent être intégrées au dossier numérique de l’élève.

Le module reste volontairement séparé de l’internat, de la restauration, du personnel/RH, du Tahfiz et du Wushu.

## Ce qui est livré

### Présence / assiduité
- séances d’appel par année, classe, date, horaire et activité ;
- matière et responsable facultatifs ;
- statuts `present`, `absent`, `late`, `excused` ;
- heure d’arrivée et de départ ;
- motif/remark ;
- saisie transactionnelle d’une classe complète ;
- contrôle qu’un élève appartient bien à la classe et à l’année de la séance.

### Absences / justificatifs
- période début/fin ;
- motif ;
- document éventuellement lié ;
- statuts `pending`, `approved`, `rejected`, `cancelled` ;
- workflow de validation sécurisé par permission.

### Discipline
- catégories paramétrables ;
- niveau de gravité de 1 à 5 ;
- incident/observation/récompense/sanction via type libre, car le cahier des charges ne fournit pas une nomenclature officielle ;
- description ;
- action ou mesure éducative ;
- responsable du suivi ;
- historique.

### Suivi éducatif
- catégorie ;
- observation ;
- plan d’action ;
- prochaine date de revue ;
- statut `open`, `in_progress`, `closed`, `cancelled` ;
- responsable.

### Récompenses
- date ;
- titre ;
- catégorie facultative ;
- description ;
- auteur de l’attribution.

## Sécurité

La migration `202609260022_school_life_workflows.sql` renforce les tables déjà créées dans le socle initial. Elle ajoute notamment :

- validations inter-écoles ;
- cohérence élève/classe/année ;
- RLS distincte pour consultation et gestion ;
- fonctions `SECURITY DEFINER` à `search_path` vide et références qualifiées ;
- RPC transactionnelles pour les opérations sensibles ;
- restrictions aux élèves/parents/enseignants selon leur périmètre lorsque la consultation portail est permise ;
- permissions fines : `attendance.view`, `absence_justifications.review`, `discipline.view`, `followups.manage`, `rewards.manage`, etc.

## Limites volontairement conservées

Le cahier des charges ne donne pas de formule officielle de « taux d’assiduité », de barème disciplinaire, ni de catalogue définitif des types d’événements et sanctions. Ces éléments ne sont donc pas inventés dans cette étape ; l’application les garde paramétrables.

## Routes

- `/vie-scolaire`
- `/vie-scolaire/presences`
- `/vie-scolaire/presences/nouveau`
- `/vie-scolaire/presences/[id]`
- `/vie-scolaire/justificatifs`
- `/vie-scolaire/discipline`
- `/vie-scolaire/discipline/categories`
- `/vie-scolaire/suivi-educatif`
- `/vie-scolaire/recompenses`

## Validation locale obligatoire

Dans PowerShell :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

Ou :

```powershell
.\scripts\validate-step14.ps1
```

Après le démarrage :

1. créer une séance ;
2. ouvrir la séance ;
3. enregistrer plusieurs statuts ;
4. vérifier qu’un élève d’une autre classe est refusé par la base ;
5. créer un justificatif avec un environnement de test ;
6. valider/rejeter le justificatif ;
7. créer une catégorie ;
8. enregistrer un incident ;
9. créer un suivi puis le clôturer ;
10. créer une récompense ;
11. ouvrir le dossier d’un élève et vérifier le bloc Vie scolaire.

## Migration

`supabase/migrations/202609260022_school_life_workflows.sql`

## Test DB

`supabase/tests/database/011_school_life_contract.sql`
