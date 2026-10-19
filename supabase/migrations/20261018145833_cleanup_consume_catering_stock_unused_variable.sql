
CREATE OR REPLACE FUNCTION public.consume_catering_stock(
  p_menu_item_id uuid,
  p_product_id uuid,
  p_location_id uuid,
  p_quantity numeric,
  p_unit_cost numeric DEFAULT 0,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_school uuid;
  v_product_school uuid;
  v_location_school uuid;
  v_movement_id uuid;
  v_balance numeric;
BEGIN
  SELECT m.school_id
  INTO v_school
  FROM public.menu_items mi
  JOIN public.menus m ON m.id = mi.menu_id
  WHERE mi.id = p_menu_item_id;

  SELECT school_id
  INTO v_product_school
  FROM public.products
  WHERE id = p_product_id
    AND is_active;

  SELECT school_id
  INTO v_location_school
  FROM public.stock_locations
  WHERE id = p_location_id;

  IF v_school IS NULL
     OR v_product_school IS NULL
     OR v_product_school <> v_school
     OR v_location_school IS NULL
     OR v_location_school <> v_school
  THEN
    RAISE EXCEPTION 'CATERING_STOCK_CONTEXT_INVALID';
  END IF;

  IF NOT (
    app.catering_has_manage(v_school)
    OR app.has_permission('stock.manage', v_school)
  ) THEN
    RAISE EXCEPTION 'CATERING_STOCK_FORBIDDEN';
  END IF;

  IF p_quantity <= 0 OR p_unit_cost < 0 THEN
    RAISE EXCEPTION 'CATERING_STOCK_QUANTITY_INVALID';
  END IF;

  SELECT quantity
  INTO v_balance
  FROM public.stock_balances
  WHERE product_id = p_product_id
    AND location_id = p_location_id
  FOR UPDATE;

  IF COALESCE(v_balance, 0) < p_quantity THEN
    RAISE EXCEPTION 'CATERING_STOCK_INSUFFICIENT';
  END IF;

  INSERT INTO public.stock_movements (
    school_id,
    product_id,
    location_id,
    movement_type,
    quantity,
    unit_cost,
    reference_type,
    reference_id,
    created_by,
    notes
  )
  VALUES (
    v_school,
    p_product_id,
    p_location_id,
    'issue',
    p_quantity,
    p_unit_cost,
    'catering_menu_item',
    p_menu_item_id,
    auth.uid(),
    NULLIF(TRIM(p_notes), '')
  )
  RETURNING id INTO v_movement_id;

  INSERT INTO public.catering_consumptions (
    school_id,
    menu_item_id,
    product_id,
    location_id,
    stock_movement_id,
    quantity,
    unit_cost,
    created_by,
    notes
  )
  VALUES (
    v_school,
    p_menu_item_id,
    p_product_id,
    p_location_id,
    v_movement_id,
    p_quantity,
    p_unit_cost,
    auth.uid(),
    NULLIF(TRIM(p_notes), '')
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
