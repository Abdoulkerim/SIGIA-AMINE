# Étape 6 — Parents / Tuteurs

## Objectif
Gérer le dossier parent/tuteur et préparer la relation sécurisée parent ↔ enfant.

## 1. Aucun reset de schéma supplémentaire nécessaire
Les tables existent déjà : `parents`, `student_parents`, `authorized_pickup_persons`.
La migration 014 contient déjà les protections RLS / multi-écoles nécessaires.

## 2. Lancer depuis la racine
```powershell
cd "C:\CHEMIN\SIGIA-AMINE"
```

## 3. Vérifier la base locale
```powershell
npx supabase status
npx supabase db reset
npx supabase test db --local
npx supabase db lint --local
```

## 4. Générer les types après toute évolution SQL
```powershell
npx supabase gen types typescript --local > src/types/database.types.ts
```

## 5. Démarrer le frontend
```powershell
npm run typecheck
npm run build
npm run dev
```

## 6. URLs de test
- `/administration/parents`
- `/administration/parents/nouveau`
- `/administration/parents/:id`

## 7. Test fonctionnel
1. Se connecter avec l'administrateur de développement.
2. Ouvrir Parents / Tuteurs.
3. Créer un parent de test.
4. Ouvrir sa fiche.
5. Vérifier qu'aucun autre établissement n'est visible.
6. Réinitialiser la DB pour effacer les données de test quand nécessaire.

## 8. Prochaine liaison parent → enfant
Elle sera construite à l'étape 12 dans le dossier élève, avec contrôle `student_parents` et sans dupliquer les données du parent.
