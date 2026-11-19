create or replace function public.get_specialized_staff(p_module text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_permission text;
  v_result jsonb;
begin
  select u.school_id into v_school
  from public.users u
  where u.id = auth.uid();

  if v_school is null then
    raise exception 'Établissement introuvable';
  end if;

  v_permission := case
    when p_module = 'tahfiz' then 'tahfiz.view'
    when p_module = 'arabic' then 'arabic.view'
    else null
  end;

  if v_permission is null
     or not (
       app.has_permission(v_permission, v_school)
       or app.has_permission(replace(v_permission, '.view', '.manage'), v_school)
       or app.is_super_admin()
     ) then
    raise exception 'Accès responsable spécialisé refusé';
  end if;

  if p_module = 'arabic' then
    select coalesce(
      jsonb_agg(
        jsonb_build_object('id', e.id, 'first_name', e.first_name, 'last_name', e.last_name, 'job_title', e.job_title)
        order by e.last_name, e.first_name
      ),
      '[]'::jsonb
    ) into v_result
    from public.employees e
    inner join public.teacher_profiles tp on tp.employee_id = e.id
    where e.school_id = v_school and e.status = 'active';
  else
    select coalesce(
      jsonb_agg(
        jsonb_build_object('id', e.id, 'first_name', e.first_name, 'last_name', e.last_name, 'job_title', e.job_title)
        order by e.last_name, e.first_name
      ),
      '[]'::jsonb
    ) into v_result
    from public.employees e
    where e.school_id = v_school and e.status = 'active';
  end if;

  return v_result;
end;
$$;
