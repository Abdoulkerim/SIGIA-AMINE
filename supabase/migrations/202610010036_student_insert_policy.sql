begin;

drop policy if exists students_insert_staff on public.students;
create policy students_insert_staff on public.students
  for insert to authenticated
  with check (
    app.has_permission('students.manage', school_id)
    or app.is_super_admin()
  );

commit;