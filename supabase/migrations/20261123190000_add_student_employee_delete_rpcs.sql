begin;

create or replace function public.delete_employee(p_employee_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
begin
  select e.school_id into v_school
  from public.employees e
  where e.id = p_employee_id;

  if v_school is null then
    raise exception 'EMPLOYEE_NOT_FOUND';
  end if;
  if not app.is_super_admin()
     and not app.has_permission('hr.manage', v_school) then
    raise exception 'FORBIDDEN_HR_MANAGE';
  end if;

  delete from public.employees
  where id = p_employee_id and school_id = v_school;
end;
$$;

create or replace function public.delete_student(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
begin
  select s.school_id into v_school
  from public.students s
  where s.id = p_student_id;

  if v_school is null then
    raise exception 'STUDENT_NOT_FOUND';
  end if;
  if not app.is_super_admin()
     and not app.has_permission('students.manage', v_school) then
    raise exception 'FORBIDDEN_STUDENTS_MANAGE';
  end if;

  delete from public.students
  where id = p_student_id and school_id = v_school;
end;
$$;

revoke all on function public.delete_employee(uuid) from public, anon;
revoke all on function public.delete_student(uuid) from public, anon;
grant execute on function public.delete_employee(uuid) to authenticated;
grant execute on function public.delete_student(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
