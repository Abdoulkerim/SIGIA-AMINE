BEGIN;

CREATE OR REPLACE FUNCTION app.can_access_education_stage(
    p_school_id uuid,
    p_stage text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, app
AS $$
    SELECT
        -- Superadministrateur.
        app.is_super_admin()

        -- Fondateur : accès à tous les cycles de son établissement.
        OR (
            p_school_id IS NOT NULL
            AND app.normalize_education_stage(p_stage) IS NOT NULL
            AND app.has_role_code('founder', p_school_id)
        )

        -- Personnel : accès à son cycle affecté.
        -- Un parent ayant également un rôle professionnel
        -- conserve cet accès.
        OR (
            p_school_id IS NOT NULL
            AND app.normalize_education_stage(p_stage) IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM public.users u
                WHERE u.id = (SELECT auth.uid())
                  AND u.status = 'active'::app.user_status
                  AND u.school_id = p_school_id
                  AND u.education_stage =
                      app.normalize_education_stage(p_stage)
                  AND (
                      NOT app.has_role_code('parent', p_school_id)
                      OR EXISTS (
                          SELECT 1
                          FROM app.my_role_codes(p_school_id)
                               AS assigned_role(role_code)
                          WHERE assigned_role.role_code
                                NOT IN ('parent', 'student')
                      )
                  )
            )
        );
$$;

COMMIT;