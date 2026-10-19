
-- Correction des 4 erreurs restantes du lint local SIGIA-AMINE.
-- Cette migration ne modifie pas les données métier.

BEGIN;

-- 1. Corriger le type enum du statut de commande.
DO $migration$
DECLARE
    v_oid oid;
    v_definition text;
    v_updated text;
BEGIN
    SELECT p.oid
    INTO v_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'receive_purchase_order'
      AND p.prokind = 'f'
    ORDER BY p.oid
    LIMIT 1;

    IF v_oid IS NULL THEN
        RAISE EXCEPTION 'Fonction receive_purchase_order introuvable';
    END IF;

    v_definition := pg_get_functiondef(v_oid);

    v_updated := regexp_replace(
        v_definition,
        'SET status = CASE[[:space:]]+WHEN all_received THEN ''approved''[[:space:]]+ELSE ''submitted''[[:space:]]+END',
        'SET status = (CASE WHEN all_received THEN ''approved'' ELSE ''submitted'' END)::app.approval_status',
        'i'
    );

    IF v_updated = v_definition THEN
        RAISE EXCEPTION
            'Correction receive_purchase_order non appliquée : bloc CASE attendu introuvable';
    END IF;

    EXECUTE v_updated;
END;
$migration$;


-- 2. Corriger create_tahfiz_level : la table ne possède pas
-- de colonne description. Le paramètre reste présent pour
-- conserver la signature de la fonction et la compatibilité RPC.
CREATE OR REPLACE FUNCTION public.create_tahfiz_level(
    p_code text,
    p_name text,
    p_sequence_no integer DEFAULT 0,
    p_description text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_school uuid;
    v_id uuid;
BEGIN
    SELECT u.school_id
    INTO v_school
    FROM public.users u
    WHERE u.id = auth.uid();

    IF v_school IS NULL
       OR NOT app.has_permission('tahfiz.manage', v_school) THEN
        RAISE EXCEPTION 'Accès Tahfiz refusé';
    END IF;

    INSERT INTO public.tahfiz_levels (
        school_id,
        code,
        name,
        sequence_no
    )
    VALUES (
        v_school,
        btrim(p_code),
        btrim(p_name),
        coalesce(p_sequence_no, 0)
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$function$;


-- 3. Corriger get_dashboard_activities :
-- public.sales ne possède pas de colonne created_at.
-- On utilise id comme critère secondaire de tri sans l'ajouter
-- aux objets JSON retournés.
DO $migration$
DECLARE
    v_oid oid;
    v_definition text;
    v_updated text;
BEGIN
    SELECT p.oid
    INTO v_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_dashboard_activities'
      AND p.prokind = 'f'
    ORDER BY p.oid
    LIMIT 1;

    IF v_oid IS NULL THEN
        RAISE EXCEPTION 'Fonction get_dashboard_activities introuvable';
    END IF;

    v_definition := pg_get_functiondef(v_oid);

    v_updated := replace(
        v_definition,
        'select s.sale_date,s.sale_number,s.amount,ea.name activity_name,ea.activity_type',
        'select s.sale_date,s.sale_number,s.amount,ea.name activity_name,ea.activity_type,s.id as sort_id'
    );

    v_updated := replace(
        v_updated,
        'order by s.sale_date desc,s.created_at desc limit 15',
        'order by s.sale_date desc,s.id desc limit 15'
    );

    v_updated := replace(
        v_updated,
        'jsonb_agg(x order by x.sale_date desc)',
        'jsonb_agg(to_jsonb(x) - ''sort_id'' order by x.sale_date desc, x.sort_id desc)'
    );

    IF v_updated = v_definition THEN
        RAISE EXCEPTION
            'Correction get_dashboard_activities non appliquée : fragments attendus introuvables';
    END IF;

    IF position('s.created_at' IN v_updated) > 0 THEN
        RAISE EXCEPTION
            'get_dashboard_activities contient encore une référence à s.created_at';
    END IF;

    EXECUTE v_updated;
END;
$migration$;


-- 4. Corriger get_dashboard_direction :
-- la vue v_class_effectives fournit id, name et effective.
-- L'année scolaire et l'état actif sont filtrés depuis classes.
DO $migration$
DECLARE
    v_oid oid;
    v_definition text;
    v_updated text;
BEGIN
    SELECT p.oid
    INTO v_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_dashboard_direction'
      AND p.prokind = 'f'
    ORDER BY p.oid
    LIMIT 1;

    IF v_oid IS NULL THEN
        RAISE EXCEPTION 'Fonction get_dashboard_direction introuvable';
    END IF;

    v_definition := pg_get_functiondef(v_oid);

    v_updated := replace(
        v_definition,
        'select class_id,class_name,active_students from public.v_class_effectives where school_id=sid and school_year_id=current_year_id order by active_students desc,class_name limit 10',
        'select v.id AS class_id, v.name AS class_name, v.effective AS active_students from public.v_class_effectives v join public.classes c on c.id = v.id where v.school_id = sid and c.school_year_id = current_year_id and c.is_active = true order by v.effective desc, v.name limit 10'
    );

    IF v_updated = v_definition THEN
        RAISE EXCEPTION
            'Correction get_dashboard_direction non appliquée : requête top_classes attendue introuvable';
    END IF;

    EXECUTE v_updated;
END;
$migration$;

COMMIT;
