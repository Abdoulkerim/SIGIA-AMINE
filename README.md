# SIGIA-AMINE — dépôt de développement professionnel

## Stack de développement

- VS Code
- Next.js + TypeScript (implémentation UI/service à l’étape suivante)
- Supabase CLI
- PostgreSQL local via la stack Supabase
- Supabase Auth
- PostgreSQL RLS
- Supabase Storage privé
- Git

## Règle de déploiement

`code → migration → reset local → tests → lint → revue → Git → staging → recette → production`.

Supabase recommande explicitement le développement local, le versionnement des migrations et le déploiement des migrations validées vers le projet distant.

## Installation Windows

1. Installer Docker Desktop et le démarrer.
2. Installer Node.js LTS.
3. Ouvrir le dossier dans VS Code.
4. Installer la CLI Supabase dans le projet :

```powershell
npm install --save-dev supabase
```

Si le fichier `supabase/config.toml` n’existe pas encore, initialiser une fois :

```powershell
npx supabase init
```

La CLI crée `supabase/config.toml`. Ensuite :

```powershell
npx supabase start
```

## Recréer la base locale

```powershell
npx supabase db reset
```

Cette commande repart d’une base locale propre et rejoue toutes les migrations dans l’ordre.

## Validation

```powershell
npx supabase db reset
npx supabase test db
npx supabase db lint
```

Ou :

```powershell
.\scripts\validate.ps1
```

## Migration 001 → 014

| N° | Migration | Fonction |
|---:|---|---|
| 001 | extensions_types | extensions, types, schéma `app` |
| 002 | core_organisation | écoles, paramètres, années scolaires, périodes |
| 003 | users_roles | utilisateurs, rôles, permissions |
| 004 | academic_reference | niveaux, classes, matières, programmes |
| 005 | personnel_teachers | personnel et enseignants |
| 006 | students_administration | élèves, parents, admissions, inscriptions |
| 007 | documents | documents |
| 008 | academic_assessment | emploi du temps, évaluations, notes, bulletins |
| 009 | school_life_boarding_catering | présence, discipline, internat, restauration |
| 010 | tahfiz_wushu | Tahfiz, formation islamique, Wushu |
| 011 | finance | frais, factures, paiements, caisse |
| 012 | stock_agriculture_hr | stocks, achats, AGR, agriculture, élevage, RH, paie |
| 013 | communication_ai_audit_logic_seed | communication, IA, audit, index, fonctions, triggers, seed RBAC, vues |
| **014** | **hardening_1a1_security_rls_storage** | **RLS/RBAC, multi-écoles, règles métier, audit, Storage** |
| **027** | **stock_purchases_workflows** | **Stocks / Achats : produits, inventaires, transferts, demandes, commandes, réceptions, factures fournisseurs** |
| **028** | **tahfiz_arabe_workflows** | **Tahfiz / Arabe : mémorisation, séances, évaluations, progression, référentiel coranique** |
| **029** | **wushu_workflows** | **Wushu : groupes, séances, présences, évaluations, grades, compétitions** |
| **030** | **agriculture_livestock_agr_workflows** | **Agriculture / Élevage / AGR : sites, campagnes, intrants, production, cheptel, ventes, dépenses et résultats** |
| **031** | **documents_communication_workflows** | **Documents / Communication : documents, versions, demandes, annonces, notifications et file d’envoi** |
| **032** | **statistics_dashboards_workflows** | **Statistiques / Dashboards : permissions, indicateurs et tableaux de bord Direction, Pédagogie, Finance, Internat et Activités** |

Le V1 monolithique est conservé sous `legacy/` pour traçabilité. Il ne doit plus être exécuté comme source de vérité.

## Cloud Supabase

Après validation locale uniquement :

```powershell
npx supabase login
npx supabase link --project-ref VOTRE_PROJECT_REF
npx supabase db push --dry-run
npx supabase db push
```

**Ne modifie pas le schéma distant manuellement avec SQL Editor/Table Editor après le démarrage des migrations.** Toute modification doit passer par une nouvelle migration Git.

## Créer une future migration

```powershell
npx supabase migration new nom_de_la_modification
```

La CLI crée un nouveau fichier versionné dans `supabase/migrations/`.

## Arborescence applicative

```text
SIGIA-AMINE/
├── src/
│   ├── app/
│   │   ├── (auth)/
│   │   │   └── login/
│   │   └── (dashboard)/
│   │       ├── administration/
│   │       ├── pedagogie/
│   │       ├── vie-scolaire/
│   │       ├── finance/
│   │       ├── internat/
│   │       ├── restauration/
│   │       ├── tahfiz/
│   │       ├── wushu/
│   │       ├── personnel/
│   │       ├── stocks/
│   │       ├── achats/
│   │       ├── agriculture/
│   │       ├── elevage/
│   │       ├── communication/
│   │       ├── documents/
│   │       ├── statistiques/
│   │       ├── ia/
│   │       └── administration-it/
│   ├── components/
│   ├── features/
│   ├── lib/
│   ├── server/
│   │   ├── repositories/
│   │   └── services/
│   ├── types/
│   ├── config/
│   ├── hooks/
│   └── styles/
├── supabase/
│   ├── migrations/
│   ├── tests/database/
│   ├── functions/
│   ├── seed.sql
│   └── config.toml       ← généré par `supabase init`
├── scripts/
├── docs/
├── legacy/
├── .vscode/
├── .env.example
├── .gitignore
└── README.md
```

## Sécurité

`Supabase Auth → rôle → permission → action → RLS → périmètre des données`.

- Parent : enfants liés uniquement.
- Élève : soi-même.
- Enseignant : classes/matières affectées.
- Comptable : finance selon permissions.
- Surveillant : présence/disciplines.
- Direction : pilotage selon permissions.
- IT : administration technique, sans accès métier global implicite.

Les données sensibles et les opérations critiques restent protégées côté PostgreSQL, RLS et fonctions serveur.

## Avant l’Étape 2

Ne pas injecter les vraies données d’Al Amine, ne pas construire le frontend métier et ne pas pousser en production avant que `db reset`, `test db` et `db lint` soient verts.


## Étape 2 — Seed officiel Al Amine

Le fichier `supabase/seed.sql` contient uniquement les données institutionnelles initiales. Aucun élève, parent ou personnel réel n'est inclus.

Après validation des migrations locales :

```powershell
npx supabase db reset
npx supabase gen types typescript --local > src/types/database.types.ts
```

## Étape 3 — Frontend

Installer le frontend dans le même dossier racine `SIGIA-AMINE` :

```powershell
npm install next@latest react@latest react-dom@latest @supabase/ssr @supabase/supabase-js zod
npm install --save-dev typescript @types/node @types/react @types/react-dom
```

Puis créer `.env.local` à partir de `.env.example`. Les clés secrètes restent uniquement côté serveur. Supabase recommande `@supabase/ssr` et un client serveur/client séparés pour Next.js.

Voir `docs/03_frontend_bootstrap.md` puis `docs/04_module_administration_eleves.md`.

## Roadmap post-Administration
- Étape 6 : Parents / Tuteurs
- Étape 7 : Admissions / Préinscriptions
- Étape 8 : Inscriptions / Réinscriptions
- Étape 9 : Niveaux / Classes
- Étape 10 : Matières
- Étape 11 : Enseignants / Affectations
- Étape 12 : Dossier élève complet
- Étape 13 : Pédagogie
- Étape 14 : Vie scolaire
- Étape 15 : Finance
- Étape 16 : Internat
- Étape 17 : Restauration
- Étape 18 : Personnel / RH / Paie
- Étape 19 : Stocks / Achats
- Étape 20 : Tahfiz / Arabe
- Étape 21 : Wushu
- Étape 22 : Agriculture / Élevage / AGR
- Étape 23 : Documents / Communication
- Étape 24 : Statistiques / Dashboards
- Étape 25 : IA
- Étape 26 : Production

Voir `docs/05_roadmap_etapes_6_13_et_suite.md` et `docs/06_parents_tuteurs.md`.

## Étape 7 — Admissions / Préinscriptions
La migration `202609250015_admissions_workflow.sql` ajoute les champs candidat, la permission dédiée admissions, les contrôles inter-écoles, les transitions de statut, les index et les policies RLS spécifiques.

Routes ajoutées :
- `/administration/admissions`
- `/administration/admissions/nouveau`
- `/administration/admissions/[id]`

## Validation rapide de l'étape 7
Depuis la racine du projet :

```powershell
.\scripts\validate-step7.ps1
```

Routes :
- `/administration/admissions`
- `/administration/admissions/nouveau`
- `/administration/admissions/[id]`

Migration : `supabase/migrations/202609250015_admissions_workflow.sql`
Test DB : `supabase/tests/database/004_admissions_contract.sql`

## Étape 8 — Inscriptions / Réinscriptions
Migration ajoutée : `202609250016_enrollments_workflow.sql`.
Le dossier d'inscription peut rester `pending` sans classe afin de respecter l'ordre de développement : les classes seront configurées à l'étape 9. La finalisation exige ensuite une classe de la même école et de la même année.

## Étape 8 — Inscriptions / Réinscriptions
Migration : `202609250016_enrollments_workflow.sql`.
Le dossier d'inscription peut rester `pending` sans classe pendant que le référentiel Niveaux/Classes est encore en construction. La finalisation vers `enrolled` exige une classe de la même école, de la même année et, si renseigné, du niveau demandé.

### Routes ajoutées
- `/administration/inscriptions`
- `/administration/inscriptions/nouveau`
- `/administration/inscriptions/[id]`

### Validation
```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
```


## Étape 13 — Pédagogie

La migration `202609250021_pedagogy_workflows.sql` rend opérationnels :
- emploi du temps avec contrôle des conflits ;
- types d’évaluations configurables ;
- évaluations liées aux affectations enseignant/classe/matière ;
- saisie atomique des notes ;
- publication et verrouillage des notes ;
- génération des brouillons de bulletins ;
- publication des bulletins après clôture de période.

Routes :
- `/pedagogie`
- `/pedagogie/emploi-du-temps`
- `/pedagogie/types-evaluations`
- `/pedagogie/evaluations`
- `/pedagogie/bulletins`

### Règles non inventées
Les règles officielles détaillées d'Al Amine pour les types d'évaluations, coefficients officiels, rangs, décisions et absence/neutralisation ne sont pas présentes dans le cahier des charges fourni. Elles doivent être paramétrées/fournies avant toute automatisation officielle de ces règles. `rank` et `decision` restent donc null dans les bulletins générés par cette étape.

Validation étape 13 :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

Voir `docs/13_step13_pedagogie.md`.

## Étape 14 — Vie scolaire

La migration `202609260022_school_life_workflows.sql` complète et sécurise le socle existant pour la vie scolaire : présences, absences, retards, justificatifs, discipline, suivi éducatif et récompenses.

### Routes
- `/vie-scolaire`
- `/vie-scolaire/presences`
- `/vie-scolaire/presences/nouveau`
- `/vie-scolaire/presences/[id]`
- `/vie-scolaire/justificatifs`
- `/vie-scolaire/discipline`
- `/vie-scolaire/discipline/categories`
- `/vie-scolaire/suivi-educatif`
- `/vie-scolaire/recompenses`

### Migration et test
- `supabase/migrations/202609260022_school_life_workflows.sql`
- `supabase/tests/database/011_school_life_contract.sql`

### Validation
```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```

Voir `docs/14_step14_vie_scolaire.md` pour les règles, le périmètre et les tests fonctionnels.


## Étape 15 — Finance & comptabilité
Migration ajoutée : `supabase/migrations/202609260023_finance_workflows.sql`.
Tests : `supabase/tests/database/012_finance_contract.sql`.
Routes : `/finance`, `/finance/tarifs`, `/finance/factures`, `/finance/paiements`, `/finance/depenses`, `/finance/caisse`, `/finance/impayes`.
Documentation : `docs/15_step15_finance_comptabilite.md`.


## Étape 15 — Finance & comptabilité
Migration ajoutée : `supabase/migrations/202609260023_finance_workflows.sql`.
Tests : `supabase/tests/database/012_finance_contract.sql`.
Routes : `/finance`, `/finance/tarifs`, `/finance/factures`, `/finance/paiements`, `/finance/depenses`, `/finance/caisse`, `/finance/impayes`.
Documentation : `docs/15_step15_finance_comptabilite.md`.


## Étape 15 — Finance & comptabilité
Migration ajoutée : `supabase/migrations/202609260023_finance_workflows.sql`.
Tests : `supabase/tests/database/012_finance_contract.sql`.
Routes : `/finance`, `/finance/tarifs`, `/finance/factures`, `/finance/paiements`, `/finance/depenses`, `/finance/caisse`, `/finance/impayes`.
Documentation : `docs/15_step15_finance_comptabilite.md`.

## Étape 16 — Internat

Le module Internat couvre désormais les structures (bâtiments, dortoirs, chambres, lits), affectations, mouvements de sortie/retour et présences. Les mutations sensibles passent par des RPC sécurisées et le Data API reste en lecture pour ces tables.

Pages principales : `/internat`, `/internat/structures`, `/internat/affectations`, `/internat/mouvements`, `/internat/presences`.


## Étape 17 — Restauration
Menus, services, présences repas, consommations et intégration stock cuisine. Voir `docs/17_step17_restauration.md`.

## Étape 18 — Personnel / RH / Paie
La migration `202609260026_hr_payroll_workflows.sql` renforce le dossier personnel, contrats, présence, congés, compétences, formations et paie, avec permissions RH/paie et RPC sécurisées.

Routes principales : `/personnel`, `/personnel/employes`, `/personnel/contrats`, `/personnel/presences`, `/personnel/conges`, `/personnel/formations`, `/personnel/paie`.

Test : `supabase/tests/database/015_hr_payroll_contract.sql`.
Documentation : `docs/18_step18_personnel_rh_paie.md`.

## Étape 19 — Stocks / Achats

La migration `202609260027_stock_purchases_workflows.sql` transforme le socle stock/achat en workflows opérationnels : référentiel produits et fournisseurs, demandes d'achat, commandes, réceptions alimentant les mouvements de stock, inventaires et ajustements, transferts entre emplacements et factures fournisseurs/paiements reliés à la caisse.

Principes métier :
- Le stock disponible est dérivé des `stock_movements` et matérialisé dans `stock_balances`.
- Les réceptions d'achats génèrent les entrées de stock dans une transaction.
- Les inventaires génèrent les ajustements positifs/négatifs avant clôture.
- Les transferts créent une sortie source et une entrée destination.
- Les écritures sensibles passent par des RPC sécurisées ; les tables critiques ne permettent pas de mutation directe par `authenticated`.
- Aucun barème fiscal ou règle comptable réglementaire supplémentaire n'est inventé dans cette étape.

Routes frontend :
`/stocks`, `/stocks/produits`, `/stocks/fournisseurs`, `/stocks/demandes`, `/stocks/commandes`, `/stocks/receptions`, `/stocks/inventaires`, `/stocks/mouvements`, `/stocks/transferts`, `/stocks/factures`.

Validation locale recommandée :
```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
npm run dev
```


## Étape 20 — Tahfiz / Arabe
Voir `docs/20_step20_tahfiz_arabe.md` et exécuter `scripts/validate-step20.ps1`.

## Étape 23 — Documents / Communication
- Documents, versioning, demandes, archives et accès contrôlés.
- Annonces ciblées et notifications in-app.
- File de livraison email/SMS/WhatsApp/push en attente de fournisseurs.
- Voir `docs/23_step23_documents_communication.md`.


## Étape 25 — Intelligence artificielle

La migration `202609260033_ai_workflows.sql` transforme le socle IA existant en couche d’assistance gouvernée : conversations, exécutions, appels d’outils, prompts réutilisables et alertes à validation humaine.

Principes :
- l’IA lit uniquement les données accessibles au profil ;
- les outils exposés sont en lecture seule sur les données métier ;
- les alertes IA restent en statut de revue jusqu’à validation humaine ;
- aucune clé de fournisseur IA n’est exposée au navigateur ;
- le fournisseur et le modèle sont configurables par secrets Edge Function (`OPENAI_API_KEY`, `AI_MODEL`).

Routes : `/ia`, `/ia/alertes`, `/ia/prompts`.
Fonction Supabase : `supabase/functions/ai-assistant/index.ts`.
Test : `supabase/tests/database/022_ai_contract.sql`.
Documentation : `docs/25_step25_intelligence_artificielle.md`.
