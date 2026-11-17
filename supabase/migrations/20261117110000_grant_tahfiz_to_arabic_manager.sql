begin;

-- The Arabic supervisor is responsible for the shared Tahfiz/Arabic program
-- and therefore needs the same Tahfiz module access as the Tahfiz supervisor.
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'arabic_manager'
  and p.code in ('tahfiz.view', 'tahfiz.manage')
on conflict do nothing;

commit;
