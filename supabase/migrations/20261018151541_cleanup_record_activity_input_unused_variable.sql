
CREATE OR REPLACE FUNCTION public.record_activity_input(
  p_activity_id uuid,
  p_product_id uuid,
  p_stock_location_id uuid,
  p_quantity numeric,
  p_unit_cost numeric DEFAULT NULL,
  p_site_id uuid DEFAULT NULL,
  p_campaign_id uuid DEFAULT NULL,
  p_livestock_id uuid DEFAULT NULL,
  p_input_date date DEFAULT CURRENT_DATE,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  sid uuid;
  ps uuid;
  ls uuid;
  iid uuid;
  sm uuid;
BEGIN
  IF NOT app.activity_manage_permission(p_activity_id) THEN
    RAISE EXCEPTION 'ACTIVITY_INPUT_FORBIDDEN';
  END IF;

  SELECT school_id
  INTO sid
  FROM public.economic_activities
  WHERE id = p_activity_id;

  SELECT school_id
  INTO ps
  FROM public.products
  WHERE id = p_product_id;

  SELECT school_id
  INTO ls
  FROM public.stock_locations
  WHERE id = p_stock_location_id;

  IF ps <> sid OR ls <> sid THEN
    RAISE EXCEPTION 'ACTIVITY_INPUT_STOCK_CROSS_SCHOOL';
  END IF;

  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'ACTIVITY_INPUT_QUANTITY_INVALID';
  END IF;

  IF p_unit_cost IS NOT NULL AND p_unit_cost < 0 THEN
    RAISE EXCEPTION 'ACTIVITY_INPUT_COST_INVALID';
  END IF;

  sm := public.record_stock_movement(
    p_product_id,
    p_stock_location_id,
    'issue'::app.stock_movement_type,
    p_quantity,
    p_unit_cost,
    p_notes
  );

  INSERT INTO public.economic_activity_inputs (
    school_id,
    activity_id,
    site_id,
    campaign_id,
    livestock_id,
    product_id,
    stock_location_id,
    quantity,
    unit_cost,
    input_date,
    stock_movement_id,
    notes,
    created_by
  )
  VALUES (
    sid,
    p_activity_id,
    p_site_id,
    p_campaign_id,
    p_livestock_id,
    p_product_id,
    p_stock_location_id,
    p_quantity,
    p_unit_cost,
    p_input_date,
    sm,
    NULLIF(TRIM(p_notes), ''),
    auth.uid()
  )
  RETURNING id INTO iid;

  RETURN iid;
END;
$function$;
