begin;
create or replace function app.apply_education_stage()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_school_id uuid := nullif(v_row ->> 'school_id', '')::uuid;
  v_stage text := app.normalize_education_stage(v_row ->> 'education_stage');
  v_linked_stage text;
  v_linked_school uuid;
  v_candidate_stage text;
  v_candidate_school uuid;
  v_user_stage text;
  v_link uuid;
  v_related_access boolean := false;
  v_is_service_teacher_link boolean := false;
  v_is_authorized_wushu_assignment boolean := false;
  v_is_authorized_wushu_session boolean := false;
begin
  -- A privileged Edge Function may link a teacher login to an existing
  -- teacher profile in the same school. This exception does not cover other
  -- service-role writes or accounts without the teacher role.
  if tg_table_name = 'employees'
     and tg_op = 'UPDATE'
     and coalesce(auth.role(), '') = 'service_role' then
    if old.user_id is null and new.user_id is not null and new.status = 'active' then
      select
        exists (
          select 1
          from public.teacher_profiles tp
          where tp.employee_id = new.id
        )
        and exists (
          select 1
          from public.users u
          join public.user_roles ur on ur.user_id = u.id
          join public.roles r on r.id = ur.role_id
          where u.id = new.user_id
            and u.school_id = new.school_id
            and u.status = 'active'::app.user_status
            and ur.school_id = new.school_id
            and ur.is_active
            and r.code = 'teacher'
        )
      into v_is_service_teacher_link;
    end if;
  end if;

  if nullif(v_row ->> 'student_id', '') is not null then
    select s.education_stage, s.school_id into v_candidate_stage, v_candidate_school
      from public.students s where s.id = (v_row ->> 'student_id')::uuid;
    v_linked_stage := v_candidate_stage;
    v_linked_school := v_candidate_school;
    if v_linked_stage is not null then
      if v_stage is not null and v_stage <> v_linked_stage then
        raise exception 'CROSS_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
      end if;
      v_stage := v_linked_stage;
    end if;
  end if;
  if tg_table_name = 'student_wushu'
     and auth.uid() is not null
     and v_linked_stage is not null
     and (app.has_permission('wushu.manage', v_school_id) or app.is_super_admin())
     and exists (
       select 1 from public.students s
       where s.id = nullif(v_row ->> 'student_id', '')::uuid
         and s.school_id = v_school_id
     )
     and exists (
       select 1 from public.wushu_groups g
       where g.id = nullif(v_row ->> 'group_id', '')::uuid
         and g.school_id = v_school_id
         and g.is_active
     ) then
    v_is_authorized_wushu_assignment := true;
  end if;
  if tg_table_name = 'wushu_sessions'
     and auth.uid() is not null
     and (app.has_permission('wushu.manage', v_school_id) or app.is_super_admin())
     and exists (
       select 1 from public.wushu_groups g
       where g.id = nullif(v_row ->> 'group_id', '')::uuid
         and g.school_id = v_school_id
         and (g.is_active or (tg_op = 'UPDATE' and g.id = old.group_id))
         and (v_stage is null or g.education_stage is null or g.education_stage = v_stage)
     ) then
    v_is_authorized_wushu_session := true;
    if v_stage is null then
      select g.education_stage into v_stage
      from public.wushu_groups g
      where g.id = nullif(v_row ->> 'group_id', '')::uuid;
    end if;
  end if;
  if nullif(v_row ->> 'class_id', '') is not null then
    select c.education_stage, c.school_id into v_candidate_stage, v_candidate_school
      from public.classes c where c.id = (v_row ->> 'class_id')::uuid;
    if v_candidate_stage is not null then
      if v_stage is not null and v_stage <> v_candidate_stage then
        raise exception 'CROSS_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
      end if;
      v_stage := v_candidate_stage;
    end if;
    if v_linked_stage is not null and v_candidate_stage is not null and v_linked_stage <> v_candidate_stage then
      raise exception 'CROSS_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
    end if;
    if v_linked_school is not null and v_candidate_school is not null and v_linked_school <> v_candidate_school then
      raise exception 'CROSS_SCHOOL: %', tg_table_name using errcode = '23514';
    end if;
    if v_linked_school is null then v_linked_school := v_candidate_school; end if;
    if v_school_id is not null and v_candidate_school is not null and v_school_id <> v_candidate_school then
      raise exception 'CROSS_SCHOOL: %', tg_table_name using errcode = '23514';
    end if;
  end if;
  foreach v_link in array array[
    nullif(v_row ->> 'level_id', '')::uuid,
    nullif(v_row ->> 'desired_level_id', '')::uuid,
    nullif(v_row ->> 'requested_level_id', '')::uuid
  ] loop
    if v_link is not null then
      select coalesce(l.education_stage, app.normalize_education_stage(l.education_cycle)), l.school_id
        into v_candidate_stage, v_candidate_school from public.levels l where l.id = v_link;
      if v_candidate_stage is not null then
        if v_stage is not null and v_stage <> v_candidate_stage then
          raise exception 'CROSS_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
        end if;
        v_stage := v_candidate_stage;
      end if;
      if v_linked_stage is not null and v_candidate_stage is not null and v_linked_stage <> v_candidate_stage then
        raise exception 'CROSS_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
      end if;
      if v_linked_school is not null and v_candidate_school is not null and v_linked_school <> v_candidate_school then
        raise exception 'CROSS_SCHOOL: %', tg_table_name using errcode = '23514';
      end if;
      if v_linked_school is null then v_linked_school := v_candidate_school; end if;
      if v_school_id is not null and v_candidate_school is not null and v_school_id <> v_candidate_school then
        raise exception 'CROSS_SCHOOL: %', tg_table_name using errcode = '23514';
      end if;
    end if;
  end loop;
  if v_stage is null and v_linked_stage is not null then
    v_stage := v_linked_stage;
  end if;
  if nullif(v_row ->> 'recipient_user_id', '') is not null then
    select u.education_stage, u.school_id into v_candidate_stage, v_candidate_school
      from public.users u where u.id = (v_row ->> 'recipient_user_id')::uuid;
  elsif nullif(v_row ->> 'user_id', '') is not null and tg_table_name <> 'users' then
    select u.education_stage, u.school_id into v_candidate_stage, v_candidate_school
      from public.users u where u.id = (v_row ->> 'user_id')::uuid;
  else
    v_candidate_stage := null;
    v_candidate_school := null;
  end if;
  if v_candidate_stage is not null then
    if v_stage is not null and v_stage <> v_candidate_stage and not v_is_authorized_wushu_assignment and not v_is_authorized_wushu_session then
      raise exception 'CROSS_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
    end if;
    if not v_is_authorized_wushu_assignment and not v_is_authorized_wushu_session then
      v_stage := v_candidate_stage;
    end if;
  end if;
  if v_linked_school is not null and v_candidate_school is not null and v_linked_school <> v_candidate_school then
    raise exception 'CROSS_SCHOOL: %', tg_table_name using errcode = '23514';
  end if;
  if v_linked_school is null then v_linked_school := v_candidate_school; end if;
  if v_school_id is not null and v_candidate_school is not null and v_school_id <> v_candidate_school then
    raise exception 'CROSS_SCHOOL: %', tg_table_name using errcode = '23514';
  end if;
  if v_school_id is null then
    v_school_id := v_linked_school;
  elsif v_linked_school is not null and v_school_id <> v_linked_school then
    raise exception 'CROSS_SCHOOL: %', tg_table_name using errcode = '23514';
  end if;

  if v_stage is null and tg_table_name = 'levels' then
    v_stage := coalesce(app.normalize_education_stage(v_row ->> 'education_cycle'), app.infer_education_stage((v_row ->> 'code') || ' ' || (v_row ->> 'name')));
  end if;
  if v_stage is null and tg_table_name = 'classes' then
    v_stage := app.infer_education_stage((v_row ->> 'code') || ' ' || (v_row ->> 'name'));
  end if;
  if v_stage is null and tg_table_name <> 'users' then
    select u.education_stage into v_user_stage from public.users u where u.id = (select auth.uid()) and u.status = 'active'::app.user_status;
    v_stage := app.normalize_education_stage(v_user_stage);
  end if;

  if nullif(v_row ->> 'student_id', '') is not null then
    v_related_access := app.can_access_student((v_row ->> 'student_id')::uuid);
  elsif tg_table_name = 'students' and nullif(v_row ->> 'id', '') is not null then
    v_related_access := app.can_access_student((v_row ->> 'id')::uuid);
  end if;
  if not v_related_access and nullif(v_row ->> 'class_id', '') is not null then
    v_related_access := app.can_access_class((v_row ->> 'class_id')::uuid);
  end if;
  if not v_related_access then
    foreach v_link in array array[
      nullif(v_row ->> 'level_id', '')::uuid,
      nullif(v_row ->> 'desired_level_id', '')::uuid,
      nullif(v_row ->> 'requested_level_id', '')::uuid
    ] loop
      if v_link is not null and app.can_access_level(v_link) then v_related_access := true; end if;
    end loop;
  end if;
  if not v_related_access and tg_table_name = 'parents' and (v_row ->> 'user_id')::uuid = (select auth.uid()) then
    v_related_access := true;
  end if;

  if v_stage is null and not v_is_service_teacher_link and not v_is_authorized_wushu_assignment and not v_is_authorized_wushu_session and not app.is_super_admin() and not v_related_access
     and not (tg_table_name = 'users' and app.has_permission('users.manage', v_school_id)) then
    raise exception 'EDUCATION_STAGE_REQUIRED: %', tg_table_name using errcode = '42501';
  end if;
  if v_stage is not null and not v_is_service_teacher_link and not v_is_authorized_wushu_assignment and not v_is_authorized_wushu_session and not app.can_access_education_stage(v_school_id, v_stage)
     and not v_related_access
     and not (tg_table_name = 'users' and app.has_permission('users.manage', v_school_id)) then
    raise exception 'FORBIDDEN_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
  end if;

  v_row := jsonb_set(v_row, '{education_stage}', coalesce(to_jsonb(v_stage), 'null'::jsonb), true);
  return jsonb_populate_record(new, v_row);
end;
$$;
-- Only active employees with an explicit Wushu teaching specialty can be selected as coaches.
drop function if exists public.list_wushu_coaches();
create function public.list_wushu_coaches()
returns table (id uuid, first_name text, last_name text)
language plpgsql stable security definer set search_path = '' as $$
declare v_school_id uuid;
begin
  select u.school_id into v_school_id
  from public.users u where u.id = (select auth.uid()) and u.status = 'active'::app.user_status;

  if v_school_id is null and not app.is_super_admin() then
    raise exception 'USER_WITHOUT_SCHOOL';
  end if;
  if not (app.is_super_admin() or (v_school_id is not null and (app.has_permission('wushu.view', v_school_id) or app.has_permission('wushu.manage', v_school_id) or app.has_role_code('direction', v_school_id) or app.has_role_code('founder', v_school_id)))) then
    raise exception 'INSUFFICIENT_WUSHU_PERMISSION';
  end if;

  return query
  select e.id, e.first_name, e.last_name
  from public.teacher_profiles tp
  join public.employees e on e.id = tp.employee_id
  where e.status = 'active'
    and (v_school_id is null or e.school_id = v_school_id)
    and concat_ws(' ', tp.speciality, tp.pedagogical_role, tp.diploma) ilike any (array['%wushu%', '%kung fu%', '%arts martiaux%'])
  order by e.last_name, e.first_name;
end;
$$;
revoke all on function public.list_wushu_coaches() from public, anon;
grant execute on function public.list_wushu_coaches() to authenticated;

create or replace function app.validate_wushu_session()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.group_id is null then
    raise exception 'wushu_sessions: groupe obligatoire';
  end if;
  if not exists (
    select 1 from public.wushu_groups g
    where g.id = new.group_id and g.school_id = new.school_id
      and (g.is_active or (tg_op = 'UPDATE' and new.group_id = old.group_id))
  ) then
    raise exception 'wushu_sessions: groupe invalide ou inactif';
  end if;
  if new.coach_employee_id is not null and not exists (
    select 1 from public.employees e
    where e.id = new.coach_employee_id and e.school_id = new.school_id
      and (e.status = 'active' or (tg_op = 'UPDATE' and new.coach_employee_id = old.coach_employee_id))
  ) then
    raise exception 'wushu_sessions: coach invalide';
  end if;
  return new;
end;
$$;

create or replace function public.create_wushu_session(
  p_group_id uuid, p_session_date date, p_session_type text, p_topic text default null,
  p_coach_employee_id uuid default null, p_notes text default null, p_progress_after numeric default null,
  p_is_published boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_school uuid; v_stage text; v_id uuid;
begin
  select school_id, education_stage into v_school, v_stage
  from public.wushu_groups where id = p_group_id and is_active;
  if v_school is null then raise exception 'Groupe Wushu introuvable ou inactif'; end if;
  if not (app.has_permission('wushu.manage', v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  insert into public.wushu_sessions(school_id, group_id, session_date, session_type, topic, coach_employee_id, notes, progress_after, is_published, education_stage)
  values(v_school, p_group_id, p_session_date, p_session_type, nullif(btrim(p_topic), ''), p_coach_employee_id, p_notes, p_progress_after, p_is_published, v_stage)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.create_wushu_session(uuid,date,text,text,uuid,text,numeric,boolean) from public, anon;
grant execute on function public.create_wushu_session(uuid,date,text,text,uuid,text,numeric,boolean) to authenticated;

create or replace function public.update_wushu_session(
  p_session_id uuid, p_group_id uuid, p_session_date date, p_session_type text,
  p_topic text default null, p_coach_employee_id uuid default null, p_notes text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_school uuid; v_stage text; v_old_group uuid;
begin
  select ws.school_id, ws.group_id into v_school, v_old_group from public.wushu_sessions ws where ws.id = p_session_id;
  if v_school is null then raise exception 'Séance Wushu introuvable'; end if;
  if not (app.has_permission('wushu.manage', v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  select g.education_stage into v_stage from public.wushu_groups g where g.id = p_group_id and g.school_id = v_school and (g.is_active or p_group_id = v_old_group);
  if not found then raise exception 'Groupe Wushu invalide ou inactif'; end if;
  update public.wushu_sessions
  set group_id = p_group_id, session_date = p_session_date, session_type = p_session_type,
      topic = nullif(btrim(p_topic), ''), coach_employee_id = p_coach_employee_id,
      notes = p_notes, education_stage = v_stage
  where id = p_session_id and school_id = v_school;
  return p_session_id;
end;
$$;
revoke all on function public.update_wushu_session(uuid,uuid,date,text,text,uuid,text) from public, anon;
grant execute on function public.update_wushu_session(uuid,uuid,date,text,text,uuid,text) to authenticated;

create or replace function public.delete_wushu_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_school uuid;
begin
  select ws.school_id into v_school from public.wushu_sessions ws where ws.id = p_session_id;
  if v_school is null then raise exception 'Séance Wushu introuvable'; end if;
  if not (app.has_permission('wushu.manage', v_school) or app.is_super_admin()) then raise exception 'Permission Wushu insuffisante'; end if;
  delete from public.wushu_sessions where id = p_session_id and school_id = v_school;
end;
$$;
revoke all on function public.delete_wushu_session(uuid) from public, anon;
grant execute on function public.delete_wushu_session(uuid) to authenticated;

commit;



