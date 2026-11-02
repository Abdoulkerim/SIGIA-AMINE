-- Wushu users need coach names for group/session forms, but should not get
-- broad read access to the HR employees table. Expose only the fields needed.
create or replace function public.list_wushu_coaches()
returns table (
  id uuid,
  first_name text,
  last_name text,
  employee_number text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
begin
  select u.school_id into v_school_id
  from public.users u
  where u.id = (select auth.uid())
    and u.status = 'active';

  if v_school_id is null then
    raise exception 'Utilisateur sans établissement';
  end if;

  if not (
    app.is_super_admin()
    or app.has_permission('wushu.view', v_school_id)
    or app.has_permission('wushu.manage', v_school_id)
    or app.has_role_code('direction', v_school_id)
    or app.has_role_code('founder', v_school_id)
  ) then
    raise exception 'Permission Wushu insuffisante';
  end if;

  return query
  select e.id, e.first_name, e.last_name, e.employee_number
  from public.employees e
  where e.school_id = v_school_id
    and e.status = 'active'
  order by e.last_name, e.first_name;
end;
$$;

revoke all on function public.list_wushu_coaches() from public, anon;
grant execute on function public.list_wushu_coaches() to authenticated;
