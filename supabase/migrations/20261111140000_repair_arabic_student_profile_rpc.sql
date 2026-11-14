begin;

alter table public.student_arabic
  add column if not exists arabic_full_name text;

create or replace function public.save_student_arabic_profile(
  p_student_id uuid,
  p_arabic_level_id uuid default null,
  p_teacher_id uuid default null,
  p_start_date date default null,
  p_status text default 'active',
  p_notes text default null,
  p_arabic_full_name text default null,
  p_first_name text default null,
  p_last_name text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_school uuid; v_profile_id uuid;
begin
    if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select s.school_id
  into v_school
  from public.students s
  where s.id = p_student_id;

  if v_school is null then
    raise exception 'STUDENT_NOT_FOUND';
  end if;

  if not coalesce(
    app.is_super_admin() or app.has_permission('arabic.manage', v_school),
    false
  ) then
    raise exception 'FORBIDDEN_ARABIC_MANAGE';
  end if;
    if p_status is null
     or p_status not in ('active', 'paused', 'completed', 'inactive') then
     raise exception 'Statut Arabe invalide';
   end if;
    if p_arabic_level_id is not null and not exists (
    select 1
    from public.arabic_levels l
    where l.id = p_arabic_level_id
      and l.school_id = v_school
  ) then
    raise exception 'Niveau Arabe hors établissement';
  end if;
  if p_teacher_id is not null and not exists(
    select 1
    from public.employees e
    where e.id = p_teacher_id
      and e.school_id = v_school
      and e.status = 'active'
  ) then
    raise exception 'Responsable Arabe invalide';
  end if;
  if p_notes is not null and length(p_notes)>1200 then raise exception 'Notes Arabe trop longues'; end if;
  if p_arabic_full_name is not null and length(btrim(p_arabic_full_name))>200 then raise exception 'Nom arabe trop long'; end if;
  if p_first_name is not null and (length(btrim(p_first_name))=0 or length(btrim(p_first_name))>120) then raise exception 'Prénom français invalide'; end if;
  if p_last_name is not null and (length(btrim(p_last_name))=0 or length(btrim(p_last_name))>120) then raise exception 'Nom français invalide'; end if;
    if p_first_name is not null or p_last_name is not null then

    if not coalesce(
      app.is_super_admin() or app.has_permission('students.manage', v_school),
      false
    ) then
      raise exception 'STUDENT_MANAGE_PERMISSION_REQUIRED';
    end if;

    update public.students
    set
      first_name = coalesce(nullif(btrim(p_first_name), ''), first_name),
      last_name = coalesce(nullif(btrim(p_last_name), ''), last_name)
    where id = p_student_id
      and school_id = v_school;

  end if;
  insert into public.student_arabic(school_id,student_id,arabic_level_id,assigned_teacher_id,start_date,status,notes,arabic_full_name)
  values(v_school,p_student_id,p_arabic_level_id,p_teacher_id,p_start_date,p_status,nullif(btrim(p_notes),''),nullif(btrim(p_arabic_full_name),''))
  on conflict (student_id) do update set arabic_level_id=excluded.arabic_level_id,assigned_teacher_id=excluded.assigned_teacher_id,
    start_date=excluded.start_date,status=excluded.status,notes=excluded.notes,
    arabic_full_name=excluded.arabic_full_name,updated_at=now()
  returning id into v_profile_id;
  return v_profile_id;
end;
$$;

revoke all on function public.save_student_arabic_profile(uuid,uuid,uuid,date,text,text,text,text,text) from public, anon;
grant execute on function public.save_student_arabic_profile(uuid,uuid,uuid,date,text,text,text,text,text) to authenticated;

commit;

notify pgrst, 'reload schema';
