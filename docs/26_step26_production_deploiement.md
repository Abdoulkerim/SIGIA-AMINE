# Étape 26 — Production / déploiement final

## Objectif

Transformer le projet SIGIA-AMINE de l'environnement de développement en une release exploitable en production, avec séparation staging/production, migrations versionnées, déploiement Next.js, Edge Function IA, gestion des secrets, sauvegardes et smoke tests.

## Livrables

- runbook de production ;
- checklist de go-live ;
- matrice des environnements ;
- workflow CI ;
- workflow de déploiement Supabase ;
- scripts de preflight et smoke test ;
- endpoint `/api/health` ;
- headers de sécurité Next.js ;
- exemples d'environnements production ;
- dépendances principales figées ;
- aucune nouvelle migration SQL ajoutée par l'étape 26.

## Important

Le cahier des charges demande un système évolutif, centralisé, sécurisé et progressivement déployé. Il ne donne pas de fournisseur d'hébergement obligatoire, de domaine, de formule de sauvegarde, ni de seuil d'exploitation. Ces éléments restent donc des choix de déploiement à valider par l'équipe.

## Ordre de mise en production

1. valider localement ;
2. déployer sur staging ;
3. exécuter les tests fonctionnels ;
4. vérifier Security Advisor et RLS ;
5. geler la release ;
6. pousser les migrations sur production ;
7. déployer l'Edge Function ;
8. configurer les secrets ;
9. déployer Next.js ;
10. exécuter les smoke tests ;
11. ouvrir progressivement aux utilisateurs.

Voir `PRODUCTION_RUNBOOK.md` pour les commandes détaillées.
