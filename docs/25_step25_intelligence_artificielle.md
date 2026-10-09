# SIGIA-AMINE — Étape 25 : Intelligence artificielle

## Périmètre
Cette étape ajoute une couche d’assistance IA au-dessus des données déjà produites par les modules SIGIA-AMINE. Le cahier des charges prévoit que l’IA arrive après la centralisation des données et qu’elle puisse rechercher, analyser, comparer, alerter, générer et assister.

## Architecture
- Next.js : interface `/ia`, `/ia/alertes`, `/ia/prompts`.
- Supabase Edge Function : `supabase/functions/ai-assistant`.
- PostgreSQL : conversations, messages, exécutions, appels d’outils, prompts gouvernés et alertes.
- Fournisseur : OpenAI par défaut dans cette implémentation, configurable via `AI_MODEL` et `OPENAI_API_KEY`.

## Sécurité
Le fournisseur IA n’a jamais accès directement à la base. L’Edge Function appelle uniquement les fonctions/RPC de lecture prévues et vérifiées par les droits SIGIA-AMINE. Les outils `get_*_dashboard`, `search_students` et `get_student_summary` n’autorisent aucune écriture métier. Les alertes sont enregistrées comme signaux à valider.

Les secrets Edge Functions doivent rester dans les secrets Supabase et ne doivent jamais être mis dans `.env` côté navigateur.

## Capacités
1. Rechercher : retrouver des élèves accessibles à l’utilisateur.
2. Analyser : résultats, assiduité, finances, internat, activités.
3. Comparer : comparer uniquement les données réellement retournées.
4. Alerter : créer un signal `open` avec preuves et action de vérification.
5. Générer : produire un texte structuré à partir des données disponibles.
6. Assister : répondre aux questions de fonctionnement et de pilotage.

## Configuration locale
Créer `supabase/functions/.env` à partir de `supabase/functions/ai-assistant/.env.example` et renseigner :

```env
OPENAI_API_KEY=...
AI_MODEL=gpt-5.6-luna
```

Le fichier de secrets ne doit pas être commit.

## Déploiement
```powershell
npx supabase functions serve ai-assistant --env-file supabase/functions/.env
npx supabase secrets set --env-file supabase/functions/.env
npx supabase functions deploy ai-assistant
```

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

## Limites assumées
- Aucun calcul réglementaire ou juridique automatique n’est inventé.
- L’IA ne doit pas être utilisée seule pour prendre une décision sensible concernant un élève, un salarié ou un paiement.
- Les outils de lecture doivent continuer à être protégés par les permissions et RLS du projet.
