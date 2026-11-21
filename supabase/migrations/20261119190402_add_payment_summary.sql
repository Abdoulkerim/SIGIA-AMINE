create or replace function public.get_payment_summary(p_school_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, app
as $function$
declare
  v_school_id uuid;
  v_today date := current_date;
  v_result jsonb;
begin
  v_school_id := coalesce(
    p_school_id,
    (select u.school_id from public.users u where u.id = (select auth.uid()))
  );

  if v_school_id is null
     or (not app.is_super_admin() and v_school_id not in (select app.my_school_ids())) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  if not app.is_super_admin()
     and not app.has_permission('finance.view', v_school_id)
     and not app.has_permission('finance.manage', v_school_id) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total_paid', coalesce(sum(p.amount) filter (where p.status = 'paid'), 0),
    'received_today', coalesce(sum(p.amount) filter (where p.status = 'paid' and p.payment_date::date = v_today), 0)
  )
  into v_result
  from public.payments p
  where p.school_id = v_school_id;

  return v_result;
end;
$function$;

revoke all on function public.get_payment_summary(uuid) from public, anon;
grant execute on function public.get_payment_summary(uuid) to authenticated;
