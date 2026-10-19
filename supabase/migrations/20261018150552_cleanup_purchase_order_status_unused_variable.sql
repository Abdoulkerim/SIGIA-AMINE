
CREATE OR REPLACE FUNCTION public.set_purchase_order_status(
  p_purchase_order_id uuid,
  p_status app.approval_status
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  sid uuid;
BEGIN
  SELECT school_id
  INTO sid
  FROM public.purchase_orders
  WHERE id = p_purchase_order_id
  FOR UPDATE;

  IF sid IS NULL
     OR NOT (
       app.has_permission('purchases.manage', sid)
       OR app.is_super_admin()
     )
  THEN
    RAISE EXCEPTION 'PURCHASE_ORDER_FORBIDDEN';
  END IF;

  IF p_status NOT IN (
    'submitted',
    'approved',
    'rejected',
    'cancelled'
  ) THEN
    RAISE EXCEPTION 'PURCHASE_ORDER_STATUS_INVALID';
  END IF;

  IF p_status = 'approved'
     AND NOT EXISTS (
       SELECT 1
       FROM public.purchase_items
       WHERE purchase_order_id = p_purchase_order_id
     )
  THEN
    RAISE EXCEPTION 'PURCHASE_ORDER_EMPTY';
  END IF;

  UPDATE public.purchase_orders
  SET status = p_status
  WHERE id = p_purchase_order_id;
END;
$function$;
