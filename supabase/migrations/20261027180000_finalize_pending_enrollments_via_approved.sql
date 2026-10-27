create or replace function public.finalize_enrollment(
  p_enrollment_id uuid,
  p_class_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  v_school_id uuid;
  v_user_id uuid := auth.uid();
  v_enrollment public.enrollments%rowtype;
begin
  select * into v_enrollment
    from public.enrollments
   where id = p_enrollment_id
   for update;
  if not found then raise exception 'ENROLLMENT_NOT_FOUND'; end if;
  v_school_id := v_enrollment.school_id;

  if v_user_id is null or not (app.has_permission('enrollments.manage', v_school_id) or app.is_super_admin()) then
    raise exception 'FORBIDDEN_ENROLLMENT_MANAGE';
  end if;

  if v_enrollment.status not in ('pending','approved') then
    raise exception 'ENROLLMENT_NOT_READY_TO_FINALIZE';
  end if;

  if p_class_id is null then
    raise exception 'CLASS_REQUIRED_TO_FINALIZE';
  end if;

  -- The status trigger requires pending -> approved -> enrolled.
  if v_enrollment.status = 'pending' then
    update public.enrollments
       set class_id = p_class_id,
           status = 'approved',
           updated_at = now()
     where id = p_enrollment_id;
  else
    update public.enrollments
       set class_id = p_class_id,
           updated_at = now()
     where id = p_enrollment_id;
  end if;

  update public.enrollments
     set status = 'enrolled',
         updated_at = now()
   where id = p_enrollment_id;

  return jsonb_build_object('enrollment_id', p_enrollment_id, 'status', 'enrolled');
end;
$$;
