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
        select 1 from public.users u
        where u.id = (select auth.uid())
          and u.status = 'active'::app.user_status
          and u.school_id = p_school_id
          and u.education_stage = app.normalize_education_stage(p_stage)
          and not app.has_role_code('parent', p_school_id)
      )
    )
$$;
