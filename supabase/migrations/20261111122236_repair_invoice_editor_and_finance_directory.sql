CREATE OR REPLACE FUNCTION public.update_invoice(
  p_invoice_id uuid,
  p_issue_date date,
  p_due_date date,
  p_notes text,
  p_items jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_school uuid;
  v_allocated boolean;
  v_item jsonb;
  v_description text;
  v_qty numeric;
  v_unit numeric;
  v_discount numeric;
  v_fee_type uuid;
BEGIN
  SELECT school_id INTO v_school
  FROM public.invoices
  WHERE id = p_invoice_id
  FOR UPDATE;

  IF v_school IS NULL THEN RAISE EXCEPTION 'INVOICE_NOT_FOUND'; END IF;
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT coalesce(app.is_super_admin() OR app.has_permission('finance.manage', v_school), false) THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;
  IF p_notes IS NOT NULL AND length(p_notes) > 500 THEN RAISE EXCEPTION 'INVALID_INVOICE_NOTES'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.payment_allocations WHERE invoice_id = p_invoice_id
  ) INTO v_allocated;

  IF p_items IS NOT NULL THEN
    IF v_allocated THEN RAISE EXCEPTION 'INVOICE_HAS_PAYMENTS_ITEMS_LOCKED'; END IF;
    IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
      RAISE EXCEPTION 'INVOICE_NEEDS_ITEMS';
    END IF;

    DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id;
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
      v_fee_type := nullif(v_item->>'fee_type_id', '')::uuid;
      IF v_fee_type IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.fee_types ft WHERE ft.id = v_fee_type AND ft.school_id = v_school
      ) THEN RAISE EXCEPTION 'FEE_TYPE_SCHOOL_MISMATCH'; END IF;

      v_description := trim(coalesce(v_item->>'description', ''));
      v_qty := coalesce(nullif(v_item->>'quantity', '')::numeric, 1);
      v_unit := coalesce(nullif(v_item->>'unit_amount', '')::numeric, 0);
      v_discount := coalesce(nullif(v_item->>'discount', '')::numeric, 0);
      IF v_description = '' OR v_qty <= 0 OR v_unit < 0 OR v_discount < 0 OR v_discount > v_qty * v_unit THEN
        RAISE EXCEPTION 'INVALID_INVOICE_ITEM';
      END IF;

      INSERT INTO public.invoice_items(invoice_id, fee_type_id, description, quantity, unit_amount, discount)
      VALUES (p_invoice_id, v_fee_type, v_description, v_qty, v_unit, v_discount);
    END LOOP;
  END IF;

  UPDATE public.invoices
  SET issue_date = p_issue_date, due_date = p_due_date, notes = nullif(trim(p_notes), ''), updated_at = now()
  WHERE id = p_invoice_id;
  RETURN p_invoice_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_invoice(uuid, date, date, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_invoice(uuid, date, date, text, jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';
