BEGIN;

CREATE OR REPLACE FUNCTION public.update_boarding_structure(
    p_entity text,
    p_id uuid,
    p_values jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_school uuid;
    v_building uuid;
    v_dormitory uuid;
    v_room uuid;
    v_capacity integer;
    v_bed_count bigint;
BEGIN
    -- Vérifier l'authentification.
    IF (SELECT auth.uid()) IS NULL THEN
        RAISE EXCEPTION 'AUTH_REQUIRED';
    END IF;

    -- Identifier l'établissement concerné.
    IF p_entity = 'building' THEN
        SELECT school_id
        INTO v_school
        FROM public.boarding_buildings
        WHERE id = p_id
        FOR UPDATE;

    ELSIF p_entity = 'dormitory' THEN
        SELECT b.school_id
        INTO v_school
        FROM public.boarding_dormitories d
        JOIN public.boarding_buildings b ON b.id = d.building_id
        WHERE d.id = p_id
        FOR UPDATE OF d;

    ELSIF p_entity = 'room' THEN
        SELECT b.school_id
        INTO v_school
        FROM public.boarding_rooms r
        JOIN public.boarding_dormitories d ON d.id = r.dormitory_id
        JOIN public.boarding_buildings b ON b.id = d.building_id
        WHERE r.id = p_id
        FOR UPDATE OF r;

    ELSIF p_entity = 'bed' THEN
        SELECT b.school_id
        INTO v_school
        FROM public.boarding_beds bed
        JOIN public.boarding_rooms r ON r.id = bed.room_id
        JOIN public.boarding_dormitories d ON d.id = r.dormitory_id
        JOIN public.boarding_buildings b ON b.id = d.building_id
        WHERE bed.id = p_id
        FOR UPDATE OF bed;

    ELSE
        RAISE EXCEPTION 'BOARDING_INVALID_ENTITY';
    END IF;

    IF v_school IS NULL THEN
        RAISE EXCEPTION 'BOARDING_STRUCTURE_NOT_FOUND';
    END IF;

    -- Vérifier les autorisations.
    IF NOT COALESCE(
        app.is_super_admin()
        OR app.has_permission('boarding.manage', v_school)
        OR app.has_role_code('direction', v_school)
        OR app.has_role_code('founder', v_school),
        false
    ) THEN
        RAISE EXCEPTION 'BOARDING_FORBIDDEN';
    END IF;

    -- Modifier un bâtiment.
    IF p_entity = 'building' THEN

        UPDATE public.boarding_buildings
        SET code = trim(p_values->>'code'),
            name = trim(p_values->>'name'),
            description = nullif(trim(p_values->>'description'), '')
        WHERE id = p_id;

    -- Modifier un dortoir.
    ELSIF p_entity = 'dormitory' THEN

        v_building := (p_values->>'buildingId')::uuid;

        IF NOT EXISTS (
            SELECT 1
            FROM public.boarding_buildings
            WHERE id = v_building
              AND school_id = v_school
        ) THEN
            RAISE EXCEPTION 'BOARDING_BUILDING_NOT_FOUND';
        END IF;

        UPDATE public.boarding_dormitories
        SET building_id = v_building,
            name = trim(p_values->>'name'),
            gender = nullif(p_values->>'gender', '')::app.gender_type
        WHERE id = p_id;

    -- Modifier une chambre.
    ELSIF p_entity = 'room' THEN

        v_dormitory := (p_values->>'dormitoryId')::uuid;
        v_capacity := (p_values->>'capacity')::integer;

        IF NOT EXISTS (
            SELECT 1
            FROM public.boarding_dormitories d
            JOIN public.boarding_buildings b ON b.id = d.building_id
            WHERE d.id = v_dormitory
              AND b.school_id = v_school
        ) THEN
            RAISE EXCEPTION 'BOARDING_DORMITORY_NOT_FOUND';
        END IF;

        IF v_capacity IS NULL OR v_capacity <= 0 THEN
            RAISE EXCEPTION 'BOARDING_CAPACITY_INVALID';
        END IF;

        SELECT count(*)
        INTO v_bed_count
        FROM public.boarding_beds
        WHERE room_id = p_id;

        IF v_capacity < v_bed_count THEN
            RAISE EXCEPTION 'BOARDING_CAPACITY_BELOW_BEDS';
        END IF;

        UPDATE public.boarding_rooms
        SET dormitory_id = v_dormitory,
            name = trim(p_values->>'name'),
            capacity = v_capacity,
            floor = nullif(trim(p_values->>'floor'), ''),
            status = p_values->>'status'
        WHERE id = p_id;

    -- Modifier ou déplacer un lit.
    ELSIF p_entity = 'bed' THEN

        v_room := (p_values->>'roomId')::uuid;

        -- Verrouiller la chambre cible.
        SELECT r.capacity
        INTO v_capacity
        FROM public.boarding_rooms r
        JOIN public.boarding_dormitories d ON d.id = r.dormitory_id
        JOIN public.boarding_buildings b ON b.id = d.building_id
        WHERE r.id = v_room
          AND b.school_id = v_school
        FOR UPDATE OF r;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'BOARDING_ROOM_NOT_FOUND';
        END IF;

        -- Compter les autres lits déjà présents.
        SELECT count(*)
        INTO v_bed_count
        FROM public.boarding_beds
        WHERE room_id = v_room
          AND id <> p_id;

        IF v_capacity IS NULL OR v_bed_count >= v_capacity THEN
            RAISE EXCEPTION 'BOARDING_ROOM_CAPACITY_REACHED';
        END IF;

        UPDATE public.boarding_beds
        SET room_id = v_room,
            bed_number = trim(p_values->>'bedNumber'),
            status = p_values->>'status'
        WHERE id = p_id;

    END IF;
END;
$$;

-- Retirer les permissions publiques et anonymes.
REVOKE ALL ON FUNCTION
    public.update_boarding_structure(text, uuid, jsonb)
FROM PUBLIC, anon;

-- Autoriser les utilisateurs authentifiés.
GRANT EXECUTE ON FUNCTION
    public.update_boarding_structure(text, uuid, jsonb)
TO authenticated;

COMMIT;