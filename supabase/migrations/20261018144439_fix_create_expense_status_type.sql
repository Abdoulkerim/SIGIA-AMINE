
BEGIN;

CREATE OR REPLACE FUNCTION public.create_expense(
    p_category_id uuid,
    p_supplier_id uuid,
    p_amount numeric,
    p_expense_date date,
    p_description text,
    p_payment_method app.payment_method DEFAULT NULL::app.payment_method,
    p_cash_account_id uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
DECLARE
    v_school uuid;
    v_id uuid;
    v_number text;
    v_status app.approval_status := 'draft'::app.approval_status;
BEGIN
    IF p_category_id IS NOT NULL THEN
        SELECT school_id
        INTO v_school
        FROM public.expense_categories
        WHERE id = p_category_id;
    END IF;

    IF v_school IS NULL AND p_supplier_id IS NOT NULL THEN
        SELECT school_id
        INTO v_school
        FROM public.suppliers
        WHERE id = p_supplier_id;
    END IF;

    IF v_school IS NULL AND p_cash_account_id IS NOT NULL THEN
        SELECT school_id
        INTO v_school
        FROM public.cash_accounts
        WHERE id = p_cash_account_id;
    END IF;

    IF v_school IS NULL THEN
        SELECT school_id
        INTO v_school
        FROM public.users
        WHERE id = auth.uid();
    END IF;

    IF v_school IS NULL THEN
        RAISE EXCEPTION 'EXPENSE_SCOPE_NOT_FOUND';
    END IF;

    IF NOT app.is_super_admin()
       AND NOT app.has_permission('expenses.manage', v_school) THEN
        RAISE EXCEPTION 'FORBIDDEN';
    END IF;

    IF p_amount < 0 THEN
        RAISE EXCEPTION 'EXPENSE_AMOUNT_INVALID';
    END IF;

    IF p_cash_account_id IS NOT NULL
       AND p_payment_method IS NULL THEN
        RAISE EXCEPTION 'EXPENSE_PAYMENT_METHOD_REQUIRED';
    END IF;

    v_number := 'DEP-'
        || to_char(now(), 'YYYYMMDDHH24MISSMS')
        || '-'
        || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

    INSERT INTO public.expenses (
        school_id,
        expense_number,
        category_id,
        supplier_id,
        amount,
        expense_date,
        description,
        payment_method,
        approval_status,
        created_by
    )
    VALUES (
        v_school,
        v_number,
        p_category_id,
        p_supplier_id,
        p_amount,
        coalesce(p_expense_date, current_date),
        trim(p_description),
        p_payment_method,
        v_status,
        auth.uid()
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$function$;

COMMIT;
