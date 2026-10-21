begin;

alter table public.users
  add column if not exists education_stage text;

alter table public.classes
  add column if not exists education_stage text;

alter table public.students
  add column if not exists education_stage text;

alter table public.levels
  add column if not exists education_stage text;

create or replace function app.normalize_education_stage(p_stage text)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select case
    when p_stage is null or btrim(p_stage) = '' then null
    when regexp_replace(lower(btrim(p_stage)), '[^a-z0-9]+', '', 'g') in ('maternelle', 'prescolaire', 'preschool') then 'maternelle'
    when regexp_replace(lower(btrim(p_stage)), '[^a-z0-9]+', '', 'g') in ('primaire', 'primary', 'elementaire') then 'primaire'
    when regexp_replace(lower(btrim(p_stage)), '[^a-z0-9]+', '', 'g') in ('secondaire', 'secondary', 'college', 'lycee') then 'secondaire'
    when regexp_replace(lower(btrim(p_stage)), '[^a-z0-9]+', '', 'g') in ('formation', 'centreformation', 'centredeformation', 'formationprofessionnelle', 'professionnelle') then 'formation'
    when regexp_replace(lower(btrim(p_stage)), '[^a-z0-9]+', '', 'g') in ('autre', 'other', 'superieur', 'superior') then 'autre'
    else null
  end
$$;

create or replace function app.infer_education_stage(p_value text)
returns text
language plpgsql
immutable
set search_path = pg_catalog, app
as $$
declare
  v text := lower(coalesce(p_value, ''));
begin
  if v ~ '(maternelle|prescolaire|petite section|moyenne section|grande section|(^|[^a-z])ps[0-9]?([^a-z]|$)|(^|[^a-z])ms[0-9]?([^a-z]|$)|(^|[^a-z])gs[0-9]?([^a-z]|$))' then
    return 'maternelle';
  elsif v ~ '(primaire|elementaire|(^|[^a-z])(cp|ce|cm)[0-9]?([^a-z]|$))' then
    return 'primaire';
  elsif v ~ '(secondaire|college|lycee|sixieme|cinquieme|quatrieme|troisieme|seconde|premiere|terminale|(^|[^a-z])(6|5|4|3|2|1|tle|tle)[a-z]?([^a-z]|$))' then
    return 'secondaire';
  elsif v ~ '(formation|apprentissage|(^|[^a-z])cfa([^a-z]|$))' then
    return 'formation';
  end if;
  return null;
end;
$$;

-- SECURITY DEFINER read RPCs bypass table RLS. Run read-only APIs as the caller
-- so the restrictive cycle policies below also apply inside RPCs and views.
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.prosecdef
      and p.proname ~ '^(get|list|search|find|view|report|dashboard|calculate|preview|fetch)_'
  loop
    execute format('alter function %s security invoker', f.signature);
  end loop;
end;
$$;

alter view if exists public.v_class_effectives set (security_invoker = true);
alter view if exists public.v_student_financial_summary set (security_invoker = true);

update public.levels
set education_stage = coalesce(
  app.normalize_education_stage(education_cycle),
  app.infer_education_stage(code || ' ' || name)
)
where education_stage is null;

update public.classes c
set education_stage = coalesce(
  l.education_stage,
  app.normalize_education_stage(l.education_cycle),
  app.infer_education_stage(c.code || ' ' || c.name)
)
from public.levels l
where c.level_id = l.id and c.education_stage is null;

update public.classes c
set education_stage = app.infer_education_stage(c.code || ' ' || c.name)
where c.education_stage is null;

update public.students s
set education_stage = c.education_stage
from public.enrollments e
join public.classes c on c.id = e.class_id
where e.student_id = s.id and s.education_stage is null
  and c.education_stage is not null;

alter table public.users
  add constraint users_education_stage_check
  check (education_stage is null or education_stage in ('maternelle', 'primaire', 'secondaire', 'formation', 'autre'));
alter table public.classes
  add constraint classes_education_stage_check
  check (education_stage is null or education_stage in ('maternelle', 'primaire', 'secondaire', 'formation', 'autre'));
alter table public.students
  add constraint students_education_stage_check
  check (education_stage is null or education_stage in ('maternelle', 'primaire', 'secondaire', 'formation', 'autre'));
alter table public.levels
  add constraint levels_education_stage_check
  check (education_stage is null or education_stage in ('maternelle', 'primaire', 'secondaire', 'formation', 'autre'));

create or replace function app.can_access_education_stage(p_school_id uuid, p_stage text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, app
as $$
  select app.is_super_admin()
    or (
      p_school_id is not null
      and app.normalize_education_stage(p_stage) is not null
      and exists (
        select 1 from public.users u
        where u.id = (select auth.uid())
          and u.status = 'active'::app.user_status
          and u.school_id = p_school_id
          and u.education_stage = app.normalize_education_stage(p_stage)
          and not app.has_role_code('parent', p_school_id)
      )
    )
$$;

create or replace function app.can_access_student(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, app
as $$
  select exists (
    select 1 from public.students s
    where s.id = p_student_id
      and (
        app.can_access_education_stage(s.school_id, s.education_stage)
        or app.is_parent_of_student(s.id)
        or app.is_self_student(s.id)
      )
  )
$$;

create or replace function app.can_access_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, app
as $$
  select exists (
    select 1 from public.classes c
    where c.id = p_class_id
      and (
        app.can_access_education_stage(c.school_id, c.education_stage)
        or exists (
          select 1 from public.enrollments e
          join public.students s on s.id = e.student_id
          where e.class_id = c.id
            and app.can_access_student(s.id)
            and (c.education_stage is null or c.education_stage = s.education_stage)
        )
      )
  )
$$;

create or replace function app.can_access_level(p_level_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, app
as $$
  select exists (
    select 1 from public.levels l
    where l.id = p_level_id
      and app.can_access_education_stage(l.school_id, coalesce(l.education_stage, app.normalize_education_stage(l.education_cycle)))
  )
$$;

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

-- Keep each user's assigned cycle immutable to that user. Only an access manager
-- (or super administrator) may assign another cycle.
drop trigger if exists trg_protect_user_education_stage on public.users;
create trigger trg_protect_user_education_stage
before update of education_stage on public.users
for each row execute function app.apply_education_stage();

-- Operational rows inherit their stage from their student, class, level, recipient,
-- or the signed-in user's assigned stage. School settings and school years remain shared.
do $$
declare
  t record;
begin
  for t in
    select c.table_name,
           bool_or(c.column_name = 'school_id') as has_school_id
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name in (select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE')
    group by c.table_name
    having (bool_or(c.column_name = 'school_id') or bool_or(c.column_name in ('student_id', 'class_id', 'level_id', 'desired_level_id', 'requested_level_id')))
       and c.table_name not in ('users', 'user_roles', 'school_settings', 'school_years', 'academic_periods', 'audit_logs', 'document_types')
  loop
    execute format('alter table public.%I add column if not exists education_stage text', t.table_name);
  end loop;
end;
$$;

-- Backfill stage tags for rows that already point to a student, class, or level.
do $$
declare
  t record;
begin
  for t in
    select table_name,
      bool_or(column_name = 'student_id') as has_student,
      bool_or(column_name = 'class_id') as has_class,
      bool_or(column_name in ('level_id', 'desired_level_id', 'requested_level_id')) as has_level
    from information_schema.columns
    where table_schema = 'public'
      and table_name in (select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE')
    group by table_name
    having bool_or(column_name = 'education_stage')
      and table_name not in ('users', 'user_roles', 'school_settings', 'school_years', 'academic_periods', 'audit_logs', 'document_types')
  loop
    if t.has_student then
      execute format('update public.%I r set education_stage = s.education_stage from public.students s where r.student_id = s.id and r.education_stage is null and s.education_stage is not null', t.table_name);
    end if;
    if t.has_class then
      execute format('update public.%I r set education_stage = c.education_stage from public.classes c where r.class_id = c.id and r.education_stage is null and c.education_stage is not null', t.table_name);
    end if;
    if t.has_level then
      execute format($query$
        update public.%I r
        set education_stage = coalesce(l.education_stage, app.normalize_education_stage(l.education_cycle))
        from public.levels l
        where l.id = coalesce(
          nullif(to_jsonb(r) ->> 'level_id', '')::uuid,
          nullif(to_jsonb(r) ->> 'desired_level_id', '')::uuid,
          nullif(to_jsonb(r) ->> 'requested_level_id', '')::uuid
        )
          and r.education_stage is null
          and coalesce(l.education_stage, app.normalize_education_stage(l.education_cycle)) is not null
      $query$, t.table_name);
    end if;
  end loop;
end;
$$;

-- If an establishment's historical classes belong to exactly one known cycle,
-- use that cycle for older school-level records that have no class/student link.
-- For schools with several cycles, ambiguous records stay unclassified.
do $$
declare
  t record;
begin
  for t in
    select c.table_name
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name in (select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE')
    group by c.table_name
    having bool_or(c.column_name = 'education_stage') and bool_or(c.column_name = 'school_id')
       and c.table_name not in ('users', 'school_settings', 'school_years', 'academic_periods', 'audit_logs')
  loop
    execute format($query$
      update public.%I r
      set education_stage = scope.education_stage
      from (
        select school_id, min(education_stage) as education_stage
        from public.classes
        where education_stage is not null
        group by school_id
        having count(distinct education_stage) = 1
      ) scope
      where r.school_id = scope.school_id and r.education_stage is null
    $query$, t.table_name);
  end loop;
end;
$$;

-- Apply stage inheritance after backfilling historical rows so this migration's
-- data repair does not get mistaken for a user request to change cycles.
do $$
declare
  t record;
begin
  for t in
    select table_name
    from information_schema.columns
    where table_schema = 'public' and column_name = 'education_stage'
      and table_name in (select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE')
      and table_name not in ('users', 'school_settings', 'school_years', 'academic_periods', 'audit_logs')
    group by table_name
  loop
    execute format('drop trigger if exists trg_apply_education_stage on public.%I', t.table_name);
    execute format('create trigger trg_apply_education_stage before insert or update on public.%I for each row execute function app.apply_education_stage()', t.table_name);
    execute format('alter table public.%I enable row level security', t.table_name);
  end loop;
end;
$$;

create or replace function app.propagate_student_education_stage()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app
as $$
declare
  v_stage text;
begin
  select c.education_stage into v_stage from public.classes c where c.id = new.class_id;
  if v_stage is not null then
    update public.students s set education_stage = v_stage where s.id = new.student_id and s.education_stage is distinct from v_stage;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_propagate_student_education_stage on public.enrollments;
create trigger trg_propagate_student_education_stage
after insert or update of class_id on public.enrollments
for each row execute function app.propagate_student_education_stage();

-- Enforce stage boundaries in RLS, even when a page forgets a client-side filter.
do $$
declare
  t record;
  v_policy text;
  v_expr text;
  v_refs text;
  v_level_id_expr text;
  v_level_expr text;
  v_base_expr text;
begin
  for t in
    select c.table_name,
      bool_or(c.column_name = 'school_id') as has_school,
      bool_or(c.column_name = 'education_stage') as has_stage,
      bool_or(c.column_name = 'student_id') as has_student,
      bool_or(c.column_name = 'class_id') as has_class,
      bool_or(c.column_name = 'level_id') as has_level,
      bool_or(c.column_name = 'desired_level_id') as has_desired_level,
      bool_or(c.column_name = 'requested_level_id') as has_requested_level
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name in (select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE')
    group by c.table_name
    having bool_or(c.column_name = 'education_stage')
       and c.table_name not in ('school_settings', 'school_years', 'academic_periods', 'audit_logs')
  loop
    v_refs := concat_ws(', ',
      case when t.has_level then 'level_id' end,
      case when t.has_desired_level then 'desired_level_id' end,
      case when t.has_requested_level then 'requested_level_id' end
    );
    v_level_id_expr := case
      when nullif(v_refs, '') is null then null
      when (t.has_level::integer + t.has_desired_level::integer + t.has_requested_level::integer) > 1 then 'coalesce(' || v_refs || ')'
      else v_refs
    end;
    v_level_expr := case when v_level_id_expr is not null then 'app.can_access_level(' || v_level_id_expr || ')' else null end;
    if t.table_name = 'students' then
      v_expr := '(app.can_access_education_stage(school_id, education_stage) or app.can_access_student(id))';
    elsif t.table_name = 'users' then
      v_expr := '(id = (select auth.uid()) or app.is_super_admin() or app.has_permission(''users.manage'', school_id))';
    elsif t.table_name = 'parents' then
      v_expr := '(user_id = (select auth.uid()) or app.can_access_education_stage(school_id, education_stage))';
    else
      v_base_expr := case when t.has_school then 'app.can_access_education_stage(school_id, education_stage)' else 'false' end;
      if t.has_student then v_base_expr := v_base_expr || ' or app.can_access_student(student_id)'; end if;
      if t.has_class then v_base_expr := v_base_expr || ' or app.can_access_class(class_id)'; end if;
      if v_level_expr is not null then v_base_expr := v_base_expr || ' or ' || v_level_expr; end if;
      v_expr := '(' || v_base_expr || ')';
      if t.has_student then v_expr := v_expr || ' and (student_id is null or app.can_access_student(student_id))'; end if;
      if t.has_class then v_expr := v_expr || ' and (class_id is null or app.can_access_class(class_id))'; end if;
      if v_level_expr is not null then
        v_expr := v_expr || ' and (' || v_level_id_expr || ' is null or ' || v_level_expr || ')';
      end if;
    end if;
    if v_expr is null then continue; end if;

    v_policy := 'education_stage_boundary';
    execute format('drop policy if exists %I on public.%I', v_policy, t.table_name);
    execute format(
      'create policy %I on public.%I as restrictive for all to authenticated using (%s) with check (%s)',
      v_policy, t.table_name, v_expr, v_expr
    );
  end loop;
end;
$$;

-- Scope child tables whose parent carries the stage key.
do $$
begin
  if to_regclass('public.report_card_items') is not null then
    drop policy if exists education_stage_boundary on public.report_card_items;
    create policy education_stage_boundary on public.report_card_items as restrictive for all to authenticated
      using (exists (select 1 from public.report_cards r where r.id = report_card_id and app.can_access_student(r.student_id)))
      with check (exists (select 1 from public.report_cards r where r.id = report_card_id and app.can_access_student(r.student_id)));
  end if;
  if to_regclass('public.invoice_items') is not null then
    drop policy if exists education_stage_boundary on public.invoice_items;
    create policy education_stage_boundary on public.invoice_items as restrictive for all to authenticated
      using (exists (select 1 from public.invoices i where i.id = invoice_id and (i.student_id is null and app.can_access_education_stage(i.school_id, i.education_stage) or app.can_access_student(i.student_id))))
      with check (exists (select 1 from public.invoices i where i.id = invoice_id and (i.student_id is null and app.can_access_education_stage(i.school_id, i.education_stage) or app.can_access_student(i.student_id))));
  end if;
  if to_regclass('public.payment_allocations') is not null then
    drop policy if exists education_stage_boundary on public.payment_allocations;
    create policy education_stage_boundary on public.payment_allocations as restrictive for all to authenticated
      using (
        exists (select 1 from public.payments p where p.id = payment_id and (
          p.student_id is not null and app.can_access_student(p.student_id)
          or p.student_id is null and (
            app.can_access_education_stage(p.school_id, p.education_stage)
            or invoice_id is not null and exists (
              select 1 from public.invoices i where i.id = invoice_id
                and i.student_id is not null and app.can_access_student(i.student_id)
            )
          )
        ))
        and (invoice_id is null or exists (
          select 1 from public.invoices i where i.id = invoice_id
            and (i.student_id is not null and app.can_access_student(i.student_id)
              or i.student_id is null and app.can_access_education_stage(i.school_id, i.education_stage))
        ))
      )
      with check (
        exists (select 1 from public.payments p where p.id = payment_id and (
          p.student_id is not null and app.can_access_student(p.student_id)
          or p.student_id is null and (
            app.can_access_education_stage(p.school_id, p.education_stage)
            or invoice_id is not null and exists (
              select 1 from public.invoices i where i.id = invoice_id
                and i.student_id is not null and app.can_access_student(i.student_id)
            )
          )
        ))
        and (invoice_id is null or exists (
          select 1 from public.invoices i where i.id = invoice_id
            and (i.student_id is not null and app.can_access_student(i.student_id)
              or i.student_id is null and app.can_access_education_stage(i.school_id, i.education_stage))
        ))
      );
  end if;
end;
$$;

-- Private account data stays visible to its owner, even for school managers.
-- RLS restrictive policies are ANDed with existing role-based policies, so an
-- administrative permission cannot expose another user's private activity.
-- The trusted server-side bootstrap uses Supabase's service_role JWT to assign
-- the first privileged role; ordinary authenticated users remain subject to the guard.
create or replace function app.guard_user_role_assignment()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app, auth
as $$
declare
  v_role_code text;
  v_user_id uuid;
  v_role_id uuid;
  v_school_id uuid;
begin
  if tg_op = 'DELETE' then
    v_user_id := old.user_id;
    v_role_id := old.role_id;
    v_school_id := old.school_id;
  else
    v_user_id := new.user_id;
    v_role_id := new.role_id;
    v_school_id := new.school_id;
  end if;

  if coalesce(auth.role(), '') = 'service_role' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if v_user_id = (select auth.uid()) then
    raise exception 'CANNOT_CHANGE_OWN_ROLES';
  end if;

  select r.code into v_role_code from public.roles r where r.id = v_role_id;
  if v_role_code in ('super_admin', 'founder', 'it_admin')
     and not app.is_super_admin()
     and not app.has_role_code('founder', v_school_id) then
    raise exception 'FORBIDDEN_PRIVILEGED_ROLE_ASSIGNMENT';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop policy if exists account_private_owner_only on public.notifications;
create policy account_private_owner_only on public.notifications
  as restrictive for all to authenticated
  using (recipient_user_id = (select auth.uid()) or app.is_super_admin())
  with check (recipient_user_id = (select auth.uid()) or app.is_super_admin());

drop policy if exists account_private_owner_only on public.notification_preferences;
create policy account_private_owner_only on public.notification_preferences
  as restrictive for all to authenticated
  using (user_id = (select auth.uid()) or app.is_super_admin())
  with check (user_id = (select auth.uid()) or app.is_super_admin());

drop policy if exists account_private_owner_only on public.ai_conversations;
create policy account_private_owner_only on public.ai_conversations
  as restrictive for all to authenticated
  using (user_id = (select auth.uid()) or app.is_super_admin())
  with check (user_id = (select auth.uid()) or app.is_super_admin());

drop policy if exists account_private_owner_only on public.ai_messages;
create policy account_private_owner_only on public.ai_messages
  as restrictive for all to authenticated
  using (exists (
    select 1 from public.ai_conversations c
    where c.id = conversation_id
      and (c.user_id = (select auth.uid()) or app.is_super_admin())
  ))
  with check (exists (
    select 1 from public.ai_conversations c
    where c.id = conversation_id
      and (c.user_id = (select auth.uid()) or app.is_super_admin())
  ));

drop policy if exists account_private_owner_only on public.ai_runs;
create policy account_private_owner_only on public.ai_runs
  as restrictive for all to authenticated
  using (user_id = (select auth.uid()) or app.is_super_admin())
  with check (user_id = (select auth.uid()) or app.is_super_admin());

drop policy if exists account_private_owner_only on public.ai_tool_calls;
create policy account_private_owner_only on public.ai_tool_calls
  as restrictive for all to authenticated
  using (exists (
    select 1 from public.ai_runs r
    where r.id = run_id
      and (r.user_id = (select auth.uid()) or app.is_super_admin())
  ))
  with check (exists (
    select 1 from public.ai_runs r
    where r.id = run_id
      and (r.user_id = (select auth.uid()) or app.is_super_admin())
  ));

drop policy if exists account_private_owner_only on public.announcement_deliveries;
create policy account_private_owner_only on public.announcement_deliveries
  as restrictive for all to authenticated
  using (recipient_user_id = (select auth.uid()) or app.is_super_admin())
  with check (recipient_user_id = (select auth.uid()) or app.is_super_admin());

revoke all on function app.normalize_education_stage(text) from public, anon, authenticated;
revoke all on function app.infer_education_stage(text) from public, anon, authenticated;
revoke all on function app.can_access_education_stage(uuid, text) from public, anon;
revoke all on function app.can_access_student(uuid) from public, anon;
revoke all on function app.can_access_class(uuid) from public, anon;
revoke all on function app.can_access_level(uuid) from public, anon;
revoke all on function app.apply_education_stage() from public, anon, authenticated;
revoke all on function app.propagate_student_education_stage() from public, anon, authenticated;
grant execute on function app.can_access_education_stage(uuid, text) to authenticated;
grant execute on function app.can_access_student(uuid) to authenticated;
grant execute on function app.can_access_class(uuid) to authenticated;
grant execute on function app.can_access_level(uuid) to authenticated;

commit;
