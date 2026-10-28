# SIGIA-AMINE — Runbook de mise en production

## 1. Cible

Architecture recommandée :

`Navigateur → Vercel / Next.js → Supabase Auth + Postgres + Storage + Edge Functions`

Le dépôt reste la source de vérité pour le code et les migrations. Une fois le projet migratoire adopté, aucune modification de schéma ne doit être faite directement sur la base distante ; les changements passent par des migrations versionnées.

## 2. Avant production

Exécuter localement :

```powershell
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
npx supabase gen types typescript --local > src/types/database.types.ts
npm run typecheck
npm run build
```

Puis créer une release Git :

```powershell
git checkout main
git pull
git tag v1.0.0
git push origin v1.0.0
```

## 3. Supabase

Créer un projet Supabase STAGING et un projet PRODUCTION séparés.

Se connecter :

```powershell
supabase login
supabase projects list
```

Lier la production :

```powershell
supabase link --project-ref YOUR_PRODUCTION_PROJECT_REF
```

Pousser uniquement les migrations :

```powershell
supabase db push
```

Le seed `supabase/seed.sql` contient actuellement des paramètres institutionnels de démarrage, dont une année scolaire à confirmer. Ne pas utiliser `--include-seed` en production tant que l'année scolaire et les paramètres officiels n'ont pas été validés.

## 4. Edge Function IA

Déployer :

```powershell
supabase functions deploy ai-assistant --project-ref YOUR_PRODUCTION_PROJECT_REF
```

Configurer les secrets hors Git :

```powershell
supabase secrets set OPENAI_API_KEY=YOUR_REAL_KEY --project-ref YOUR_PRODUCTION_PROJECT_REF
supabase secrets set AI_MODEL=gpt-5.6-luna --project-ref YOUR_PRODUCTION_PROJECT_REF
```

Vérifier :

```powershell
supabase secrets list --project-ref YOUR_PRODUCTION_PROJECT_REF
```

La clé IA ne doit jamais être préfixée `NEXT_PUBLIC_` ni placée dans le code navigateur.

## 5. Vercel / Next.js

Connecter le dépôt GitHub à un projet Vercel. Le framework Next.js est détecté automatiquement.

Variables Production :

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_URL` (même URL de projet, côté serveur)
- `SUPABASE_SECRET_KEY` (clé secrète/service role, côté serveur; requise pour créer les comptes)
- `NEXT_PUBLIC_APP_URL`

Ajouter `SUPABASE_SECRET_KEY` dans les variables d'environnement Vercel du projet Supabase de production, avec l'environnement `Production` sélectionné. Copier la clé secrète ou `service_role` depuis les clés API du projet Supabase. Ne jamais lui ajouter le préfixe `NEXT_PUBLIC_`. Redéployer l'application après l'ajout; les variables Vercel ne sont injectées dans une version déjà déployée qu'après un nouveau déploiement.

Ne pas placer la clé OpenAI dans les variables publiques de Next.js. Elle appartient aux secrets de la fonction Edge.

Après configuration, déployer depuis `main` ou via la CLI :

```powershell
vercel deploy --prod
```

Pour un déploiement Docker, définir `SUPABASE_URL` et `SUPABASE_SECRET_KEY` dans les secrets/variables d'environnement du conteneur au démarrage. Ne pas les mettre dans les arguments de construction (`Build Args`) : ils ne garantissent pas leur présence à l'exécution et un secret fourni au build peut être conservé dans l'image ou ses journaux. Après modification, redémarrer le conteneur.

## 6. Domaine et Auth

Dans Supabase Auth, configurer l'URL de site et les redirect URLs exactes de production.

Exemple :

`https://app.example.com/auth/callback`

Le domaine public doit utiliser HTTPS.

## 7. Smoke tests

Après déploiement :

```powershell
npm run smoke:production -- https://app.example.com
```

Puis tester manuellement :

1. connexion ;
2. déconnexion ;
3. changement de rôle ;
4. consultation élève ;
5. notes/bulletins ;
6. finance ;
7. internat ;
8. documents ;
9. restauration ;
10. IA ;
11. permissions parent/enseignant/comptable ;
12. refus d'accès aux routes non autorisées.

## 8. Sauvegardes

Activer les sauvegardes du projet de production et vérifier régulièrement la restauration. Pour les projets utilisant des fonctions métier critiques, documenter le RPO/RTO choisi par l'établissement.

Les sauvegardes Supabase de base de données ne remplacent pas une stratégie de stockage des fichiers : les objets Storage doivent également être protégés et leur restauration testée.

## 9. Rollback

### Code frontend
Revenir au déploiement Vercel précédent ou au tag Git précédent.

### Base de données
Ne jamais annuler une migration déjà appliquée par un simple `git revert`. Créer une nouvelle migration corrective. Pour une restauration de base, suivre la procédure de restauration Supabase appropriée et accepter le temps d'indisponibilité nécessaire.

## 10. Règles absolues

- aucun secret dans Git ;
- aucune donnée réelle dans les seeds de développement ;
- aucune écriture directe de schéma distant ;
- aucune modification métier par l'IA ;
- aucune clé secrète en `NEXT_PUBLIC_*` ;
- une seule personne/processus déploie les migrations de production à la fois ;
- toute modification passe par Git + migration + validation.
