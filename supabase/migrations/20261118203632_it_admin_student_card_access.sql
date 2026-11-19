create or replace function public.get_student_cards()
returns table (
  student_number text,
  first_name text,
  last_name text,
  class_name text,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
begin
  select u.school_id into v_school_id
  from public.users u
  where u.id = auth.uid() and u.status = 'active'::app.user_status;

  if v_school_id is null then
    raise exception 'Aucun établissement associé à ce compte.' using errcode = '42501';
  end if;

  if not (
    app.has_role_code('it_admin', v_school_id)
    or app.has_role_code('founder', v_school_id)
    or app.is_super_admin()
  ) then
    raise exception 'Accès aux cartes scolaires refusé.' using errcode = '42501';
  end if;

  return query
  select
    s.student_number,
    s.first_name,
    s.last_name,
    coalesce((
      select c.name
      from public.enrollments e
      join public.classes c on c.id = e.class_id and c.school_id = v_school_id
      where e.student_id = s.id
        and e.school_id = v_school_id
        and e.status = 'enrolled'
      order by e.created_at desc
      limit 1
    ), 'Non inscrit') as class_name,
    s.status::text
  from public.students s
  where s.school_id = v_school_id
  order by s.last_name, s.first_name
  limit 1000;
end;
$$;

revoke all on function public.get_student_cards() from public, anon;
grant execute on function public.get_student_cards() to authenticated;
