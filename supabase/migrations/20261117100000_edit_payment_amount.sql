begin;

create or replace function public.update_payment_details(
  p_payment_id uuid,
  p_amount numeric,
  p_payment_date timestamptz,
  p_method app.payment_method,
  p_reference text,
  p_notes text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_old_date timestamptz;
  v_cash_linked boolean;
  v_allocation_count integer;
begin
  if p_amount is null or p_amount <= 0 or p_payment_date is null then
    raise exception 'INVALID_PAYMENT_DETAILS';
  end if;

  select school_id, payment_date
    into v_school, v_old_date
    from public.payments
    where id = p_payment_id
    for update;
  if v_school is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
  if auth.uid() is null or (not app.is_super_admin() and not app.has_permission('finance.manage', v_school)) then
    raise exception 'FORBIDDEN';
  end if;
  if (p_reference is not null and length(p_reference) > 120)
     or (p_notes is not null and length(p_notes) > 500) then
    raise exception 'INVALID_PAYMENT_DETAILS';
  end if;

  select count(*) into v_allocation_count
    from public.payment_allocations
    where payment_id = p_payment_id;
  if v_allocation_count <> 1 then
    raise exception 'PAYMENT_AMOUNT_EDIT_REQUIRES_SINGLE_ALLOCATION';
  end if;

  select exists(
    select 1 from public.cash_transactions
    where reference_type = 'payment' and reference_id = p_payment_id
  ) into v_cash_linked;

  if v_cash_linked and exists (
    select 1
    from public.cash_transactions ct
    join public.cash_closings cc on cc.cash_account_id = ct.cash_account_id
    where ct.reference_type = 'payment'
      and ct.reference_id = p_payment_id
      and cc.closing_date >= least(p_payment_date::date, v_old_date::date)
  ) then
    raise exception 'PAYMENT_LOCKED_BY_CASH_CLOSING';
  end if;

  update public.payments
    set amount = p_amount,
        payment_date = p_payment_date,
        method = p_method,
        reference = nullif(trim(p_reference), ''),
        notes = nullif(trim(p_notes), '')
    where id = p_payment_id;

  -- The allocation trigger checks the corrected value against the remaining
  -- amount due and refreshes the invoice or direct-charge payment status.
  update public.payment_allocations
    set amount = p_amount
    where payment_id = p_payment_id;

  update public.receipts set issued_at = p_payment_date where payment_id = p_payment_id;
  if v_cash_linked then
    update public.cash_transactions
      set amount = p_amount, transaction_date = p_payment_date
      where reference_type = 'payment' and reference_id = p_payment_id;
  end if;
  return p_payment_id;
end;
$$;

revoke all on function public.update_payment_details(uuid,numeric,timestamptz,app.payment_method,text,text) from public, anon;
grant execute on function public.update_payment_details(uuid,numeric,timestamptz,app.payment_method,text,text) to authenticated;

commit;
