
BEGIN;

CREATE OR REPLACE FUNCTION public.approve_expense(
    p_expense_id uuid,
    p_cash_account_id uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
DECLARE
    v_school uuid;
    v_method app.payment_method;
    v_status app.approval_status;
    v_account_school uuid;
BEGIN
    SELECT school_id, payment_method, approval_status
    INTO v_school, v_method, v_status
    FROM public.expenses
    WHERE id = p_expense_id
    FOR UPDATE;

    IF v_school IS NULL THEN
        RAISE EXCEPTION 'EXPENSE_NOT_FOUND';
    END IF;

    IF NOT app.is_super_admin()
       AND NOT app.has_permission('expenses.manage', v_school) THEN
        RAISE EXCEPTION 'FORBIDDEN';
    END IF;

    IF v_status = 'approved' THEN
        RETURN p_expense_id;
    END IF;

    IF v_method IS NOT NULL AND p_cash_account_id IS NOT NULL THEN
        SELECT school_id
        INTO v_account_school
        FROM public.cash_accounts
        WHERE id = p_cash_account_id;

        IF v_account_school IS NULL OR v_account_school <> v_school THEN
            RAISE EXCEPTION 'EXPENSE_CASH_ACCOUNT_SCHOOL_MISMATCH';
        END IF;
    END IF;

    UPDATE public.expenses
    SET approval_status = 'approved',
        approved_by = auth.uid(),
        updated_at = now()
    WHERE id = p_expense_id;

    IF p_cash_account_id IS NOT NULL AND v_method IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM public.cash_transactions
            WHERE reference_type = 'expense'
              AND reference_id = p_expense_id
        ) THEN
            RAISE EXCEPTION 'EXPENSE_ALREADY_POSTED_TO_CASH';
        END IF;

        INSERT INTO public.cash_transactions (
            school_id,
            cash_account_id,
            transaction_type,
            amount,
            transaction_date,
            reference_type,
            reference_id,
            description,
            created_by
        )
        SELECT
            school_id,
            p_cash_account_id,
            'expense',
            amount,
            expense_date::timestamptz,
            'expense',
            id,
            'Dépense ' || expense_number,
            auth.uid()
        FROM public.expenses
        WHERE id = p_expense_id;
    END IF;

    RETURN p_expense_id;
END;
$function$;

COMMIT;
