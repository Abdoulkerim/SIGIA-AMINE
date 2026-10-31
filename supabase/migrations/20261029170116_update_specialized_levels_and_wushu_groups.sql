begin;

create or replace function public.update_tahfiz_level(
  p_level_id uuid,
  p_code text,
  p_name text,
  p_sequence_no integer default 0,
  p_description text default null,
  p_is_active boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_user_school_id uuid;
begin
  select school_id into v_school_id
  from public.tahfiz_levels
  where id = p_level_id;
  if v_school_id is null then raise exception 'TAHFIZ_LEVEL_NOT_FOUND'; end if;

  select school_id into v_user_school_id
  from public.users
  where id = (select auth.uid()) and status = 'active';
  if not app.is_super_admin()
     and (v_user_school_id is distinct from v_school_id
       or not app.has_permission('tahfiz.manage', v_school_id)) then
    raise exception 'FORBIDDEN_TAHFIZ_MANAGE';
  end if;
  if length(trim(coalesce(p_code, ''))) = 0 then raise exception 'TAHFIZ_LEVEL_CODE_REQUIRED'; end if;
  if length(trim(coalesce(p_name, ''))) = 0 then raise exception 'TAHFIZ_LEVEL_NAME_REQUIRED'; end if;
  if coalesce(p_sequence_no, -1) < 0 then raise exception 'TAHFIZ_LEVEL_ORDER_INVALID'; end if;

  update public.tahfiz_levels
  set code = trim(p_code),
      name = trim(p_name),
      sequence_no = coalesce(p_sequence_no, 0),
      description = nullif(trim(p_description), ''),
      is_active = coalesce(p_is_active, true)
  where id = p_level_id and school_id = v_school_id;
end;
$$;

create or replace function public.update_arabic_level(
  p_level_id uuid,
  p_code text,
  p_name text,
  p_sequence_no integer default 0,
  p_description text default null,
  p_is_active boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_user_school_id uuid;
begin
  select school_id into v_school_id
  from public.arabic_levels
  where id = p_level_id;
  if v_school_id is null then raise exception 'ARABIC_LEVEL_NOT_FOUND'; end if;

  select school_id into v_user_school_id
  from public.users
  where id = (select auth.uid()) and status = 'active';
  if not app.is_super_admin()
     and (v_user_school_id is distinct from v_school_id
       or not app.has_permission('arabic.manage', v_school_id)) then
    raise exception 'FORBIDDEN_ARABIC_MANAGE';
  end if;
  if length(trim(coalesce(p_code, ''))) = 0 then raise exception 'ARABIC_LEVEL_CODE_REQUIRED'; end if;
  if length(trim(coalesce(p_name, ''))) = 0 then raise exception 'ARABIC_LEVEL_NAME_REQUIRED'; end if;
  if coalesce(p_sequence_no, -1) < 0 then raise exception 'ARABIC_LEVEL_ORDER_INVALID'; end if;

  update public.arabic_levels
  set code = trim(p_code),
      name = trim(p_name),
      sequence_no = coalesce(p_sequence_no, 0),
      description = nullif(trim(p_description), ''),
      is_active = coalesce(p_is_active, true)
  where id = p_level_id and school_id = v_school_id;
end;
$$;

create or replace function public.update_wushu_group(
  p_group_id uuid,
  p_code text,
  p_name text,
  p_level text default null,
  p_coach_employee_id uuid default null,
  p_is_active boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_user_school_id uuid;
  v_education_stage text;
begin
  select school_id, education_stage
  into v_school_id, v_education_stage
  from public.wushu_groups
  where id = p_group_id;
  if v_school_id is null then raise exception 'WUSHU_GROUP_NOT_FOUND'; end if;

  select school_id into v_user_school_id
  from public.users
  where id = (select auth.uid()) and status = 'active';
  if not app.is_super_admin()
     and (v_user_school_id is distinct from v_school_id
       or not app.has_permission('wushu.manage', v_school_id)) then
    raise exception 'FORBIDDEN_WUSHU_MANAGE';
  end if;
  if not app.is_super_admin()
     and not app.can_access_education_stage(v_school_id, v_education_stage) then
    raise exception 'FORBIDDEN_EDUCATION_STAGE: wushu_groups' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_name, ''))) = 0 then raise exception 'WUSHU_GROUP_NAME_REQUIRED'; end if;

  update public.wushu_groups
  set code = nullif(trim(p_code), ''),
      name = trim(p_name),
      level = nullif(trim(p_level), ''),
      coach_employee_id = p_coach_employee_id,
      is_active = coalesce(p_is_active, true)
  where id = p_group_id and school_id = v_school_id;
end;
$$;

revoke all on function public.update_tahfiz_level(uuid, text, text, integer, text, boolean) from public, anon;
revoke all on function public.update_arabic_level(uuid, text, text, integer, text, boolean) from public, anon;
revoke all on function public.update_wushu_group(uuid, text, text, text, uuid, boolean) from public, anon;
grant execute on function public.update_tahfiz_level(uuid, text, text, integer, text, boolean) to authenticated;
grant execute on function public.update_arabic_level(uuid, text, text, integer, text, boolean) to authenticated;
grant execute on function public.update_wushu_group(uuid, text, text, text, uuid, boolean) to authenticated;

commit;
