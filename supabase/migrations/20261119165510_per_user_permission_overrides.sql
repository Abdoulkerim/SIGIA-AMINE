begin;

create table public.user_permission_overrides (
  user_id uuid not null references public.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  is_granted boolean not null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, school_id, permission_id)
);

create index user_permission_overrides_school_permission_idx
  on public.user_permission_overrides (school_id, permission_id, user_id);

alter table public.user_permission_overrides enable row level security;
revoke all on public.user_permission_overrides from anon, authenticated;
grant select on public.user_permission_overrides to authenticated;
create policy user_permission_overrides_select_manager
  on public.user_permission_overrides for select to authenticated
  using (user_id = auth.uid() or app.has_permission('users.roles.manage', school_id) or app.has_role_code('founder', school_id) or app.is_super_admin());

create or replace function public.set_user_permission_overrides(
  p_user_id uuid,
  p_school_id uuid,
  p_granted_permission_ids uuid[] default '{}',
  p_denied_permission_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := (select auth.uid());
  v_caller_school uuid;
  v_protected_target boolean;
  v_is_privileged boolean;
  v_sensitive_permission boolean;
begin
  if v_caller_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  select school_id into v_caller_school from public.users where id = v_caller_id and status = 'active';
  if v_caller_school is null then raise exception 'ACTIVE_USER_REQUIRED'; end if;
  v_is_privileged := app.is_super_admin() or app.has_role_code('founder', p_school_id);
  if v_caller_school is distinct from p_school_id and not v_is_privileged then raise exception 'FORBIDDEN_USER_PERMISSION_MANAGE'; end if;
  if not v_is_privileged and not app.has_permission('users.roles.manage', p_school_id) then raise exception 'FORBIDDEN_USER_PERMISSION_MANAGE'; end if;
  if p_user_id = v_caller_id then raise exception 'CANNOT_CHANGE_OWN_PERMISSIONS'; end if;
  if not exists (select 1 from public.users where id = p_user_id and school_id = p_school_id) then raise exception 'USER_NOT_FOUND_IN_SCHOOL'; end if;

  select exists (
    select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id
    where ur.user_id = p_user_id and ur.school_id = p_school_id and ur.is_active
      and r.code in ('super_admin', 'founder', 'it_admin')
  ) into v_protected_target;
  if v_protected_target and not v_is_privileged then raise exception 'PROTECTED_USER_PERMISSION_MANAGE'; end if;

  if coalesce(cardinality(p_granted_permission_ids), 0) > 0 and coalesce(cardinality(p_denied_permission_ids), 0) > 0
    and p_granted_permission_ids && p_denied_permission_ids then
    raise exception 'DUPLICATE_PERMISSION_OVERRIDE';
  end if;
  if exists (
    select 1 from unnest(coalesce(p_granted_permission_ids, '{}') || coalesce(p_denied_permission_ids, '{}')) as requested(id)
    left join public.permissions p on p.id = requested.id where p.id is null
  ) then raise exception 'UNKNOWN_PERMISSION'; end if;

  if not v_is_privileged and exists (
    select 1 from public.permissions p
    where p.id = any(coalesce(p_granted_permission_ids, '{}'))
      and p.code in ('users.manage', 'users.roles.manage', 'settings.manage', 'audit.view')
  ) then raise exception 'PROTECTED_PERMISSION'; end if;

  delete from public.user_permission_overrides where user_id = p_user_id and school_id = p_school_id;
  insert into public.user_permission_overrides(user_id, school_id, permission_id, is_granted, created_by)
  select p_user_id, p_school_id, granted.id, true, v_caller_id
  from unnest(coalesce(p_granted_permission_ids, '{}')) as granted(id);
  insert into public.user_permission_overrides(user_id, school_id, permission_id, is_granted, created_by)
  select p_user_id, p_school_id, denied.id, false, v_caller_id
  from unnest(coalesce(p_denied_permission_ids, '{}')) as denied(id);
end;
$$;

revoke all on function public.set_user_permission_overrides(uuid, uuid, uuid[], uuid[]) from public, anon;
grant execute on function public.set_user_permission_overrides(uuid, uuid, uuid[], uuid[]) to authenticated;

create or replace function app.has_permission(p_code text, p_school_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public, app
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.status = 'active'::app.user_status
  ) and (
    app.is_super_admin()
    or (
      not exists (
        select 1 from public.user_permission_overrides o
        join public.permissions p on p.id = o.permission_id
        where o.user_id = auth.uid() and p.code = p_code and not o.is_granted
          and (p_school_id is null or o.school_id = p_school_id)
      )
      and (
        exists (
          select 1
          from public.user_roles ur
          join public.role_permissions rp on rp.role_id = ur.role_id
          join public.permissions p on p.id = rp.permission_id
          join public.users u on u.id = ur.user_id and u.status = 'active'::app.user_status
          where ur.user_id = auth.uid() and ur.is_active and p.code = p_code
            and (p_school_id is null or ur.school_id = p_school_id)
        )
        or exists (
          select 1 from public.user_permission_overrides o
          join public.permissions p on p.id = o.permission_id
          where o.user_id = auth.uid() and p.code = p_code and o.is_granted
            and (p_school_id is null or o.school_id = p_school_id)
        )
      )
    )
  );
$$;

revoke all on function app.has_permission(text, uuid) from public, anon;
grant execute on function app.has_permission(text, uuid) to authenticated;

commit;

NOTIFY pgrst, 'reload schema';
