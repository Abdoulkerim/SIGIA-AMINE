begin;

create table if not exists public.user_access_stages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  education_stage text not null,
  created_at timestamptz not null default now(),
  unique(user_id, school_id, education_stage)
);

create index if not exists idx_user_access_stages_user_school
  on public.user_access_stages(user_id, school_id);

insert into public.user_access_stages(user_id, school_id, education_stage)
select u.id, u.school_id, u.education_stage
from public.users u
where u.school_id is not null
  and u.education_stage is not null
on conflict do nothing;

insert into public.user_access_stages(user_id, school_id, education_stage)
select distinct ur.user_id, ur.school_id, stage
from public.user_roles ur
join public.roles r on r.id = ur.role_id
cross join (values
  ('maternelle'),
  ('primaire'),
  ('secondaire'),
  ('formation'),
  ('autre')
) stages(stage)
where ur.is_active
  and ur.school_id is not null
  and r.code = 'arabic_manager'
on conflict do nothing;

alter table public.user_access_stages enable row level security;

revoke all on public.user_access_stages from anon, authenticated;
grant select, insert, update, delete on public.user_access_stages to authenticated;

drop policy if exists user_access_stages_manage on public.user_access_stages;
create policy user_access_stages_manage on public.user_access_stages
for all to authenticated
using (
  app.is_super_admin()
  or app.has_permission('users.roles.manage', school_id)
  or app.has_permission('users.manage', school_id)
)
with check (
  app.is_super_admin()
  or app.has_permission('users.roles.manage', school_id)
  or app.has_permission('users.manage', school_id)
);

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
        from public.user_access_stages uas
        where uas.user_id = (select auth.uid())
          and uas.school_id = p_school_id
          and uas.education_stage =
              app.normalize_education_stage(p_stage)
      )
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
          and u.education_stage =
              app.normalize_education_stage(p_stage)
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

revoke all on function app.can_access_education_stage(uuid, text) from public, anon;
grant execute on function app.can_access_education_stage(uuid, text) to authenticated;

commit;
