
BEGIN;

-- 1. Corriger create_purchase_order
CREATE OR REPLACE FUNCTION public.create_purchase_order(
    p_order_number text,
    p_supplier_id uuid,
    p_order_date date,
    p_expected_date date,
    p_default_location_id uuid,
    p_request_id uuid,
    p_items jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    sid uuid;
    ss uuid;
    ls uuid;
    rs uuid;
    poid uuid;
    item jsonb;
    pid uuid;
    qty numeric;
    cost numeric;
    v_total numeric := 0;
    req_status app.approval_status;
BEGIN
    SELECT u.school_id
    INTO sid
    FROM public.users u
    WHERE u.id = auth.uid();

    SELECT s.school_id
    INTO ss
    FROM public.suppliers s
    WHERE s.id = p_supplier_id
      AND s.is_active = true;

    IF sid IS NULL OR ss IS DISTINCT FROM sid
       OR NOT (
           app.has_permission('purchases.manage', sid)
           OR app.is_super_admin()
       )
    THEN
        RAISE EXCEPTION 'PURCHASE_ORDER_FORBIDDEN';
    END IF;

    IF p_default_location_id IS NOT NULL THEN
        SELECT sl.school_id
        INTO ls
        FROM public.stock_locations sl
        WHERE sl.id = p_default_location_id;

        IF ls IS DISTINCT FROM sid THEN
            RAISE EXCEPTION 'PURCHASE_LOCATION_INVALID';
        END IF;
    END IF;

    IF p_request_id IS NOT NULL THEN
        SELECT pr.school_id, pr.status
        INTO rs, req_status
        FROM public.purchase_requests pr
        WHERE pr.id = p_request_id;

        IF rs IS DISTINCT FROM sid
           OR req_status IS DISTINCT FROM 'approved'::app.approval_status
        THEN
            RAISE EXCEPTION 'PURCHASE_REQUEST_NOT_APPROVED';
        END IF;
    END IF;

    IF jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0
    THEN
        RAISE EXCEPTION 'PURCHASE_ORDER_EMPTY';
    END IF;

    INSERT INTO public.purchase_orders (
        school_id, order_number, supplier_id,
        order_date, expected_date, status, created_by
    )
    VALUES (
        sid, trim(p_order_number), p_supplier_id,
        p_order_date, p_expected_date, 'draft', auth.uid()
    )
    RETURNING id INTO poid;

    UPDATE public.purchase_orders AS po
    SET source_request_id = p_request_id,
        default_location_id = p_default_location_id
    WHERE po.id = poid;

    FOR item IN
        SELECT value
        FROM jsonb_array_elements(p_items)
    LOOP
        pid := (item->>'product_id')::uuid;
        qty := (item->>'quantity')::numeric;
        cost := (item->>'unit_cost')::numeric;

        IF qty IS NULL OR qty <= 0 OR cost IS NULL OR cost < 0 THEN
            RAISE EXCEPTION 'PURCHASE_ORDER_ITEM_INVALID';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM public.products p
            WHERE p.id = pid
              AND p.school_id = sid
              AND p.is_active = true
        ) THEN
            RAISE EXCEPTION 'PURCHASE_PRODUCT_INVALID';
        END IF;

        INSERT INTO public.purchase_items (
            purchase_order_id, product_id,
            quantity, unit_cost, received_quantity
        )
        VALUES (poid, pid, qty, cost, 0);

        v_total := v_total + (qty * cost);
    END LOOP;

    UPDATE public.purchase_orders AS po
    SET subtotal = v_total,
        total = v_total
    WHERE po.id = poid;

    RETURN poid;
END;
$function$;


-- 2. Corriger receive_purchase_order
CREATE OR REPLACE FUNCTION public.receive_purchase_order(
    p_purchase_order_id uuid,
    p_location_id uuid,
    p_receipt_number text,
    p_received_at timestamptz,
    p_items jsonb,
    p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    sid uuid;
    locschool uuid;
    v_order_status app.approval_status;
    rid uuid;
    item jsonb;
    pi_id uuid;
    qty numeric;
    available numeric;
    prod uuid;
    movement uuid;
    all_received boolean;
BEGIN
    SELECT po.school_id, po.status
    INTO sid, v_order_status
    FROM public.purchase_orders po
    WHERE po.id = p_purchase_order_id
    FOR UPDATE;

    SELECT sl.school_id
    INTO locschool
    FROM public.stock_locations sl
    WHERE sl.id = p_location_id;

    IF sid IS NULL
       OR locschool IS DISTINCT FROM sid
       OR NOT (
           app.has_permission('purchases.manage', sid)
           OR app.has_permission('stock.manage', sid)
           OR app.is_super_admin()
       )
    THEN
        RAISE EXCEPTION 'PURCHASE_RECEIPT_FORBIDDEN';
    END IF;

    IF v_order_status NOT IN ('approved', 'submitted') THEN
        RAISE EXCEPTION 'PURCHASE_ORDER_NOT_RECEIVABLE';
    END IF;

    IF jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0
    THEN
        RAISE EXCEPTION 'PURCHASE_RECEIPT_EMPTY';
    END IF;

    INSERT INTO public.purchase_receipts (
        school_id, purchase_order_id, receipt_number,
        location_id, received_at, status, received_by, notes
    )
    VALUES (
        sid, p_purchase_order_id, trim(p_receipt_number),
        p_location_id, p_received_at, 'posted', auth.uid(),
        nullif(trim(p_notes), '')
    )
    RETURNING id INTO rid;

    FOR item IN
        SELECT value
        FROM jsonb_array_elements(p_items)
    LOOP
        pi_id := (item->>'purchase_item_id')::uuid;
        qty := (item->>'quantity')::numeric;

        SELECT pi.product_id, pi.quantity - pi.received_quantity
        INTO prod, available
        FROM public.purchase_items pi
        WHERE pi.id = pi_id
          AND pi.purchase_order_id = p_purchase_order_id
        FOR UPDATE;

        IF prod IS NULL OR qty IS NULL OR qty <= 0 OR qty > available THEN
            RAISE EXCEPTION 'PURCHASE_RECEIPT_QUANTITY_INVALID';
        END IF;

        INSERT INTO public.stock_movements (
            school_id, product_id, location_id, movement_type,
            quantity, unit_cost, reference_type, reference_id,
            created_by, notes
        )
        SELECT
            sid, pi.product_id, p_location_id, 'purchase',
            qty, pi.unit_cost, 'purchase_receipt', rid,
            auth.uid(), 'Réception achat'
        FROM public.purchase_items pi
        WHERE pi.id = pi_id
        RETURNING id INTO movement;

        INSERT INTO public.purchase_receipt_items (
            receipt_id, purchase_item_id, product_id,
            quantity, unit_cost, stock_movement_id
        )
        SELECT
            rid, pi.id, pi.product_id,
            qty, pi.unit_cost, movement
        FROM public.purchase_items pi
        WHERE pi.id = pi_id;

        UPDATE public.purchase_items AS pi
        SET received_quantity = pi.received_quantity + qty
        WHERE pi.id = pi_id;
    END LOOP;

    SELECT NOT EXISTS (
        SELECT 1
        FROM public.purchase_items pi
        WHERE pi.purchase_order_id = p_purchase_order_id
          AND pi.received_quantity < pi.quantity
    )
    INTO all_received;

    UPDATE public.purchase_orders AS po
    SET status = CASE
        WHEN all_received THEN 'approved'
        ELSE 'submitted'
    END
    WHERE po.id = p_purchase_order_id;

    RETURN rid;
END;
$function$;


-- 3. Corriger complete_stock_transfer
CREATE OR REPLACE FUNCTION public.complete_stock_transfer(
    p_transfer_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    sid uuid;
    v_transfer_status text;
    source uuid;
    target uuid;
    r record;
    balance numeric;
BEGIN
    SELECT
        st.school_id,
        st.status,
        st.source_location_id,
        st.target_location_id
    INTO sid, v_transfer_status, source, target
    FROM public.stock_transfers st
    WHERE st.id = p_transfer_id
    FOR UPDATE;

    IF sid IS NULL
       OR NOT (
           app.has_permission('stock.manage', sid)
           OR app.is_super_admin()
       )
    THEN
        RAISE EXCEPTION 'STOCK_TRANSFER_FORBIDDEN';
    END IF;

    IF v_transfer_status NOT IN ('draft', 'approved', 'submitted') THEN
        RAISE EXCEPTION 'STOCK_TRANSFER_STATUS_INVALID';
    END IF;

    FOR r IN
        SELECT sti.*
        FROM public.stock_transfer_items sti
        WHERE sti.transfer_id = p_transfer_id
    LOOP
        SELECT sb.quantity
        INTO balance
        FROM public.stock_balances sb
        WHERE sb.product_id = r.product_id
          AND sb.location_id = source
        FOR UPDATE;

        IF coalesce(balance, 0) < r.quantity THEN
            RAISE EXCEPTION 'STOCK_TRANSFER_INSUFFICIENT';
        END IF;

        INSERT INTO public.stock_movements (
            school_id, product_id, location_id, movement_type,
            quantity, reference_type, reference_id, created_by, notes
        )
        VALUES (
            sid, r.product_id, source, 'transfer',
            r.quantity, 'stock_transfer', p_transfer_id,
            auth.uid(), 'Transfert sortant'
        );

        INSERT INTO public.stock_movements (
            school_id, product_id, location_id, movement_type,
            quantity, reference_type, reference_id, created_by, notes
        )
        VALUES (
            sid, r.product_id, target, 'return',
            r.quantity, 'stock_transfer', p_transfer_id,
            auth.uid(), 'Transfert entrant'
        );

        UPDATE public.stock_transfer_items AS sti
        SET dispatched_quantity = sti.quantity,
            received_quantity = sti.quantity
        WHERE sti.id = r.id;
    END LOOP;

    UPDATE public.stock_transfers AS st
    SET status = 'received',
        approved_by = coalesce(st.approved_by, auth.uid()),
        received_by = auth.uid()
    WHERE st.id = p_transfer_id;
END;
$function$;


-- 4. Corriger pay_purchase_invoice
CREATE OR REPLACE FUNCTION public.pay_purchase_invoice(
    p_purchase_invoice_id uuid,
    p_cash_account_id uuid,
    p_amount numeric,
    p_payment_date timestamptz,
    p_reference text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    sid uuid;
    invoice_amount numeric;
    paid numeric;
    cash_school uuid;
    pid uuid;
    tx uuid;
    v_invoice_status text;
BEGIN
    SELECT
        pi.school_id,
        pi.amount,
        pi.paid_amount,
        pi.status
    INTO sid, invoice_amount, paid, v_invoice_status
    FROM public.purchase_invoices pi
    WHERE pi.id = p_purchase_invoice_id
    FOR UPDATE;

    SELECT ca.school_id
    INTO cash_school
    FROM public.cash_accounts ca
    WHERE ca.id = p_cash_account_id;

    IF sid IS NULL
       OR cash_school IS DISTINCT FROM sid
       OR NOT (
           app.has_permission('cash.manage', sid)
           OR app.has_permission('finance.manage', sid)
           OR app.is_super_admin()
       )
    THEN
        RAISE EXCEPTION 'PURCHASE_PAYMENT_FORBIDDEN';
    END IF;

    IF v_invoice_status = 'cancelled'
       OR p_amount IS NULL
       OR p_amount <= 0
       OR p_amount > (invoice_amount - paid)
    THEN
        RAISE EXCEPTION 'PURCHASE_PAYMENT_AMOUNT_INVALID';
    END IF;

    INSERT INTO public.cash_transactions (
        school_id, cash_account_id, transaction_type, amount,
        transaction_date, reference_type, reference_id,
        description, created_by
    )
    VALUES (
        sid, p_cash_account_id, 'expense', p_amount,
        p_payment_date, 'purchase_invoice', p_purchase_invoice_id,
        'Paiement facture fournisseur', auth.uid()
    )
    RETURNING id INTO tx;

    INSERT INTO public.purchase_invoice_payments (
        school_id, purchase_invoice_id, cash_account_id,
        amount, payment_date, reference, created_by, cash_transaction_id
    )
    VALUES (
        sid, p_purchase_invoice_id, p_cash_account_id,
        p_amount, p_payment_date, nullif(trim(p_reference), ''),
        auth.uid(), tx
    )
    RETURNING id INTO pid;

    UPDATE public.purchase_invoices AS pi
    SET paid_amount = pi.paid_amount + p_amount,
        status = CASE
            WHEN pi.paid_amount + p_amount >= pi.amount
                THEN 'paid'
            ELSE 'partially_paid'
        END
    WHERE pi.id = p_purchase_invoice_id;

    RETURN pid;
END;
$function$;

COMMIT;
