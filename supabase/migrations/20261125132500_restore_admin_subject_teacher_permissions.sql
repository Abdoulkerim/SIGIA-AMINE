begin;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('subjects.manage', 'teachers.manage')
where r.code = 'admin'
on conflict do nothing;

commit;
