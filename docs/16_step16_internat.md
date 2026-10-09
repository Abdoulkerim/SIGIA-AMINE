# SIGIA-AMINE — Étape 16 : Internat

## 1. Périmètre

Cette étape implémente uniquement le module **Internat**. La restauration, Tahfiz, Wushu et les autres services restent dans les étapes suivantes.

Le cahier des charges Al Amine prévoit pour l’internat :
- bâtiments et dortoirs ;
- chambres et lits ;
- affectation des élèves ;
- présence ;
- sorties et retours ;
- autorisations ;
- discipline/incidents ;
- responsables et surveillants.

## 2. Chaîne fonctionnelle

Élève interne → bâtiment → dortoir → chambre → lit → affectation → présence → sortie/retour → historique.

## 3. Sécurité

Les mutations de l’internat passent par des RPC `SECURITY DEFINER` à `search_path=''`. Les tables sont exposées en lecture via RLS, tandis que les INSERT/UPDATE/DELETE directs du rôle `authenticated` sont retirés pour les objets sensibles.

Permission principale : `boarding.manage`.
Permission de consultation : `boarding.view`.

Le rôle `boarding_manager` reçoit les deux permissions. Direction, fondateur et super-admin sont également couverts.

## 4. Règles métier

### Élèves
- seul un élève actif peut être affecté ;
- l’élève doit être marqué `residence_type = internal` ;
- l’élève, le lit et la structure doivent appartenir à la même école ;
- le sexe du dortoir est contrôlé lorsque sexe élève/dortoir sont renseignés.

### Lits
- un lit `maintenance` ou `inactive` ne peut pas être affecté ;
- une chambre ne peut pas recevoir plus de lits que sa capacité ;
- un élève ne peut pas avoir deux affectations qui se chevauchent ;
- un lit ne peut pas avoir deux affectations qui se chevauchent ;
- une seule affectation active ouverte est autorisée par élève et par lit.

### Mouvements
- `entry` = entrée à l’internat ;
- `exit` = sortie ;
- `temporary_leave` = sortie temporaire nécessitant une autorisation ;
- `return` = retour après une sortie/sortie temporaire ;
- une sortie temporaire/sortie ne peut pas être répétée avant un retour ;
- un retour sans mouvement précédent `exit`/`temporary_leave` est refusé.

### Présence
La présence d’internat est enregistrable uniquement pour un élève disposant d’une affectation active couvrant la date saisie.

## 5. RPC livrées

- `create_boarding_building`
- `create_boarding_dormitory`
- `create_boarding_room`
- `create_boarding_bed`
- `assign_boarding_bed`
- `close_boarding_assignment`
- `record_boarding_movement`
- `set_boarding_attendance`
- `get_boarding_dashboard`
- `get_student_boarding`

## 6. Interfaces

- `/internat` : tableau de bord et affectations actives
- `/internat/structures` : bâtiments, dortoirs, chambres et lits
- `/internat/affectations` : affectations et fin d’affectation
- `/internat/mouvements` : sorties, retours et historique
- `/internat/presences` : présence quotidienne des internes

## 7. Limites volontairement conservées

Le cahier des charges ne fournit pas de règlement interne détaillé sur : heures limites de sortie, liste officielle des motifs, workflow disciplinaire spécifique de l’internat ou catégories d’autorisations. Ces paramètres ne sont donc pas inventés dans cette étape.
