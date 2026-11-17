-- Return only the minimum directory and filter fields required by the
-- Arabic/Tahfiz forms. No general students/classes table access is granted.
create or replace function public.get_specialized_form_options(p_module text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_result jsonb;
  v_permission text;
begin
  v_permission := case p_module
    when 'arabic' then 'arabic.manage'
    when 'tahfiz' then 'tahfiz.manage'
    else null
  end;

  select u.school_id into v_school
  from public.users u
  where u.id = auth.uid();

  if v_permission is null or v_school is null or not (
    app.has_permission(v_permission, v_school) or app.is_super_admin()
  ) then
    raise exception 'Accès aux listes de formation spécialisée refusé';
  end if;

  select jsonb_build_object(
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'student_number', s.student_number,
        'first_name', s.first_name, 'last_name', s.last_name, 'gender', s.gender
      ) order by s.last_name, s.first_name)
      from public.students s where s.school_id = v_school
    ), '[]'::jsonb),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'code', c.code)
        order by c.name)
      from public.classes c
      join public.school_years sy on sy.id = c.school_year_id
      where c.school_id = v_school and sy.is_current
    ), '[]'::jsonb),
    'enrollments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'student_id', e.student_id, 'class_id', e.class_id, 'education_stage', e.education_stage
      ))
      from public.enrollments e
      join public.school_years sy on sy.id = e.school_year_id
      where e.school_id = v_school and sy.is_current and e.status = 'enrolled'
    ), '[]'::jsonb),
    'periods', coalesce((
      select jsonb_agg(jsonb_build_object('id', ap.id, 'name', ap.name, 'school_year_id', ap.school_year_id)
        order by ap.start_date, ap.sequence_no)
      from public.academic_periods ap
      join public.school_years sy on sy.id = ap.school_year_id
      where sy.school_id = v_school
    ), '[]'::jsonb),
    'subjects', case when p_module = 'arabic' then coalesce((
      select jsonb_agg(jsonb_build_object('id', sub.id, 'name', sub.name, 'code', sub.code, 'education_stage', sub.education_stage)
        order by sub.name)
      from public.subjects sub
      where sub.school_id = v_school and sub.domain = 'arabe' and sub.is_active
    ), '[]'::jsonb) else '[]'::jsonb end
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_specialized_form_options(text) from public, anon;
grant execute on function public.get_specialized_form_options(text) to authenticated;

create or replace function public.get_specialized_periods()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_school uuid; v_result jsonb;
begin
  select u.school_id into v_school from public.users u where u.id=auth.uid();
  if v_school is null or not (
    app.has_permission('arabic.view',v_school)
    or app.has_permission('arabic.manage',v_school)
    or app.has_permission('tahfiz.view',v_school)
    or app.has_permission('tahfiz.manage',v_school)
    or app.is_super_admin()
  ) then
    raise exception 'Accès périodes formation spécialisée refusé';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',ap.id,'name',ap.name,'school_year_id',ap.school_year_id) order by ap.start_date,ap.sequence_no),'[]'::jsonb)
    into v_result
    from public.academic_periods ap
    join public.school_years sy on sy.id=ap.school_year_id
   where sy.school_id=v_school;
  return v_result;
end $$;
