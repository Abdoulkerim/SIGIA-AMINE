begin;

-- Keep the two top-level roles in sync with every permission currently
-- available, including view permissions added after the original role seed.
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code in ('founder', 'super_admin')
on conflict do nothing;

commit;
