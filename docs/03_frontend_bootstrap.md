# Étape 3 — Frontend Next.js + Supabase Auth

Le frontend utilise Next.js App Router et Supabase SSR. Les sessions Auth sont gérées par cookies. Dans Next.js 16, le fichier de rafraîchissement de session s'appelle `proxy.ts`.

## Installation

```powershell
npm install next@latest react@latest react-dom@latest @supabase/ssr @supabase/supabase-js zod
npm install --save-dev typescript @types/node @types/react @types/react-dom
```

Le projet contient `package.frontend.json` comme référence pour les scripts.

## Variables locales

Créer `.env.local` à la racine et remplir :

```env
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=COLLER_LA_CLE_ANON_LOCALE
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SECRET_KEY=COLLER_LA_CLE_SECRET_LOCALE
```

La connexion accepte l’adresse e-mail ou le nom d’utilisateur enregistré sur le profil. La résolution du nom d’utilisateur vers l’e-mail Auth utilise `SUPABASE_SECRET_KEY` côté serveur. Après avoir ajouté ou modifié cette variable, redémarrer Next.js. En hébergement, configurer la même variable dans l’environnement serveur de production; ne jamais utiliser le préfixe `NEXT_PUBLIC_` pour cette clé.

Ne jamais committer `.env.local`.

## Générer les types

Après `supabase start` et `supabase db reset` :

```powershell
npx supabase gen types typescript --local > src/types/database.types.ts
```

## Bootstrap du premier administrateur local

Récupérer les clés locales :

```powershell
npx supabase status -o env
```

Puis définir temporairement les variables dans le terminal PowerShell :

```powershell
$env:SUPABASE_URL='http://127.0.0.1:54321'
$env:SUPABASE_SERVICE_ROLE_KEY='COLLER_SERVICE_ROLE_KEY_LOCALE'
$env:ADMIN_EMAIL='admin@al-amine.local'
$env:ADMIN_PASSWORD='mot-de-passe-local-fort'
$env:ADMIN_FIRST_NAME='Administrateur'
$env:ADMIN_LAST_NAME='SIGIA'
$env:ADMIN_ROLE_CODE='founder'
$env:SCHOOL_CODE='AL-AMINE'
```

Puis :

```powershell
node scripts/bootstrap-admin.mjs
```

Le secret de bootstrap ne doit jamais être ajouté à Git ni envoyé au navigateur.

## Lancer le frontend

```powershell
npm run dev
```

Puis ouvrir `http://localhost:3000/login`.
