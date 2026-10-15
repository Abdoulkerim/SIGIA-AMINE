begin;

alter table public.fee_types
  add column if not exists default_amount numeric(14,2) not null default 0
  check (default_amount >= 0);

drop function if exists public.create_fee_type(uuid,text,text,text,text);

create function public.create_fee_type(
  p_school_id uuid,
  p_code text,
  p_name text,
  p_category text,
  p_description text default null,
  p_default_amount numeric default 0
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_id uuid;
begin
  if not app.is_super_admin() and not app.has_permission('finance.manage', p_school_id) then
    raise exception 'FORBIDDEN';
  end if;
  if p_default_amount < 0 then
    raise exception 'INVALID_FEE_AMOUNT';
  end if;

  insert into public.fee_types(school_id, code, name, category, description, default_amount)
  values (p_school_id, trim(p_code), trim(p_name), trim(p_category), nullif(trim(p_description), ''), p_default_amount)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_fee_type(uuid,text,text,text,text,numeric) from public, anon;
grant execute on function public.create_fee_type(uuid,text,text,text,text,numeric) to authenticated;

commit;
