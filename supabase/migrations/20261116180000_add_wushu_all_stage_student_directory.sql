-- Wushu managers need a cross-cycle student picker, but should not gain
-- general SELECT access to the school's student/class/enrollment tables.
create or replace function public.get_wushu_student_directory()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_year uuid;
  v_result jsonb;
begin
  select u.school_id into v_school
  from public.users u
  where u.id = auth.uid() and u.status = 'active'::app.user_status;

  if v_school is null or not (
    app.has_permission('wushu.manage', v_school) or app.is_super_admin()
  ) then
    raise exception 'Accès au répertoire Wushu refusé';
  end if;

  select sy.id into v_year
  from public.school_years sy
  where sy.school_id = v_school
  order by sy.is_current desc, sy.start_date desc
  limit 1;

  select jsonb_build_object(
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'student_number', s.student_number,
        'first_name', s.first_name, 'last_name', s.last_name, 'gender', s.gender
      ) order by s.last_name, s.first_name)
      from public.students s
      where s.school_id = v_school and s.status = 'active'
    ), '[]'::jsonb),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name, 'code', c.code, 'education_stage', c.education_stage
      ) order by c.name)
      from public.classes c
      where c.school_id = v_school and c.school_year_id = v_year
    ), '[]'::jsonb),
    'enrollments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'student_id', e.student_id, 'class_id', e.class_id,
        'education_stage', coalesce(e.education_stage, c.education_stage)
      ))
      from public.enrollments e
      left join public.classes c on c.id = e.class_id
      where e.school_id = v_school and e.school_year_id = v_year and e.status = 'enrolled'
    ), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id, 'name', g.name, 'level', g.level, 'is_active', g.is_active
      ) order by g.name)
      from public.wushu_groups g where g.school_id = v_school
    ), '[]'::jsonb),
    'profiles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', sw.id, 'student_id', sw.student_id, 'group_id', sw.group_id,
        'current_grade', sw.current_grade, 'current_progress', sw.current_progress,
        'start_date', sw.start_date, 'status', sw.status, 'updated_at', sw.updated_at
      ) order by sw.updated_at desc)
      from public.student_wushu sw where sw.school_id = v_school
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_wushu_student_directory() from public, anon;
grant execute on function public.get_wushu_student_directory() to authenticated;
