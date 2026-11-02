begin;

-- Founders may work across all education stages. Staff who also have a parent
-- role keep access to their assigned stage when they also hold a staff role;
-- parent-only accounts remain limited to their linked children.
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
      and app.has_role_code('founder', p_school_id)
    )
    or (
      p_school_id is not null
      and app.normalize_education_stage(p_stage) is not null
      and exists (
        select 1
        from public.users u
        where u.id = (select auth.uid())
          and u.status = 'active'::app.user_status
          and u.school_id = p_school_id
          and u.education_stage = app.normalize_education_stage(p_stage)
          and (
            not app.has_role_code('parent', p_school_id)
            or exists (
              select 1
              from app.my_role_codes(p_school_id) as assigned_role(role_code)
              where assigned_role.role_code not in ('parent', 'student')
            )
          )
      )
    )
$$;

-- Employee dossiers are school-wide master data, not cycle-bound student data.
-- Keep access governed by the existing school/HR/teacher policies instead.
drop trigger if exists trg_apply_education_stage on public.employees;
update public.employees
set education_stage = null
where education_stage is not null;

drop policy if exists education_stage_boundary on public.employees;

commit;
