# Étape 16 — Plan de validation

1. `npx supabase db reset`
2. `npx supabase test db --local`
3. `npx supabase db lint --local`
4. `npx supabase gen types typescript --local > src/types/database.types.ts`
5. `npm run typecheck`
6. `npm run build`
7. `npm run dev`

Tests fonctionnels à effectuer dans l’interface :

- créer un bâtiment ;
- créer un dortoir ;
- créer une chambre avec capacité ;
- créer les lits sans dépasser la capacité ;
- affecter un élève interne ;
- vérifier qu’un second lit ou une seconde affectation active est refusée ;
- clôturer l’affectation ;
- enregistrer une sortie temporaire avec autorisation ;
- vérifier que le retour sans sortie est refusé ;
- enregistrer le retour ;
- enregistrer la présence quotidienne ;
- vérifier qu’une présence hors période d’affectation est refusée ;
- contrôler le tableau de bord.
