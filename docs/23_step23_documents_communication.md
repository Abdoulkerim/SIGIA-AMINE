# Étape 23 — Documents / Communication

## Périmètre
Le cahier des charges Al Amine prévoit pour les documents : dossier d'inscription, fiche d'inscription, certificat de scolarité, attestations, autres documents administratifs, classement, archivage et recherche. Il prévoit également un historique administratif de l'élève. Pour la communication : notifications et annonces, convocations et rappels, informations aux parents, résultats, reçus, attestations et communications internes.

## Livrables
- Migration `202609260031_documents_communication_workflows.sql`.
- Versionnement documentaire, demandes de documents et journal d'accès.
- Annonces publiables avec ciblage contrôlé.
- Notifications in-app et file de livraison externe (`email`, `sms`, `whatsapp`, `push`) en attente d'un fournisseur.
- RLS et fonctions SECURITY DEFINER pour les opérations sensibles.
- Stockage privé `school-documents` durci sur le chemin `school_id/document_id/file`.
- Interfaces Documents / Communication.

## Ciblage des annonces
Formats supportés : `all_users`, `all_staff`, `all_parents`, `class`, `role`, `users`.
Pour `class`, `class_id` et `school_year_id` sont obligatoires.

## Limites fonctionnelles
Le cahier des charges ne définit pas de fournisseur SMS, WhatsApp, e-mail ou push. Le système crée donc les notifications in-app et met les autres canaux en file `queued`; leur envoi réel sera raccordé au module de communication externe ultérieur.

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
