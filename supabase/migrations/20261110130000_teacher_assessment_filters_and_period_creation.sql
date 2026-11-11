drop policy if exists classes_select_017 on public.classes;
create policy classes_select_017
on public.classes
for select
to authenticated
using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      app.has_permission('classes.view', school_id)
      or app.has_permission('classes.manage', school_id)
      or exists (
        select 1
        from public.teacher_assignments ta
        where ta.class_id = classes.id
          and app.teacher_assignment_belongs_to_user(ta.teacher_id)
      )
    )
  )
);

drop policy if exists subjects_select_018 on public.subjects;
create policy subjects_select_018
on public.subjects
for select
to authenticated
using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      app.has_permission('subjects.view', school_id)
      or app.has_permission('subjects.manage', school_id)
      or app.has_permission('classes.view', school_id)
      or app.has_permission('classes.manage', school_id)
      or app.has_permission('teachers.manage', school_id)
      or app.has_permission('assessments.manage', school_id)
      or exists (
        select 1
        from public.teacher_assignments ta
        where ta.subject_id = subjects.id
          and app.teacher_assignment_belongs_to_user(ta.teacher_id)
      )
    )
  )
);

drop policy if exists academic_periods_insert_assessment_manage on public.academic_periods;
create policy academic_periods_insert_assessment_manage
on public.academic_periods
for insert
to authenticated
with check (
  exists (
    select 1
    from public.school_years sy
    where sy.id = school_year_id
      and (
        app.is_super_admin()
        or (
          sy.school_id in (select app.my_school_ids())
          and (
            app.has_permission('settings.manage', sy.school_id)
            or app.has_permission('assessments.manage', sy.school_id)
          )
        )
      )
  )
);
