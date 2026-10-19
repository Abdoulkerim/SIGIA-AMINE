
CREATE OR REPLACE FUNCTION public.create_economic_activity_site(
  p_activity_id uuid,
  p_code text,
  p_name text,
  p_site_type text DEFAULT NULL,
  p_location_description text DEFAULT NULL,
  p_area numeric DEFAULT NULL,
  p_area_unit text DEFAULT NULL,
  p_responsible_employee_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  sid uuid;
  eschool uuid;
  x uuid;
BEGIN
  IF NOT app.activity_manage_permission(p_activity_id) THEN
    RAISE EXCEPTION 'ACTIVITY_SITE_FORBIDDEN';
  END IF;

  SELECT school_id
  INTO sid
  FROM public.economic_activities
  WHERE id = p_activity_id;

  IF p_area IS NOT NULL AND p_area < 0 THEN
    RAISE EXCEPTION 'ACTIVITY_SITE_AREA_INVALID';
  END IF;

  IF p_responsible_employee_id IS NOT NULL THEN
    SELECT school_id
    INTO eschool
    FROM public.employees
    WHERE id = p_responsible_employee_id;

    IF eschool <> sid THEN
      RAISE EXCEPTION 'ACTIVITY_SITE_RESPONSIBLE_CROSS_SCHOOL';
    END IF;
  END IF;

  INSERT INTO public.economic_activity_sites (
    school_id,
    activity_id,
    code,
    name,
    site_type,
    location_description,
    area,
    area_unit,
    responsible_employee_id
  )
  VALUES (
    sid,
    p_activity_id,
    TRIM(p_code),
    TRIM(p_name),
    NULLIF(TRIM(p_site_type), ''),
    NULLIF(TRIM(p_location_description), ''),
    p_area,
    NULLIF(TRIM(p_area_unit), ''),
    p_responsible_employee_id
  )
  RETURNING id INTO x;

  RETURN x;
END;
$function$;
