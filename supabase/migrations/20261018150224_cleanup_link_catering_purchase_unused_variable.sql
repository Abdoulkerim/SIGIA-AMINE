
CREATE OR REPLACE FUNCTION public.link_catering_purchase(
  p_menu_item_id uuid,
  p_purchase_order_id uuid,
  p_product_id uuid,
  p_quantity numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_po_school uuid;
  v_product_school uuid;
  v_menu_school uuid;
BEGIN
  SELECT m.school_id
  INTO v_menu_school
  FROM public.menu_items mi
  JOIN public.menus m ON m.id = mi.menu_id
  WHERE mi.id = p_menu_item_id;

  SELECT school_id
  INTO v_po_school
  FROM public.purchase_orders
  WHERE id = p_purchase_order_id;

  SELECT school_id
  INTO v_product_school
  FROM public.products
  WHERE id = p_product_id;

  IF v_menu_school IS NULL
     OR v_po_school IS NULL
     OR v_product_school IS NULL
     OR v_menu_school <> v_po_school
     OR v_menu_school <> v_product_school
  THEN
    RAISE EXCEPTION 'CATERING_PURCHASE_CONTEXT_INVALID';
  END IF;

  IF NOT (
    app.catering_has_manage(v_menu_school)
    OR app.has_permission('purchases.manage', v_menu_school)
  ) THEN
    RAISE EXCEPTION 'CATERING_PURCHASE_FORBIDDEN';
  END IF;

  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'CATERING_PURCHASE_QUANTITY_INVALID';
  END IF;

  INSERT INTO public.catering_purchase_links (
    school_id,
    menu_item_id,
    purchase_order_id,
    product_id,
    quantity
  )
  VALUES (
    v_menu_school,
    p_menu_item_id,
    p_purchase_order_id,
    p_product_id,
    p_quantity
  )
  ON CONFLICT (menu_item_id, purchase_order_id, product_id)
  DO UPDATE SET quantity = EXCLUDED.quantity
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
