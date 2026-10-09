begin;

drop policy if exists parents_insert_staff on public.parents;
create policy parents_insert_staff on public.parents
  for insert to authenticated
  with check (
    app.has_permission('parents.manage', school_id)
    or app.is_super_admin()
  );

commit;