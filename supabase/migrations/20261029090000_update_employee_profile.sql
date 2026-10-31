begin;

create or replace function public.update_employee(
  p_employee_id uuid,
  p_employee_number text,
  p_first_name text,
  p_last_name text,
  p_job_title text default null,
  p_department text default null,
  p_qualification text default null,
  p_hire_date date default null,
  p_gender app.gender_type default null,
  p_date_of_birth date default null,
  p_place_of_birth text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_user_school_id uuid;
  v_user_active boolean;
begin
  select school_id into v_school_id
  from public.employees
  where id = p_employee_id;

  if v_school_id is null then
    raise exception 'EMPLOYEE_NOT_FOUND';
  end if;

  select school_id, status = 'active' into v_user_school_id, v_user_active
  from public.users
  where id = auth.uid();

  if auth.uid() is null or v_user_active is distinct from true then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not app.is_super_admin()
     and (v_user_school_id is distinct from v_school_id
       or not app.has_permission('hr.manage', v_school_id)) then
    raise exception 'FORBIDDEN_HR_MANAGE';
  end if;

  if length(trim(coalesce(p_employee_number, ''))) = 0 then
    raise exception 'EMPLOYEE_NUMBER_REQUIRED';
  end if;
  if length(trim(coalesce(p_first_name, ''))) = 0 then
    raise exception 'FIRST_NAME_REQUIRED';
  end if;
  if length(trim(coalesce(p_last_name, ''))) = 0 then
    raise exception 'LAST_NAME_REQUIRED';
  end if;

  update public.employees
  set employee_number = trim(p_employee_number),
      first_name = trim(p_first_name),
      last_name = trim(p_last_name),
      job_title = nullif(trim(p_job_title), ''),
      department = nullif(trim(p_department), ''),
      qualification = nullif(trim(p_qualification), ''),
      hire_date = p_hire_date,
      gender = p_gender,
      date_of_birth = p_date_of_birth,
      place_of_birth = nullif(trim(p_place_of_birth), ''),
      phone = nullif(trim(p_phone), ''),
      email = nullif(trim(p_email), ''),
      address = nullif(trim(p_address), ''),
      updated_at = now()
  where id = p_employee_id;

  return p_employee_id;
end;
$$;

revoke all on function public.update_employee(uuid,text,text,text,text,text,text,date,app.gender_type,date,text,text,text,text) from public, anon;
grant execute on function public.update_employee(uuid,text,text,text,text,text,text,date,app.gender_type,date,text,text,text,text) to authenticated;

commit;
