drop policy if exists academic_periods_select_secure on public.academic_periods;

create policy academic_periods_select_secure
on public.academic_periods
for select
to authenticated
using (
  exists (
    select 1
    from public.school_years sy
    where sy.id = school_year_id
      and (
        app.has_permission('settings.manage', sy.school_id)
        or app.has_permission('classes.manage', sy.school_id)
        or app.has_permission('assessments.view', sy.school_id)
        or app.has_permission('assessments.manage', sy.school_id)
        or app.has_permission('grades.view', sy.school_id)
        or app.has_permission('grades.enter', sy.school_id)
        or app.has_permission('grades.publish', sy.school_id)
        or app.has_permission('report_cards.generate', sy.school_id)
        or app.has_role_code('direction', sy.school_id)
        or app.has_role_code('founder', sy.school_id)
        or app.is_super_admin()
      )
  )
);
