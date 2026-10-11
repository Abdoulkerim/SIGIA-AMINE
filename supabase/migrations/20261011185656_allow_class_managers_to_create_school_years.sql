-- Let staff who manage classes read and create school years for their own school.
-- Update and delete continue to use the existing settings.manage policies.
drop policy if exists school_years_class_manager_select on public.school_years;

create policy school_years_class_manager_select
on public.school_years
for select
to authenticated
using (
  school_id in (select app.my_school_ids())
  and app.has_permission('classes.manage', school_id)
);

drop policy if exists school_years_class_manager_insert on public.school_years;

create policy school_years_class_manager_insert
on public.school_years
for insert
to authenticated
with check (
  school_id in (select app.my_school_ids())
  and app.has_permission('classes.manage', school_id)
);
