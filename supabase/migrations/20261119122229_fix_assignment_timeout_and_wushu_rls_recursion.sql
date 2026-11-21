-- Avoid repeatedly traversing every student enrollment from the restrictive
-- teacher_assignments policy. Preserve the student/parent fallback for classes
-- that have no education stage configured.
create or replace function app.can_access_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, app
as $function$
  select exists (
    select 1
    from public.classes c
    where c.id = p_class_id
      and (
        app.can_access_education_stage(c.school_id, c.education_stage)
        or exists (
          select 1
          from public.enrollments e
          join public.students s on s.id = e.student_id
          where e.class_id = c.id
            and (c.education_stage is null or c.education_stage = s.education_stage)
            and (
              app.can_access_education_stage(s.school_id, s.education_stage)
              or app.is_parent_of_student(s.id)
              or app.is_self_student(s.id)
            )
        )
      )
  )
$function$;

revoke all on function app.can_access_class(uuid) from public, anon;
grant execute on function app.can_access_class(uuid) to authenticated;

-- Break the mutual RLS dependency: sessions SELECT used to read attendance,
-- while attendance SELECT read sessions. These SECURITY DEFINER predicates
-- evaluate the relationship without re-entering either table's RLS policy.
create or replace function app.can_read_wushu_session(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, app
set row_security = off
as $function$
  select exists (
    select 1
    from public.wushu_sessions ws
    where ws.id = p_session_id
      and (
        app.has_permission('wushu.view', ws.school_id)
        or app.has_permission('wushu.manage', ws.school_id)
        or app.has_role_code('direction', ws.school_id)
        or app.has_role_code('founder', ws.school_id)
        or app.is_super_admin()
        or exists (
          select 1
          from public.wushu_attendance wa
          join public.student_wushu sw on sw.student_id = wa.student_id
          where wa.session_id = ws.id
            and (app.is_self_student(sw.student_id) or app.is_parent_of_student(sw.student_id))
        )
      )
  )
$function$;

create or replace function app.can_read_wushu_attendance(p_session_id uuid, p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, app
set row_security = off
as $function$
  select exists (
    select 1
    from public.wushu_sessions ws
    where ws.id = p_session_id
      and (
        app.is_self_student(p_student_id)
        or app.is_parent_of_student(p_student_id)
        or app.has_permission('wushu.view', ws.school_id)
        or app.has_permission('wushu.manage', ws.school_id)
        or app.has_role_code('direction', ws.school_id)
        or app.has_role_code('founder', ws.school_id)
        or app.is_super_admin()
      )
  )
$function$;

revoke all on function app.can_read_wushu_session(uuid) from public, anon;
revoke all on function app.can_read_wushu_attendance(uuid, uuid) from public, anon;
grant execute on function app.can_read_wushu_session(uuid) to authenticated;
grant execute on function app.can_read_wushu_attendance(uuid, uuid) to authenticated;

drop policy if exists wushu_sessions_select_step21 on public.wushu_sessions;
create policy wushu_sessions_select_step21
on public.wushu_sessions
for select
to authenticated
using (app.can_read_wushu_session(id));

drop policy if exists wushu_attendance_select_step21 on public.wushu_attendance;
create policy wushu_attendance_select_step21
on public.wushu_attendance
for select
to authenticated
using (app.can_read_wushu_attendance(session_id, student_id));
