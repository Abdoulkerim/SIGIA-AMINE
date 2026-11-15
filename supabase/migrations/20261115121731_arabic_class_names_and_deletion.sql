begin;

alter table public.arabic_levels add column if not exists name_fr text;

drop function if exists public.create_arabic_level(text, text, integer, text);
create function public.create_arabic_level(
  p_code text,
  p_name text,
  p_french_name text,
  p_sequence_no integer default 0,
  p_description text default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_school uuid;
  v_id uuid;
begin
  select u.school_id into v_school from public.users u where u.id = (select auth.uid()) and u.status = 'active';
  if v_school is null or not app.has_permission('arabic.manage', v_school) then raise exception 'FORBIDDEN_ARABIC_MANAGE'; end if;
  if length(trim(coalesce(p_code, ''))) = 0 or length(trim(coalesce(p_name, ''))) = 0 or length(trim(coalesce(p_french_name, ''))) = 0 then
    raise exception 'ARABIC_LEVEL_FIELDS_REQUIRED';
  end if;
  if coalesce(p_sequence_no, -1) < 0 then raise exception 'ARABIC_LEVEL_ORDER_INVALID'; end if;
  insert into public.arabic_levels(school_id, code, name, name_fr, sequence_no, description)
  values(v_school, btrim(p_code), btrim(p_name), btrim(p_french_name), coalesce(p_sequence_no, 0), nullif(btrim(p_description), '')) returning id into v_id;
  return v_id;
end $$;

drop function if exists public.update_arabic_level(uuid, text, text, integer, text, boolean);
create function public.update_arabic_level(
  p_level_id uuid,
  p_code text,
  p_name text,
  p_french_name text,
  p_sequence_no integer default 0,
  p_description text default null,
  p_is_active boolean default true
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_school uuid;
  v_user_school uuid;
begin
  select school_id into v_school from public.arabic_levels where id = p_level_id;
  if v_school is null then raise exception 'ARABIC_LEVEL_NOT_FOUND'; end if;
  select school_id into v_user_school from public.users where id = (select auth.uid()) and status = 'active';
  if not app.is_super_admin() and (v_user_school is distinct from v_school or not app.has_permission('arabic.manage', v_school)) then
    raise exception 'FORBIDDEN_ARABIC_MANAGE';
  end if;
  if length(trim(coalesce(p_code, ''))) = 0 or length(trim(coalesce(p_name, ''))) = 0 or length(trim(coalesce(p_french_name, ''))) = 0 then
    raise exception 'ARABIC_LEVEL_FIELDS_REQUIRED';
  end if;
  if coalesce(p_sequence_no, -1) < 0 then raise exception 'ARABIC_LEVEL_ORDER_INVALID'; end if;
  update public.arabic_levels set code = btrim(p_code), name = btrim(p_name), name_fr = btrim(p_french_name),
    sequence_no = coalesce(p_sequence_no, 0), description = nullif(btrim(p_description), ''), is_active = coalesce(p_is_active, true)
  where id = p_level_id and school_id = v_school;
end $$;

create or replace function public.delete_arabic_level(p_level_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_school uuid;
begin
  select school_id into v_school from public.arabic_levels where id = p_level_id;
  if v_school is null then raise exception 'ARABIC_LEVEL_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('arabic.manage', v_school) then raise exception 'FORBIDDEN_ARABIC_MANAGE'; end if;
  delete from public.arabic_levels where id = p_level_id and school_id = v_school;
end $$;

create or replace function public.delete_student_arabic_profile(p_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_school uuid;
begin
  select school_id into v_school from public.student_arabic where id = p_profile_id;
  if v_school is null then raise exception 'ARABIC_PROFILE_NOT_FOUND'; end if;
  if not app.is_super_admin() and not app.has_permission('arabic.manage', v_school) then raise exception 'FORBIDDEN_ARABIC_MANAGE'; end if;
  delete from public.student_arabic where id = p_profile_id and school_id = v_school;
end $$;

revoke all on function public.create_arabic_level(text, text, text, integer, text) from public, anon;
revoke all on function public.update_arabic_level(uuid, text, text, text, integer, text, boolean) from public, anon;
revoke all on function public.delete_arabic_level(uuid) from public, anon;
revoke all on function public.delete_student_arabic_profile(uuid) from public, anon;
grant execute on function public.create_arabic_level(text, text, text, integer, text) to authenticated;
grant execute on function public.update_arabic_level(uuid, text, text, text, integer, text, boolean) to authenticated;
grant execute on function public.delete_arabic_level(uuid) to authenticated;
grant execute on function public.delete_student_arabic_profile(uuid) to authenticated;

commit;
