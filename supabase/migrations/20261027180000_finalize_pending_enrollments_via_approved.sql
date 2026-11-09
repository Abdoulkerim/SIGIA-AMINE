BEGIN;

CREATE OR REPLACE FUNCTION public.finalize_enrollment(
    p_enrollment_id uuid,
    p_class_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_school_id uuid;
    v_enrollment public.enrollments%rowtype;
BEGIN
    -- Vérifier l'authentification.
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'FORBIDDEN_ENROLLMENT_MANAGE';
    END IF;

    IF p_enrollment_id IS NULL THEN
        RAISE EXCEPTION 'ENROLLMENT_NOT_FOUND';
    END IF;

    IF p_class_id IS NULL THEN
        RAISE EXCEPTION 'CLASS_REQUIRED_TO_FINALIZE';
    END IF;

    -- Première lecture sans verrouillage.
    SELECT e.school_id
    INTO v_school_id
    FROM public.enrollments AS e
    WHERE e.id = p_enrollment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ENROLLMENT_NOT_FOUND';
    END IF;

    -- Vérifier les droits avant de verrouiller l'inscription.
    IF NOT COALESCE(
        app.has_permission('enrollments.manage', v_school_id),
        false
    )
    AND NOT COALESCE(app.is_super_admin(), false) THEN
        RAISE EXCEPTION 'FORBIDDEN_ENROLLMENT_MANAGE';
    END IF;

    -- Verrouiller l'inscription.
    SELECT e.*
    INTO v_enrollment
    FROM public.enrollments AS e
    WHERE e.id = p_enrollment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ENROLLMENT_NOT_FOUND';
    END IF;

    -- Revérifier les droits après verrouillage.
    IF NOT COALESCE(
        app.has_permission(
            'enrollments.manage',
            v_enrollment.school_id
        ),
        false
    )
    AND NOT COALESCE(app.is_super_admin(), false) THEN
        RAISE EXCEPTION 'FORBIDDEN_ENROLLMENT_MANAGE';
    END IF;

    -- Vérifier que la classe appartient au bon établissement
    -- et à la bonne année scolaire.
    PERFORM 1
    FROM public.classes AS c
    WHERE c.id = p_class_id
      AND c.school_id = v_enrollment.school_id
      AND c.school_year_id = v_enrollment.school_year_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CLASS_NOT_VALID_FOR_ENROLLMENT';
    END IF;

    -- Vérifier le statut actuel.
    IF v_enrollment.status IS NULL
       OR v_enrollment.status NOT IN ('pending', 'approved') THEN
        RAISE EXCEPTION 'ENROLLMENT_NOT_READY_TO_FINALIZE';
    END IF;

    -- Première transition : pending vers approved.
    IF v_enrollment.status = 'pending' THEN
        UPDATE public.enrollments
        SET class_id = p_class_id,
            status = 'approved',
            updated_at = pg_catalog.now()
        WHERE id = p_enrollment_id;
    ELSE
        -- L'inscription est déjà approuvée.
        UPDATE public.enrollments
        SET class_id = p_class_id,
            updated_at = pg_catalog.now()
        WHERE id = p_enrollment_id;
    END IF;

    -- Deuxième transition : approved vers enrolled.
    UPDATE public.enrollments
    SET status = 'enrolled',
        updated_at = pg_catalog.now()
    WHERE id = p_enrollment_id;

    RETURN pg_catalog.jsonb_build_object(
        'enrollment_id', p_enrollment_id,
        'status', 'enrolled'
    );
END;
$$;

-- Retirer les droits publics et anonymes.
REVOKE ALL ON FUNCTION
    public.finalize_enrollment(uuid, uuid)
FROM PUBLIC, anon;

-- Autoriser les utilisateurs authentifiés.
GRANT EXECUTE ON FUNCTION
    public.finalize_enrollment(uuid, uuid)
TO authenticated, service_role;

COMMIT;