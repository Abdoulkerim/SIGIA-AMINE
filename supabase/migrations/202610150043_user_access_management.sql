begin;

create or replace function app.my_school_ids()
returns setof uuid
language sql stable security definer set search_path=public,app
as $$
  select ur.school_id
  from public.user_roles ur
  join public.users u on u.id=ur.user_id and u.status='active'::app.user_status
  where ur.user_id=auth.uid() and ur.is_active=true and ur.school_id is not null
  union
  select u.school_id
  from public.users u
  where u.id=auth.uid() and u.status='active'::app.user_status and u.school_id is not null
$$;

create or replace function app.is_super_admin()
returns boolean
language sql stable security definer set search_path=public,app
as $$
  select exists(
    select 1
    from public.user_roles ur
    join public.roles r on r.id=ur.role_id
    join public.users u on u.id=ur.user_id and u.status='active'::app.user_status
    where ur.user_id=auth.uid() and ur.is_active=true and r.code='super_admin'
  )
$$;

create or replace function app.has_permission(p_code text,p_school_id uuid default null)
returns boolean
language sql stable security definer set search_path=public,app
as $$
  select exists(select 1 from public.users u where u.id=auth.uid() and u.status='active'::app.user_status)
    and (app.is_super_admin() or exists(
      select 1
      from public.user_roles ur
      join public.role_permissions rp on rp.role_id=ur.role_id
      join public.permissions p on p.id=rp.permission_id
      join public.users u on u.id=ur.user_id and u.status='active'::app.user_status
      where ur.user_id=auth.uid()
        and ur.is_active=true
        and p.code=p_code
        and (p_school_id is null or ur.school_id=p_school_id)
    ))
$$;

create or replace function app.my_role_codes(p_school_id uuid default null)
returns setof text
language sql stable security definer set search_path=public,app
as $$
  select r.code
  from public.user_roles ur
  join public.roles r on r.id=ur.role_id
  join public.users u on u.id=ur.user_id and u.status='active'::app.user_status
  where ur.user_id=auth.uid() and ur.is_active and (p_school_id is null or ur.school_id=p_school_id)
$$;

create or replace function app.is_parent_of_student(p_student_id uuid)
returns boolean
language sql stable security definer set search_path=public,app
as $$
  select exists(
    select 1
    from public.students s
    join public.student_parents sp on sp.student_id=s.id
    join public.parents p on p.id=sp.parent_id
    join public.users u on u.id=auth.uid() and u.status='active'::app.user_status
    where s.id=p_student_id and p.user_id=auth.uid()
  )
$$;

create or replace function app.is_self_student(p_student_id uuid)
returns boolean
language sql stable security definer set search_path=public,app
as $$
  select exists(
    select 1
    from public.students s
    join public.users u on u.id=auth.uid() and u.status='active'::app.user_status
    where s.id=p_student_id and s.user_id=auth.uid()
  )
$$;

create or replace function app.guard_user_access_state()
returns trigger
language plpgsql security definer set search_path=public,app
as $$
begin
  if old.id=auth.uid() and (old.status is distinct from new.status or old.school_id is distinct from new.school_id) then
    raise exception 'CANNOT_CHANGE_OWN_ACCESS';
  end if;
  if (old.status is distinct from new.status or old.school_id is distinct from new.school_id)
    and not app.is_super_admin()
    and not app.has_permission('users.manage',old.school_id) then
    raise exception 'FORBIDDEN_USER_ACCESS_CHANGE';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_user_access_state on public.users;
create trigger trg_guard_user_access_state
before update of status,school_id on public.users
for each row execute function app.guard_user_access_state();

create or replace function app.guard_user_role_assignment()
returns trigger
language plpgsql security definer set search_path=public,app
as $$
declare
  v_role_code text;
  v_user_id uuid;
  v_role_id uuid;
  v_school_id uuid;
begin
  if tg_op='DELETE' then
    v_user_id:=old.user_id;
    v_role_id:=old.role_id;
    v_school_id:=old.school_id;
  else
    v_user_id:=new.user_id;
    v_role_id:=new.role_id;
    v_school_id:=new.school_id;
  end if;

  if v_user_id=auth.uid() then
    raise exception 'CANNOT_CHANGE_OWN_ROLES';
  end if;

  select code into v_role_code from public.roles where id=v_role_id;
  if v_role_code in ('super_admin','founder','it_admin')
    and not app.is_super_admin()
    and not app.has_role_code('founder',v_school_id) then
    raise exception 'FORBIDDEN_PRIVILEGED_ROLE_ASSIGNMENT';
  end if;

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_user_role_assignment on public.user_roles;
create trigger trg_guard_user_role_assignment
before insert or update or delete on public.user_roles
for each row execute function app.guard_user_role_assignment();

create or replace function app.audit_access_change()
returns trigger
language plpgsql security definer set search_path=public,app
as $$
declare
  v_school_id uuid;
  v_id uuid;
  v_action text;
  v_old jsonb;
  v_new jsonb;
begin
  if tg_table_name='users' then
    if tg_op<>'UPDATE' or (old.status is not distinct from new.status and old.school_id is not distinct from new.school_id) then
      return new;
    end if;
    v_school_id:=coalesce(new.school_id,old.school_id);
    v_id:=new.id;
    v_action:='user_access_updated';
    v_old:=jsonb_build_object('status',old.status,'school_id',old.school_id);
    v_new:=jsonb_build_object('status',new.status,'school_id',new.school_id);
  else
    v_school_id:=coalesce(new.school_id,old.school_id);
    v_id:=coalesce(new.id,old.id);
    v_action:='user_role_'||lower(tg_op);
    if tg_op<>'INSERT' then v_old:=to_jsonb(old); end if;
    if tg_op<>'DELETE' then v_new:=to_jsonb(new); end if;
  end if;

  insert into public.audit_logs(school_id,actor_user_id,action,table_name,record_id,old_data,new_data)
  values(v_school_id,auth.uid(),v_action,tg_table_name,v_id,v_old,v_new);

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function app.guard_user_access_state() from public,anon,authenticated;
revoke all on function app.guard_user_role_assignment() from public,anon,authenticated;
revoke all on function app.audit_access_change() from public,anon,authenticated;

drop trigger if exists trg_audit_users_access on public.users;
create trigger trg_audit_users_access
after update of status,school_id on public.users
for each row execute function app.audit_access_change();

drop trigger if exists trg_audit_user_roles_access on public.user_roles;
create trigger trg_audit_user_roles_access
after insert or update or delete on public.user_roles
for each row execute function app.audit_access_change();

commit;
