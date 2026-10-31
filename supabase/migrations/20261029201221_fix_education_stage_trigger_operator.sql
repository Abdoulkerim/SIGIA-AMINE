begin;

-- Parenthesize JSON text extraction before concatenation; otherwise PostgreSQL
-- can parse the expression as the unsupported text ->> unknown operator.
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
begin
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
    if v_stage is not null and v_stage <> v_candidate_stage then
      raise exception 'CROSS_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
    end if;
    v_stage := v_candidate_stage;
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

  if v_stage is null and not app.is_super_admin() and not v_related_access
     and not (tg_table_name = 'users' and app.has_permission('users.manage', v_school_id)) then
    raise exception 'EDUCATION_STAGE_REQUIRED: %', tg_table_name using errcode = '42501';
  end if;
  if v_stage is not null and not app.can_access_education_stage(v_school_id, v_stage)
     and not v_related_access
     and not (tg_table_name = 'users' and app.has_permission('users.manage', v_school_id)) then
    raise exception 'FORBIDDEN_EDUCATION_STAGE: %', tg_table_name using errcode = '42501';
  end if;

  v_row := jsonb_set(v_row, '{education_stage}', coalesce(to_jsonb(v_stage), 'null'::jsonb), true);
  return jsonb_populate_record(new, v_row);
end;
$$;

commit;

