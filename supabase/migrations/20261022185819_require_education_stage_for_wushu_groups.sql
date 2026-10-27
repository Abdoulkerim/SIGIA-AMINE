begin;

-- Keep Wushu groups within the existing education-stage boundary.
-- The RPC requires a stage and verifies it against the caller's assigned scope
-- before inserting; the existing apply_education_stage trigger then enforces
-- the same rule at the table boundary.
create or replace function public.create_wushu_group_for_stage(
  p_code text,
  p_name text,
  p_level text,
  p_coach_employee_id uuid,
  p_schedule jsonb,
  p_education_stage text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_id uuid;
  v_stage text;
begin
  select school_id into v_school
  from public.users
  where id = (select auth.uid());

  if v_school is null then
    raise exception 'Utilisateur sans établissement';
  end if;

  if not (app.has_permission('wushu.manage', v_school) or app.is_super_admin()) then
    raise exception 'Permission Wushu insuffisante';
  end if;

  v_stage := app.normalize_education_stage(p_education_stage);
  if v_stage is null then
    raise exception 'EDUCATION_STAGE_REQUIRED: wushu_groups' using errcode = '42501';
  end if;

  if not app.is_super_admin() and not app.can_access_education_stage(v_school, v_stage) then
    raise exception 'FORBIDDEN_EDUCATION_STAGE: wushu_groups' using errcode = '42501';
  end if;

  insert into public.wushu_groups(
    school_id, code, name, level, coach_employee_id, schedule, education_stage
  )
  values (
    v_school,
    nullif(btrim(p_code), ''),
    btrim(p_name),
    nullif(btrim(p_level), ''),
    p_coach_employee_id,
    coalesce(p_schedule, '{}'::jsonb),
    v_stage
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.create_wushu_group_for_stage(text, text, text, uuid, jsonb, text) from public, anon;
grant execute on function public.create_wushu_group_for_stage(text, text, text, uuid, jsonb, text) to authenticated;

commit;
