-- Expose only assessments assigned to the signed-in teacher, with a roster
-- limited to enrolled students in each assessment's class/year.
create or replace function public.get_teacher_assessments_for_grading()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_school uuid;
  v_result jsonb;
begin
  select u.school_id into v_school
  from public.users u
  where u.id = v_user and u.status = 'active'::app.user_status;

  if v_school is null or not (
    app.is_super_admin()
    or app.has_permission('grades.publish', v_school)
    or app.has_permission('grades.enter', v_school)
  ) then
    raise exception 'Accès à la saisie des notes refusé';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'title', a.title, 'assessment_date', a.assessment_date,
    'max_score', a.max_score, 'is_published', a.is_published,
    'school_years', jsonb_build_object('name', sy.name),
    'academic_periods', jsonb_build_object('name', ap.name),
    'classes', jsonb_build_object('name', c.name, 'code', c.code),
    'subjects', jsonb_build_object('name', sub.name, 'code', sub.code),
    'employees', jsonb_build_object('first_name', e.first_name, 'last_name', e.last_name),
    'assessment_types', jsonb_build_object('name', at.name)
  ) order by a.assessment_date desc), '[]'::jsonb)
    into v_result
  from public.assessments a
  join public.school_years sy on sy.id = a.school_year_id
  join public.academic_periods ap on ap.id = a.period_id
  join public.classes c on c.id = a.class_id
  join public.subjects sub on sub.id = a.subject_id
  join public.employees e on e.id = a.teacher_id
  left join public.assessment_types at on at.id = a.assessment_type_id
  where a.school_id = v_school
    and (
      app.is_super_admin()
      or app.has_permission('grades.publish', v_school)
      or (app.has_permission('grades.enter', v_school) and app.is_teacher_for_assessment(a.id))
    );

  return v_result;
end;
$$;

create or replace function public.get_assessment_grade_sheet(p_assessment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_ass public.assessments%rowtype;
  v_result jsonb;
begin
  select * into v_ass
  from public.assessments a
  where a.id = p_assessment_id;

  if not found then raise exception 'ASSESSMENT_NOT_FOUND_OR_FORBIDDEN'; end if;
  if not (
    app.is_super_admin()
    or app.has_permission('grades.publish', v_ass.school_id)
    or (app.has_permission('grades.enter', v_ass.school_id) and app.is_teacher_for_assessment(v_ass.id))
  ) then
    raise exception 'ASSESSMENT_NOT_FOUND_OR_FORBIDDEN';
  end if;

  select jsonb_build_object(
    'assessment', jsonb_build_object(
      'id', a.id, 'title', a.title, 'max_score', a.max_score,
      'is_published', a.is_published, 'school_year_id', a.school_year_id,
      'class_id', a.class_id, 'period_id', a.period_id,
      'subjects', jsonb_build_object('name', sub.name),
      'classes', jsonb_build_object('name', c.name, 'code', c.code),
      'academic_periods', jsonb_build_object('name', ap.name, 'is_closed', ap.is_closed),
      'employees', jsonb_build_object('first_name', e.first_name, 'last_name', e.last_name)
    ),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
        'student_id', en.student_id,
        'students', jsonb_build_object(
          'id', s.id, 'first_name', s.first_name,
          'last_name', s.last_name, 'student_number', s.student_number
        ),
        'grade', case when g.student_id is null then null else jsonb_build_object(
          'student_id', g.student_id, 'score', g.score, 'observation', g.observation
        ) end
      ) order by s.last_name, s.first_name)
      from public.enrollments en
      join public.students s on s.id = en.student_id
      left join public.grades g on g.assessment_id = a.id and g.student_id = en.student_id
      where en.school_year_id = a.school_year_id
        and en.class_id = a.class_id
        and en.status = 'enrolled'
    ), '[]'::jsonb)
  ) into v_result
  from public.assessments a
  join public.classes c on c.id = a.class_id
  join public.subjects sub on sub.id = a.subject_id
  join public.academic_periods ap on ap.id = a.period_id
  join public.employees e on e.id = a.teacher_id
  where a.id = v_ass.id;

  return v_result;
end;
$$;

revoke all on function public.get_teacher_assessments_for_grading() from public, anon;
revoke all on function public.get_assessment_grade_sheet(uuid) from public, anon;
grant execute on function public.get_teacher_assessments_for_grading() to authenticated;
grant execute on function public.get_assessment_grade_sheet(uuid) to authenticated;
