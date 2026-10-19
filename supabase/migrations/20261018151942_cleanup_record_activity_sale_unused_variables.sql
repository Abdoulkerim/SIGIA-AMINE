
CREATE OR REPLACE FUNCTION public.record_activity_sale(
  p_sale_number text,
  p_activity_id uuid DEFAULT NULL,
  p_sale_date date DEFAULT CURRENT_DATE,
  p_customer_name text DEFAULT NULL,
  p_payment_method app.payment_method DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_items jsonb DEFAULT '[]'::jsonb,
  p_cash_transaction_id uuid DEFAULT NULL,
  p_activity_reference text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  sid uuid;
  saleid uuid;
  item jsonb;
  product_id uuid;
  production_id uuid;
  location_id uuid;
  qty numeric;
  unit text;
  price numeric;
  total numeric := 0;
  sm uuid;
  cs uuid;
BEGIN
  SELECT school_id
  INTO sid
  FROM public.economic_activities
  WHERE id = p_activity_id;

  IF p_activity_id IS NOT NULL
     AND NOT app.activity_manage_permission(p_activity_id)
  THEN
    RAISE EXCEPTION 'SALE_FORBIDDEN';
  END IF;

  IF p_activity_id IS NULL THEN
    SELECT school_id
    INTO sid
    FROM public.users
    WHERE id = auth.uid();

    IF sid IS NULL
       OR NOT (
         app.has_permission('agriculture.manage', sid)
         OR app.has_permission('livestock.manage', sid)
         OR app.is_super_admin()
       )
    THEN
      RAISE EXCEPTION 'SALE_FORBIDDEN';
    END IF;
  END IF;

  IF p_cash_transaction_id IS NOT NULL THEN
    SELECT school_id
    INTO cs
    FROM public.cash_transactions
    WHERE id = p_cash_transaction_id;

    IF cs <> sid THEN
      RAISE EXCEPTION 'SALE_CASH_CROSS_SCHOOL';
    END IF;
  END IF;

  IF jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0
  THEN
    RAISE EXCEPTION 'SALE_ITEMS_EMPTY';
  END IF;

  INSERT INTO public.sales (
    school_id,
    activity_id,
    sale_number,
    sale_date,
    customer_name,
    amount,
    payment_method,
    description,
    cash_transaction_id,
    activity_reference
  )
  VALUES (
    sid,
    p_activity_id,
    TRIM(p_sale_number),
    p_sale_date,
    NULLIF(TRIM(p_customer_name), ''),
    0,
    p_payment_method,
    NULLIF(TRIM(p_description), ''),
    p_cash_transaction_id,
    NULLIF(TRIM(p_activity_reference), '')
  )
  RETURNING id INTO saleid;

  FOR item IN
    SELECT value
    FROM jsonb_array_elements(p_items)
  LOOP
    product_id := NULLIF(item->>'product_id', '')::uuid;
    production_id := NULLIF(item->>'production_id', '')::uuid;
    location_id := NULLIF(item->>'stock_location_id', '')::uuid;
    qty := (item->>'quantity')::numeric;
    unit := COALESCE(NULLIF(TRIM(item->>'unit'), ''), 'unit');
    price := (item->>'unit_price')::numeric;

    IF qty IS NULL OR qty <= 0 OR price IS NULL OR price < 0 THEN
      RAISE EXCEPTION 'SALE_ITEM_INVALID';
    END IF;

    IF product_id IS NOT NULL THEN
      IF location_id IS NULL THEN
        RAISE EXCEPTION 'SALE_LOCATION_REQUIRED';
      END IF;

      sm := public.record_stock_movement(
        product_id,
        location_id,
        'sale'::app.stock_movement_type,
        qty,
        price,
        'Vente: ' || TRIM(p_sale_number)
      );
    END IF;

    INSERT INTO public.sale_items (
      sale_id,
      product_id,
      production_id,
      stock_location_id,
      quantity,
      unit,
      unit_price,
      stock_movement_id,
      notes
    )
    VALUES (
      saleid,
      product_id,
      production_id,
      location_id,
      qty,
      unit,
      price,
      sm,
      NULLIF(TRIM(item->>'notes'), '')
    );

    total := total + (qty * price);
  END LOOP;

  UPDATE public.sales
  SET amount = ROUND(total, 2)
  WHERE id = saleid;

  RETURN saleid;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.record_activity_sale(
  text, uuid, date, text, app.payment_method, text, jsonb, uuid, text
) TO authenticated;
