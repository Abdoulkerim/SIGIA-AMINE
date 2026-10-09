# SIGIA-AMINE — stratégie de migration

## Source de vérité
`supabase/migrations/` contient l’état versionné de PostgreSQL, RBAC, RLS et règles métier.

## Cycle obligatoire
1. Modifier le code SQL localement.
2. `supabase db reset`.
3. `supabase test db`.
4. `supabase db lint`.
5. Revue Git.
6. Push vers staging.
7. UAT.
8. Production.

## Multi-école
Les FK critiques portent ou héritent du `school_id`. Des triggers empêchent les relations inter-écoles.

## Autorisation
Auth → rôle → permission → action → RLS → périmètre de données.

## Historique
Les fichiers V1/hardening originaux restent dans `legacy/` pour comparaison et audit.
