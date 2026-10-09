begin;

alter table public.classes
  drop constraint if exists classes_level_required,
  alter column level_id drop not null;

create or replace function app.validate_level_class_integrity()
returns trigger
language plpgsql
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_level_school uuid;
begin
  if TG_TABLE_NAME = 'classes' then
    select school_id into v_school_id
    from public.school_years
    where id = NEW.school_year_id;

    if v_school_id is null then
      raise exception 'INVALID_SCHOOL_YEAR';
    end if;

    if v_school_id <> NEW.school_id then
      raise exception 'CROSS_SCHOOL: classes.school_year_id';
    end if;

    if NEW.level_id is not null then
      select school_id into v_level_school
      from public.levels
      where id = NEW.level_id;

      if v_level_school is null then
        raise exception 'INVALID_LEVEL';
      end if;

      if v_level_school <> NEW.school_id then
        raise exception 'CROSS_SCHOOL: classes.level_id';
      end if;
    end if;
  end if;

  return NEW;
end;
$$;

create or replace function public.create_class(
  p_school_year_id uuid,
  p_level_id uuid,
  p_name text,
  p_code text,
  p_section text default null,
  p_room_name text default null,
  p_capacity integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_user public.users%rowtype;
  v_year_school uuid;
  v_level_school uuid;
  v_id uuid;
begin
  select * into v_user
  from public.users
  where id = auth.uid()
    and status = 'active';

  if v_user.id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not app.has_permission('classes.manage', v_user.school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_CLASS_MANAGE';
  end if;

  select school_id into v_year_school
  from public.school_years
  where id = p_school_year_id;

  if v_year_school is null or (v_year_school <> v_user.school_id and not app.is_super_admin()) then
    raise exception 'INVALID_SCHOOL_YEAR';
  end if;

  if p_level_id is not null then
    select school_id into v_level_school
    from public.levels
    where id = p_level_id
      and is_active = true;

    if v_level_school is null or (v_level_school <> v_user.school_id and not app.is_super_admin()) then
      raise exception 'INVALID_LEVEL';
    end if;
  end if;

  if length(trim(coalesce(p_name,''))) = 0 then
    raise exception 'CLASS_NAME_REQUIRED';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then
    raise exception 'CLASS_CODE_REQUIRED';
  end if;

  if p_capacity is not null and p_capacity <= 0 then
    raise exception 'CLASS_CAPACITY_INVALID';
  end if;

  insert into public.classes(
    school_id, school_year_id, level_id, name, code, section,
    room_name, capacity, is_active
  )
  values (
    v_user.school_id,
    p_school_year_id,
    p_level_id,
    trim(p_name),
    trim(p_code),
    nullif(trim(p_section), ''),
    nullif(trim(p_room_name), ''),
    p_capacity,
    true
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_class(
  p_class_id uuid,
  p_school_year_id uuid,
  p_level_id uuid,
  p_name text,
  p_code text,
  p_section text default null,
  p_room_name text default null,
  p_capacity integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_year_school uuid;
  v_level_school uuid;
begin
  select school_id into v_school_id
  from public.classes
  where id = p_class_id;

  if v_school_id is null then
    raise exception 'CLASS_NOT_FOUND';
  end if;

  if not app.has_permission('classes.manage', v_school_id) and not app.is_super_admin() then
    raise exception 'FORBIDDEN_CLASS_MANAGE';
  end if;

  select school_id into v_year_school
  from public.school_years
  where id = p_school_year_id;

  if v_year_school is distinct from v_school_id then
    raise exception 'CROSS_SCHOOL: classes.school_year_id';
  end if;

  if p_level_id is not null then
    select school_id into v_level_school
    from public.levels
    where id = p_level_id
      and is_active = true;

    if v_level_school is distinct from v_school_id then
      raise exception 'CROSS_SCHOOL: classes.level_id';
    end if;
  end if;

  if length(trim(coalesce(p_name,''))) = 0 then
    raise exception 'CLASS_NAME_REQUIRED';
  end if;

  if length(trim(coalesce(p_code,''))) = 0 then
    raise exception 'CLASS_CODE_REQUIRED';
  end if;

  if p_capacity is not null and p_capacity <= 0 then
    raise exception 'CLASS_CAPACITY_INVALID';
  end if;

  update public.classes
  set
    school_year_id = p_school_year_id,
    level_id = p_level_id,
    name = trim(p_name),
    code = trim(p_code),
    section = nullif(trim(p_section), ''),
    room_name = nullif(trim(p_room_name), ''),
    capacity = p_capacity
  where id = p_class_id;

  return p_class_id;
end;
$$;

create or replace function app.validate_enrollment_step8()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
declare
  student_school uuid;
  year_school uuid;
  class_school uuid;
  class_year uuid;
  class_level uuid;
  level_school uuid;
  admission_school uuid;
  admission_year uuid;
  admission_status app.enrollment_status;
begin
  select school_id into student_school from public.students where id = new.student_id;
  select school_id into year_school from public.school_years where id = new.school_year_id;

  if student_school is null or student_school <> new.school_id then
    raise exception 'ENROLLMENT_CROSS_SCHOOL_STUDENT';
  end if;

  if year_school is null or year_school <> new.school_id then
    raise exception 'ENROLLMENT_CROSS_SCHOOL_YEAR';
  end if;

  if new.requested_level_id is not null then
    select school_id into level_school from public.levels where id = new.requested_level_id;
    if level_school is null or level_school <> new.school_id then
      raise exception 'ENROLLMENT_CROSS_SCHOOL_LEVEL';
    end if;
  end if;

  if new.class_id is not null then
    select school_id, school_year_id, level_id
      into class_school, class_year, class_level
      from public.classes
     where id = new.class_id;

    if class_school is null or class_school <> new.school_id then
      raise exception 'ENROLLMENT_CROSS_SCHOOL_CLASS';
    end if;

    if class_year <> new.school_year_id then
      raise exception 'ENROLLMENT_CLASS_YEAR_MISMATCH';
    end if;

    if new.requested_level_id is not null and class_level is not null and class_level is distinct from new.requested_level_id then
      raise exception 'ENROLLMENT_CLASS_LEVEL_MISMATCH';
    end if;
  end if;

  if new.source_admission_id is not null then
    select school_id, desired_year_id, status
      into admission_school, admission_year, admission_status
      from public.admission_applications
     where id = new.source_admission_id;

    if admission_school is null or admission_school <> new.school_id then
      raise exception 'ENROLLMENT_CROSS_SCHOOL_ADMISSION';
    end if;

    if admission_year is distinct from new.school_year_id then
      raise exception 'ENROLLMENT_ADMISSION_YEAR_MISMATCH';
    end if;

    if admission_status not in ('approved','enrolled') then
      raise exception 'ENROLLMENT_SOURCE_ADMISSION_NOT_APPROVED';
    end if;
  end if;

  if new.status in ('approved','enrolled','completed') and new.class_id is null then
    raise exception 'ENROLLMENT_CLASS_REQUIRED';
  end if;

  if new.status in ('pending','approved','enrolled') then
    if exists (
      select 1
        from public.enrollments e
       where e.student_id = new.student_id
         and e.school_year_id = new.school_year_id
         and e.status in ('pending','approved','enrolled')
         and e.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) then
      raise exception 'DUPLICATE_ACTIVE_ENROLLMENT';
    end if;
  end if;

  if new.class_id is not null and new.status in ('approved','enrolled') then
    if (select capacity from public.classes where id = new.class_id) is not null
       and (
         select count(*)
           from public.enrollments e
          where e.class_id = new.class_id
            and e.status = 'enrolled'
            and e.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
       ) >= (select capacity from public.classes where id = new.class_id) then
      raise exception 'CLASS_CAPACITY_REACHED';
    end if;
  end if;

  return new;
end;
$$;

commit;