begin;

drop policy if exists school_years_assessment_staff_select on public.school_years;
create policy school_years_assessment_staff_select
on public.school_years
for select
to authenticated
using (
  school_id in (select app.my_school_ids())
  and (
    app.has_permission('assessments.view', school_id)
    or app.has_permission('assessments.manage', school_id)
  )
);

commit;
