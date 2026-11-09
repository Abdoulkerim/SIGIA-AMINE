BEGIN;

-- Supprimer l'ancienne version avant de modifier son type de retour.
DROP FUNCTION IF EXISTS public.list_wushu_coaches();

CREATE FUNCTION public.list_wushu_coaches()
RETURNS TABLE (
    id uuid,
    first_name text,
    last_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_school_id uuid;
BEGIN
    SELECT u.school_id
    INTO v_school_id
    FROM public.users u
    WHERE u.id = (SELECT auth.uid())
      AND u.status = 'active';

    IF v_school_id IS NULL THEN
        RAISE EXCEPTION 'USER_WITHOUT_SCHOOL';
    END IF;

    IF NOT (
        app.is_super_admin()
        OR app.has_permission('wushu.view', v_school_id)
        OR app.has_permission('wushu.manage', v_school_id)
        OR app.has_role_code('direction', v_school_id)
        OR app.has_role_code('founder', v_school_id)
    ) THEN
        RAISE EXCEPTION 'INSUFFICIENT_WUSHU_PERMISSION';
    END IF;

    RETURN QUERY
    SELECT
        e.id,
        e.first_name,
        e.last_name
    FROM public.employees e
    WHERE e.school_id = v_school_id
      AND e.status = 'active'
    ORDER BY e.last_name, e.first_name;
END;
$$;

REVOKE ALL ON FUNCTION public.list_wushu_coaches()
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_wushu_coaches()
TO authenticated;

COMMIT;