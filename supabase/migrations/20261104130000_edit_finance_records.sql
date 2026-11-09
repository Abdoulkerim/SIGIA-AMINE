begin;

create or replace function public.update_fee_type(
  p_fee_type_id uuid, p_code text, p_name text, p_category text,
  p_description text, p_default_amount numeric, p_is_active boolean
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_school uuid;
begin
  select school_id into v_school from public.fee_types where id=p_fee_type_id for update;
  if v_school is null then raise exception 'FEE_TYPE_NOT_FOUND'; end if;
   if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not coalesce(
    app.is_super_admin() or app.has_permission('finance.manage', v_school),
    false
  ) then
    raise exception 'FORBIDDEN';
  end if;
  if length(trim(coalesce(p_code,''))) not between 1 and 40 or length(trim(coalesce(p_name,''))) not between 1 and 160 or length(trim(coalesce(p_category,''))) not between 1 and 80 or p_default_amount is null or p_default_amount<0 then
    raise exception 'INVALID_FEE_TYPE';
  end if;
  update public.fee_types set code=trim(p_code),name=trim(p_name),category=trim(p_category),description=nullif(trim(p_description),''),default_amount=p_default_amount,is_active=p_is_active
  where id=p_fee_type_id;
  return p_fee_type_id;
end;
$$;

create or replace function public.update_invoice(
  p_invoice_id uuid, p_issue_date date, p_due_date date, p_notes text, p_items jsonb default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_school uuid; v_allocated boolean; v_item jsonb; v_description text; v_qty numeric; v_unit numeric; v_discount numeric; v_fee_type uuid;
begin
  select school_id into v_school from public.invoices where id=p_invoice_id for update;
  if v_school is null then raise exception 'INVOICE_NOT_FOUND'; end if;
    if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not coalesce(
    app.is_super_admin() or app.has_permission('finance.manage', v_school),
    false
  ) then
    raise exception 'FORBIDDEN';
  end if;
  if p_notes is not null and length(p_notes)>500 then raise exception 'INVALID_INVOICE_NOTES'; end if;
  select exists(select 1 from public.payment_allocations where invoice_id=p_invoice_id) into v_allocated;
  if p_items is not null then
    if v_allocated then raise exception 'INVOICE_HAS_PAYMENTS_ITEMS_LOCKED'; end if;
    if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'INVOICE_NEEDS_ITEMS'; end if;
    delete from public.invoice_items where invoice_id=p_invoice_id;
    for v_item in select value from jsonb_array_elements(p_items) loop
      v_fee_type := nullif(v_item->>'fee_type_id','')::uuid;
        if v_fee_type is not null and not exists (
        select 1
        from public.fee_types ft
        where ft.id = v_fee_type
          and ft.school_id = v_school
      ) then
        raise exception 'FEE_TYPE_SCHOOL_MISMATCH';
        end if;
      v_description := trim(coalesce(v_item->>'description',''));
      v_qty := coalesce(nullif(v_item->>'quantity','')::numeric,1);
      v_unit := coalesce(nullif(v_item->>'unit_amount','')::numeric,0);
      v_discount := coalesce(nullif(v_item->>'discount','')::numeric,0);
      if v_description='' or v_qty<=0 or v_unit<0 or v_discount<0 or v_discount>v_qty*v_unit then raise exception 'INVALID_INVOICE_ITEM'; end if;
      insert into public.invoice_items(invoice_id,fee_type_id,description,quantity,unit_amount,discount)
      values(p_invoice_id,v_fee_type,v_description,v_qty,v_unit,v_discount);
    end loop;
  end if;
  update public.invoices set issue_date=p_issue_date,due_date=p_due_date,notes=nullif(trim(p_notes),''),updated_at=now() where id=p_invoice_id;
  return p_invoice_id;
end;
$$;

create or replace function public.update_payment_details(
  p_payment_id uuid, p_payment_date timestamptz, p_method app.payment_method,
  p_reference text, p_notes text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_school uuid; v_old_date timestamptz; v_cash_linked boolean;
begin
  if p_payment_date is null then raise exception 'INVALID_PAYMENT_DATE'; end if;
  select school_id,payment_date into v_school,v_old_date from public.payments where id=p_payment_id for update;
  if v_school is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
  if auth.uid() is null or (not app.is_super_admin() and not app.has_permission('finance.manage',v_school)) then raise exception 'FORBIDDEN'; end if;
  if p_reference is not null and length(p_reference)>120 or p_notes is not null and length(p_notes)>500 then raise exception 'INVALID_PAYMENT_DETAILS'; end if;
  select exists(select 1 from public.cash_transactions where reference_type='payment' and reference_id=p_payment_id) into v_cash_linked;
  if v_cash_linked and p_payment_date::date is distinct from v_old_date::date and exists(
    select 1 from public.cash_transactions ct join public.cash_closings cc on cc.cash_account_id=ct.cash_account_id
    where ct.reference_type='payment' and ct.reference_id=p_payment_id
      and cc.closing_date >= least(p_payment_date::date,v_old_date::date)
  ) then raise exception 'PAYMENT_DATE_LOCKED_BY_CASH_CLOSING'; end if;
  update public.payments set payment_date=p_payment_date,method=p_method,reference=nullif(trim(p_reference),''),notes=nullif(trim(p_notes),'' ) where id=p_payment_id;
  update public.receipts set issued_at=p_payment_date where payment_id=p_payment_id;
  if v_cash_linked then update public.cash_transactions set transaction_date=p_payment_date where reference_type='payment' and reference_id=p_payment_id; end if;
  return p_payment_id;
end;
$$;

revoke all on function public.update_fee_type(uuid,text,text,text,text,numeric,boolean) from public, anon;
revoke all on function public.update_invoice(uuid,date,date,text,jsonb) from public, anon;
revoke all on function public.update_payment_details(uuid,timestamptz,app.payment_method,text,text) from public, anon;
grant execute on function public.update_fee_type(uuid,text,text,text,text,numeric,boolean) to authenticated;
grant execute on function public.update_invoice(uuid,date,date,text,jsonb) to authenticated;
grant execute on function public.update_payment_details(uuid,timestamptz,app.payment_method,text,text) to authenticated;

commit;
