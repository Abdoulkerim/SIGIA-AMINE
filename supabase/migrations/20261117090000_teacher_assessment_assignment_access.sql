begin;

-- Teachers should create assessments through their own class/subject assignments,
-- not through the broad school-wide management permission.
delete from public.role_permissions rp
using public.roles r, public.permissions p
where rp.role_id = r.id
  and rp.permission_id = p.id
  and r.code = 'teacher'
  and p.code = 'assessments.manage';

commit;
