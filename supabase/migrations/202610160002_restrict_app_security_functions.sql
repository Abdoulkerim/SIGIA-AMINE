
BEGIN;

-- 1. Réserver la gestion des rôles aux utilisateurs connectés
ALTER POLICY user_roles_manage_secure
ON public.user_roles
TO authenticated;

ALTER POLICY user_roles_select_secure
ON public.user_roles
TO authenticated;

-- 2. Réserver la gestion des comptes aux utilisateurs connectés
ALTER POLICY users_delete_admin
ON public.users
TO authenticated;

ALTER POLICY users_insert_admin
ON public.users
TO authenticated;

ALTER POLICY users_select_secure
ON public.users
TO authenticated;

ALTER POLICY users_update_self_or_admin
ON public.users
TO authenticated;

-- 3. Restreindre l'exécution des fonctions de sécurité
REVOKE EXECUTE ON FUNCTION app.has_permission(text, uuid)
FROM PUBLIC, anon;

REVOKE EXECUTE ON FUNCTION app.has_role_code(text, uuid)
FROM PUBLIC, anon;

REVOKE EXECUTE ON FUNCTION app.is_super_admin()
FROM PUBLIC, anon;

-- 4. Conserver l'exécution pour le personnel connecté
GRANT EXECUTE ON FUNCTION app.has_permission(text, uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION app.has_role_code(text, uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION app.is_super_admin()
TO authenticated;


-- 5. Retirer les privilèges directs des visiteurs
-- sur les comptes et les rôles
REVOKE ALL PRIVILEGES
ON TABLE public.users, public.user_roles
FROM anon;

-- 6. Retirer les privilèges structurels inutiles
-- aux utilisateurs connectés
REVOKE TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.users, public.user_roles
FROM authenticated;

-- 7. Retirer les privilèges anonymes
-- sur les données internes et sensibles.

REVOKE ALL PRIVILEGES ON TABLE
    public.academic_periods,
    public.admission_applications,
    public.agriculture_campaigns,
    public.agriculture_expenses,
    public.announcement_deliveries,
    public.arabic_evaluations,
    public.arabic_levels,
    public.arabic_progress_history,
    public.arabic_sessions,
    public.audit_logs,
    public.authorized_pickup_persons,
    public.boarding_assignments,
    public.boarding_attendance,
    public.boarding_beds,
    public.documents,
    public.invoices,
    public.parents,
    public.payments,
    public.students
FROM anon;

-- 8. Les visiteurs peuvent uniquement lire les annonces.
-- La politique RLS doit limiter cette lecture aux annonces
-- réellement publiées et destinées au public.

REVOKE ALL PRIVILEGES
ON TABLE public.announcements
FROM anon;

GRANT SELECT
ON TABLE public.announcements
TO anon;

-- 9. Retirer les privilèges structurels inutiles
-- au personnel connecté.

REVOKE TRUNCATE, REFERENCES, TRIGGER
ON TABLE
    public.admission_applications,
    public.announcements,
    public.audit_logs,
    public.documents,
    public.invoices,
    public.parents,
    public.payments,
    public.students
FROM authenticated;

-- 12. Limiter les privilèges par défaut sur les futures tables
-- créées par postgres dans le schéma public.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
IN SCHEMA public
REVOKE DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLES
FROM anon, authenticated;

-- 13. Limiter les privilèges par défaut sur les futures séquences.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
IN SCHEMA public
REVOKE UPDATE
ON SEQUENCES
FROM anon, authenticated;

-- 14. Réserver les fonctions de gestion des annonces
-- aux utilisateurs authentifiés.

REVOKE EXECUTE ON FUNCTION
    public.create_announcement(text, text, jsonb, timestamptz)
FROM PUBLIC, anon;

REVOKE EXECUTE ON FUNCTION
    public.publish_announcement(uuid)
FROM PUBLIC, anon;

REVOKE EXECUTE ON FUNCTION
    public.archive_announcement(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    public.create_announcement(text, text, jsonb, timestamptz)
TO authenticated;

GRANT EXECUTE ON FUNCTION
    public.publish_announcement(uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION
    public.archive_announcement(uuid)
TO authenticated;

COMMIT;
