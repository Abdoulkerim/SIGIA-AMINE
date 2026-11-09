begin;

create or replace function public.record_payroll_payment(
  p_payroll_item_id uuid,
  p_payment_date date,
  p_method app.payment_method,
  p_cash_account_id uuid,
  p_reference text default null,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_period_status text;
  v_payment_status app.payment_status;
  v_amount numeric;
  v_employee text;
  v_account_school uuid;
begin
  select pp.school_id, pp.status, pi.payment_status, pi.net_salary,
         concat(e.employee_number, ' — ', e.first_name, ' ', e.last_name)
    into v_school, v_period_status, v_payment_status, v_amount, v_employee
    from public.payroll_items pi
    join public.payroll_periods pp on pp.id=pi.payroll_period_id
    join public.employees e on e.id=pi.employee_id
   where pi.id=p_payroll_item_id
   for update of pi, pp;

  if v_school is null then raise exception 'PAYROLL_ITEM_NOT_FOUND'; end if;
    if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not coalesce(
    app.has_permission('payroll.manage', v_school) or app.is_super_admin(),
    false
  ) then
    raise exception 'FORBIDDEN_PAYROLL_MANAGE';
  end if;
  if v_period_status <> 'approved' then raise exception 'PAYROLL_NOT_APPROVED'; end if;
  if v_payment_status='paid' then raise exception 'PAYROLL_ITEM_ALREADY_PAID'; end if;
  if v_payment_status <> 'pending' then raise exception 'PAYROLL_ITEM_NOT_PAYABLE'; end if;
  if v_amount <= 0 then raise exception 'PAYROLL_AMOUNT_INVALID'; end if;

  select school_id into v_account_school from public.cash_accounts where id=p_cash_account_id and is_active for update;
  if v_account_school is distinct from v_school then raise exception 'CASH_ACCOUNT_SCHOOL_MISMATCH'; end if;

  update public.payroll_items
     set payment_status='paid', paid_at=p_payment_date::timestamptz, paid_by=auth.uid()
   where id=p_payroll_item_id;

  insert into public.cash_transactions(school_id,cash_account_id,transaction_type,amount,transaction_date,reference_type,reference_id,description,created_by)
  values(
    v_school,p_cash_account_id,'expense',v_amount,p_payment_date::timestamptz,
    'payroll_item',p_payroll_item_id,
    concat('Paie employé — ',v_employee,' — mode: ',p_method,
      case when nullif(trim(p_reference),'') is not null then concat(' — référence: ',trim(p_reference)) else '' end,
      case when nullif(trim(p_notes),'') is not null then concat(' — ',trim(p_notes)) else '' end),
    auth.uid()
  );

  if not exists(select 1 from public.payroll_items where payroll_period_id=(select payroll_period_id from public.payroll_items where id=p_payroll_item_id) and payment_status not in ('paid','cancelled')) then
    update public.payroll_periods set status='paid' where id=(select payroll_period_id from public.payroll_items where id=p_payroll_item_id);
  end if;
end;
$$;

revoke all on function public.record_payroll_payment(uuid,date,app.payment_method,uuid,text,text) from public, anon;
grant execute on function public.record_payroll_payment(uuid,date,app.payment_method,uuid,text,text) to authenticated;

commit;
