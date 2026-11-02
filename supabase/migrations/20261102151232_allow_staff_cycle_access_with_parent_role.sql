-- Keep parent-only accounts scoped to their linked children while allowing
-- staff accounts that also act as parents to use their assigned school cycle.
-- Creation checks in the application already authorize staff by role/permission;
-- this predicate must not silently remove their cycle access because of the
-- additional parent role.
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
