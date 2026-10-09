-- SIGIA-AMINE
-- Migration 031: Documents / Communication workflows
-- Etape 23
-- Source fonctionnelle: cahier des charges Al Amine (documents, archives, notifications, annonces,
-- convocations/rappels, informations aux parents et communications internes).

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- 1. DOCUMENTS: versionning, demandes et traçabilité
-- =========================================================
alter table public.document_types add column if not exists description text;
alter table public.document_types add column if not exists sort_order integer not null default 0;
alter table public.document_types add column if not exists updated_at timestamptz not null default now();

drop trigger if exists trg_document_types_updated_at on public.document_types;
create trigger trg_document_types_updated_at
before update on public.document_types
for each row execute function app.set_updated_at();

create table if not exists public.document_versions(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  version_no integer not null check(version_no > 0),
  file_path text not null,
  file_name text not null,
  mime_type text,
  file_size bigint check(file_size is null or file_size >= 0),
  checksum text,
  uploaded_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(document_id,version_no),
  unique(document_id,file_path)
);

create table if not exists public.document_requests(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  document_type_id uuid not null references public.document_types(id) on delete restrict,
  student_id uuid references public.students(id) on delete cascade,
  parent_id uuid references public.parents(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete cascade,
  requested_by uuid not null references public.users(id) on delete restrict,
  status text not null default 'pending' check(status in ('pending','approved','rejected','fulfilled','cancelled')),
  requested_at timestamptz not null default now(),
  due_at timestamptz,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  fulfilled_document_id uuid references public.documents(id) on delete set null,
  notes text,
  check(num_nonnulls(student_id,parent_id,employee_id) = 1)
);

create table if not exists public.document_access_logs(
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  action text not null check(action in ('view','download','archive','restore','upload')),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);


-- Référentiel documentaire de départ, sans imposer d'autres documents que ceux cités dans le cahier des charges.
insert into public.document_types(school_id,code,name,module,description,sort_order)
select s.id,v.code,v.name,'administration',v.description,v.ord
from public.schools s
cross join (values
 ('dossier_inscription','Dossier d''inscription','Dossier administratif numérique de l''élève',10),
 ('fiche_inscription','Fiche d''inscription','Fiche d''inscription administrative',20),
 ('certificat_scolarite','Certificat de scolarité','Certificat attestant la scolarité de l''élève',30),
 ('attestation','Attestation','Attestation administrative générique',40),
 ('autre_admin','Autre document administratif','Autre pièce administrative classée et archivée',50)
) as v(code,name,description,ord)
on conflict(school_id,code) do nothing;

create index if not exists idx_document_versions_document on public.document_versions(document_id,version_no desc);
create index if not exists idx_document_requests_school_status on public.document_requests(school_id,status,requested_at desc);
create index if not exists idx_document_requests_student on public.document_requests(student_id,requested_at desc);
create index if not exists idx_document_access_document on public.document_access_logs(document_id,created_at desc);
create index if not exists idx_documents_type_status on public.documents(school_id,document_type_id,status,created_at desc);

-- =========================================================
-- 2. COMMUNICATION: file d'envoi et suivi
-- =========================================================
create table if not exists public.announcement_deliveries(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  recipient_user_id uuid not null references public.users(id) on delete cascade,
  channel text not null check(channel in ('in_app','email','sms','whatsapp','push')),
  status text not null default 'queued' check(status in ('queued','sent','failed','cancelled')),
  queued_at timestamptz not null default now(),
  sent_at timestamptz,
  failed_at timestamptz,
  error_message text,
  unique(announcement_id,recipient_user_id,channel)
);

alter table public.announcements add column if not exists updated_at timestamptz not null default now();
alter table public.announcements add column if not exists published_by uuid references public.users(id) on delete set null;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'announcements_status_check'
      AND conrelid = 'public.announcements'::regclass
  ) THEN
    alter table public.announcements add constraint announcements_status_check
      check(status in ('draft','published','archived','cancelled'));
  END IF;
END $$;

drop trigger if exists trg_announcements_updated_at on public.announcements;
create trigger trg_announcements_updated_at
before update on public.announcements
for each row execute function app.set_updated_at();

create index if not exists idx_announcements_school_status on public.announcements(school_id,status,published_at desc);
create index if not exists idx_announcement_deliveries_recipient on public.announcement_deliveries(recipient_user_id,status,queued_at desc);
create index if not exists idx_announcement_deliveries_announcement on public.announcement_deliveries(announcement_id,status);

-- =========================================================
-- 3. HELPERS SECURISES
-- =========================================================
create or replace function app.storage_document_id(p_path text)
returns uuid
language plpgsql immutable strict
as $$
declare v uuid;
begin
  begin
    v := split_part(p_path,'/',2)::uuid;
  exception when others then
    return null;
  end;
  return v;
end $$;

create or replace function app.can_view_document(p_document_id uuid)
returns boolean
language sql stable security definer set search_path=public,app
as $$
  select exists(
    select 1
    from public.documents d
    where d.id = p_document_id
      and (
        app.has_permission('documents.view',d.school_id)
        or app.has_permission('documents.manage',d.school_id)
        or (d.student_id is not null and (app.is_self_student(d.student_id) or app.is_parent_of_student(d.student_id)))
        or (d.parent_id is not null and exists(select 1 from public.parents p where p.id=d.parent_id and p.user_id=auth.uid()))
        or (d.employee_id is not null and exists(select 1 from public.employees e where e.id=d.employee_id and e.user_id=auth.uid()))
        or app.is_super_admin()
      )
  )
$$;

create or replace function app.can_manage_documents(p_school_id uuid)
returns boolean
language sql stable security definer set search_path=public,app
as $$ select app.has_permission('documents.manage',p_school_id) or app.is_super_admin() $$;

create or replace function app.can_manage_communication(p_school_id uuid)
returns boolean
language sql stable security definer set search_path=public,app
as $$ select app.has_permission('communication.manage',p_school_id) or app.is_super_admin() $$;

-- =========================================================
-- 4. RPC DOCUMENTS
-- =========================================================
create or replace function public.create_document_type(
  p_code text, p_name text, p_module text default null,
  p_description text default null
)
returns uuid
language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.users where id=auth.uid();
  if v_school is null or not app.can_manage_documents(v_school) then
    raise exception 'FORBIDDEN: documents.manage required';
  end if;
  insert into public.document_types(school_id,code,name,module,description)
  values(v_school,trim(p_code),trim(p_name),nullif(trim(p_module),''),nullif(trim(p_description),''))
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.create_document_type(text,text,text,text) from public;
grant execute on function public.create_document_type(text,text,text,text) to authenticated;

create or replace function public.register_uploaded_document(
  p_document_id uuid,
  p_document_type_id uuid,
  p_student_id uuid,
  p_parent_id uuid,
  p_employee_id uuid,
  p_reference text,
  p_title text,
  p_file_path text,
  p_file_name text,
  p_mime_type text,
  p_file_size bigint,
  p_issued_at date default null,
  p_expires_at date default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid; v_type_school uuid; v_entity_school uuid; v_id uuid;
begin
  select school_id into v_school from public.users where id=auth.uid();
  if v_school is null or not app.can_manage_documents(v_school) then raise exception 'FORBIDDEN: documents.manage required'; end if;
  if p_document_id is null then v_id:=gen_random_uuid(); else v_id:=p_document_id; end if;
  select school_id into v_type_school from public.document_types where id=p_document_type_id;
  if v_type_school is distinct from v_school then raise exception 'CROSS_SCHOOL: document_type'; end if;
  if num_nonnulls(p_student_id,p_parent_id,p_employee_id)>1 then raise exception 'INVALID_OWNER: document owner must be unique'; end if;
  if p_student_id is not null then select school_id into v_entity_school from public.students where id=p_student_id; end if;
  if p_parent_id is not null then select school_id into v_entity_school from public.parents where id=p_parent_id; end if;
  if p_employee_id is not null then select school_id into v_entity_school from public.employees where id=p_employee_id; end if;
  if (p_student_id is not null or p_parent_id is not null or p_employee_id is not null) and v_entity_school is distinct from v_school then raise exception 'CROSS_SCHOOL: document_owner'; end if;
  if split_part(p_file_path,'/',1) <> v_school::text or split_part(p_file_path,'/',2)::uuid is distinct from v_id then
    raise exception 'INVALID_STORAGE_PATH: expected school_id/document_id/file_name';
  end if;
  insert into public.documents(id,school_id,document_type_id,student_id,parent_id,employee_id,reference,title,file_path,file_name,mime_type,file_size,status,issued_at,expires_at,metadata,created_by)
  values(v_id,v_school,p_document_type_id,p_student_id,p_parent_id,p_employee_id,nullif(trim(p_reference),''),trim(p_title),p_file_path,trim(p_file_name),p_mime_type,p_file_size,'active',p_issued_at,p_expires_at,coalesce(p_metadata,'{}'::jsonb),auth.uid())
  returning id into v_id;
  insert into public.document_versions(school_id,document_id,version_no,file_path,file_name,mime_type,file_size,uploaded_by)
  values(v_school,v_id,1,p_file_path,trim(p_file_name),p_mime_type,p_file_size,auth.uid());
  insert into public.document_access_logs(school_id,document_id,user_id,action,metadata)
  values(v_school,v_id,auth.uid(),'upload','{}'::jsonb);
  return v_id;
end $$;
revoke all on function public.register_uploaded_document(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,bigint,date,date,jsonb) from public;
grant execute on function public.register_uploaded_document(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,bigint,date,date,jsonb) to authenticated;

create or replace function public.archive_document(p_document_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid;
begin
  select school_id into v_school from public.documents where id=p_document_id;
  if v_school is null or not app.can_manage_documents(v_school) then raise exception 'FORBIDDEN: documents.manage required'; end if;
  update public.documents set status='archived',archived_at=coalesce(archived_at,now()) where id=p_document_id;
  insert into public.document_access_logs(school_id,document_id,user_id,action,metadata)
  values(v_school,p_document_id,auth.uid(),'archive',jsonb_build_object('reason',coalesce(p_reason,'')));
end $$;
revoke all on function public.archive_document(uuid,text) from public;
grant execute on function public.archive_document(uuid,text) to authenticated;

create or replace function public.create_document_request(
  p_document_type_id uuid,p_student_id uuid default null,p_parent_id uuid default null,p_employee_id uuid default null,p_due_at timestamptz default null,p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid; v_type_school uuid; v_id uuid; v_allowed boolean := false;
begin
  select school_id into v_school from public.users where id=auth.uid();
  select school_id into v_type_school from public.document_types where id=p_document_type_id;
  if v_school is null or v_type_school is distinct from v_school then raise exception 'INVALID_SCHOOL'; end if;
  if num_nonnulls(p_student_id,p_parent_id,p_employee_id)<>1 then raise exception 'INVALID_OWNER'; end if;
  if app.can_manage_documents(v_school) then v_allowed:=true;
  elsif p_student_id is not null then v_allowed:=app.is_self_student(p_student_id) or app.is_parent_of_student(p_student_id);
  elsif p_parent_id is not null then v_allowed:=exists(select 1 from public.parents p where p.id=p_parent_id and p.user_id=auth.uid());
  elsif p_employee_id is not null then v_allowed:=exists(select 1 from public.employees e where e.id=p_employee_id and e.user_id=auth.uid());
  end if;
  if not v_allowed then raise exception 'FORBIDDEN'; end if;
  insert into public.document_requests(school_id,document_type_id,student_id,parent_id,employee_id,requested_by,due_at,notes)
  values(v_school,p_document_type_id,p_student_id,p_parent_id,p_employee_id,auth.uid(),p_due_at,nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.create_document_request(uuid,uuid,uuid,uuid,timestamptz,text) from public;
grant execute on function public.create_document_request(uuid,uuid,uuid,uuid,timestamptz,text) to authenticated;

create or replace function public.review_document_request(p_request_id uuid,p_status text,p_document_id uuid default null,p_notes text default null)
returns void language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid; v_valid boolean := false;
begin
  select school_id into v_school from public.document_requests where id=p_request_id;
  if v_school is null or not app.can_manage_documents(v_school) then raise exception 'FORBIDDEN'; end if;
  if p_status not in ('approved','rejected','fulfilled','cancelled') then raise exception 'INVALID_STATUS'; end if;
  if p_status='fulfilled' and p_document_id is null then raise exception 'DOCUMENT_REQUIRED'; end if;
  if p_document_id is not null and not exists(select 1 from public.documents d where d.id=p_document_id and d.school_id=v_school) then raise exception 'CROSS_SCHOOL: document'; end if;
  update public.document_requests
  set status=p_status,reviewed_by=auth.uid(),reviewed_at=now(),fulfilled_document_id=case when p_status='fulfilled' then p_document_id else fulfilled_document_id end,notes=coalesce(nullif(trim(p_notes),''),notes)
  where id=p_request_id;
end $$;
revoke all on function public.review_document_request(uuid,text,uuid,text) from public;
grant execute on function public.review_document_request(uuid,text,uuid,text) to authenticated;

-- =========================================================
-- 5. RPC COMMUNICATION
-- =========================================================
create or replace function public.create_announcement(
  p_title text,p_content text,p_audience jsonb,p_expires_at timestamptz default null
)
returns uuid language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.users where id=auth.uid();
  if v_school is null or not app.can_manage_communication(v_school) then raise exception 'FORBIDDEN: communication.manage required'; end if;
  if jsonb_typeof(p_audience) <> 'object' then raise exception 'INVALID_AUDIENCE'; end if;
  if coalesce(p_audience->>'type','') not in ('all_users','all_staff','all_parents','class','role','users') then raise exception 'INVALID_AUDIENCE_TYPE'; end if;
  if p_audience->>'type'='class' and (p_audience->>'class_id') is null then raise exception 'class_id required'; end if;
  if p_audience->>'type'='class' and (p_audience->>'school_year_id') is null then raise exception 'school_year_id required'; end if;
  if p_audience->>'type'='role' and (p_audience->>'role_code') is null then raise exception 'role_code required'; end if;
  if p_audience->>'type'='users' and jsonb_typeof(p_audience->'user_ids') <> 'array' then raise exception 'user_ids required'; end if;
  insert into public.announcements(school_id,title,content,audience,expires_at,status,created_by)
  values(v_school,trim(p_title),trim(p_content),p_audience,p_expires_at,'draft',auth.uid()) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.create_announcement(text,text,jsonb,timestamptz) from public;
grant execute on function public.create_announcement(text,text,jsonb,timestamptz) to authenticated;

create or replace function public.publish_announcement(p_announcement_id uuid)
returns integer language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid; v_type text; v_count integer := 0;
begin
  select school_id,audience->>'type' into v_school,v_type from public.announcements where id=p_announcement_id for update;
  if v_school is null or not app.can_manage_communication(v_school) then raise exception 'FORBIDDEN'; end if;
  if exists(select 1 from public.announcements where id=p_announcement_id and status='published') then return 0; end if;
  if v_type='class' and not exists(
    select 1 from public.classes c where c.id=(select (audience->>'class_id')::uuid from public.announcements where id=p_announcement_id) and c.school_id=v_school
  ) then raise exception 'INVALID_CLASS'; end if;

  with targets as (
    select u.id as user_id
    from public.users u
    where u.school_id=v_school and u.status='active'
      and v_type='all_users'
    union
    select u.id
    from public.users u
    where u.school_id=v_school and u.status='active'
      and v_type='all_staff'
      and exists(select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=u.id and ur.is_active=true and r.code not in ('parent','student'))
    union
    select p.user_id
    from public.parents p
    where p.school_id=v_school and p.user_id is not null and v_type='all_parents'
    union
    select distinct s.user_id as user_id
    from public.enrollments e
    join public.students s on s.id=e.student_id
    where e.school_id=v_school and e.class_id=(select (audience->>'class_id')::uuid from public.announcements where id=p_announcement_id)
      and e.school_year_id=(select (audience->>'school_year_id')::uuid from public.announcements where id=p_announcement_id)
      and e.status='enrolled'
      and s.user_id is not null
      and v_type='class'
    union
    select distinct p.user_id as user_id
    from public.enrollments e
    join public.student_parents sp on sp.student_id=e.student_id and sp.receives_notifications=true
    join public.parents p on p.id=sp.parent_id
    where e.school_id=v_school and e.class_id=(select (audience->>'class_id')::uuid from public.announcements where id=p_announcement_id)
      and e.school_year_id=(select (audience->>'school_year_id')::uuid from public.announcements where id=p_announcement_id)
      and e.status='enrolled'
      and p.user_id is not null
      and v_type='class'
    union
    select u.id
    from public.users u
    join public.user_roles ur on ur.user_id=u.id and ur.is_active=true
    join public.roles r on r.id=ur.role_id
    where u.school_id=v_school and u.status='active' and v_type='role' and r.code=(select audience->>'role_code' from public.announcements where id=p_announcement_id)
    union
    select (jsonb_array_elements_text((select audience->'user_ids' from public.announcements where id=p_announcement_id)))::uuid
    where v_type='users'
  ), distinct_targets as (
    select distinct user_id from targets where user_id is not null
      and exists(select 1 from public.users u where u.id=targets.user_id and u.school_id=v_school and u.status='active')
  )
  insert into public.notifications(school_id,recipient_user_id,title,body,notification_type,related_table,related_id,sent_at)
  select v_school,user_id,(select title from public.announcements where id=p_announcement_id),(select content from public.announcements where id=p_announcement_id),'announcement','announcements',p_announcement_id,now()
  from distinct_targets
  on conflict do nothing;

  with targets as (
    select distinct n.recipient_user_id from public.notifications n where n.related_table='announcements' and n.related_id=p_announcement_id
  ), prefs as (
    select t.recipient_user_id,
      coalesce(np.email_enabled,false) email_enabled,
      coalesce(np.sms_enabled,false) sms_enabled,
      coalesce(np.whatsapp_enabled,false) whatsapp_enabled,
      coalesce(np.push_enabled,false) push_enabled
    from targets t left join public.notification_preferences np on np.user_id=t.recipient_user_id
  )
  insert into public.announcement_deliveries(school_id,announcement_id,recipient_user_id,channel,status)
  select v_school,p_announcement_id,recipient_user_id,'in_app','sent' from prefs
  union all select v_school,p_announcement_id,recipient_user_id,'email','queued' from prefs where email_enabled
  union all select v_school,p_announcement_id,recipient_user_id,'sms','queued' from prefs where sms_enabled
  union all select v_school,p_announcement_id,recipient_user_id,'whatsapp','queued' from prefs where whatsapp_enabled
  union all select v_school,p_announcement_id,recipient_user_id,'push','queued' from prefs where push_enabled
  on conflict do nothing;

  update public.announcements set status='published',published_at=now(),published_by=auth.uid() where id=p_announcement_id;
  select count(*) into v_count from public.notifications where related_table='announcements' and related_id=p_announcement_id;
  return v_count;
end $$;
revoke all on function public.publish_announcement(uuid) from public;
grant execute on function public.publish_announcement(uuid) to authenticated;

create or replace function public.archive_announcement(p_announcement_id uuid)
returns void language plpgsql security definer set search_path=public,app
as $$
declare v_school uuid;
begin
  select school_id into v_school from public.announcements where id=p_announcement_id;
  if v_school is null or not app.can_manage_communication(v_school) then raise exception 'FORBIDDEN'; end if;
  update public.announcements set status='archived' where id=p_announcement_id;
end $$;
revoke all on function public.archive_announcement(uuid) from public;
grant execute on function public.archive_announcement(uuid) to authenticated;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void language sql security definer set search_path=public,app
as $$
  update public.notifications set read_at=now() where id=p_notification_id and recipient_user_id=auth.uid();
$$;
revoke all on function public.mark_notification_read(uuid) from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;

-- =========================================================
-- 6. RLS / GRANTS / STORAGE
-- =========================================================
alter table public.document_versions enable row level security;
alter table public.document_requests enable row level security;
alter table public.document_access_logs enable row level security;
alter table public.announcement_deliveries enable row level security;

drop policy if exists document_versions_select_step23 on public.document_versions;
create policy document_versions_select_step23 on public.document_versions for select using(app.can_view_document(document_id));
drop policy if exists document_versions_manage_step23 on public.document_versions;
create policy document_versions_manage_step23 on public.document_versions for all using(app.can_manage_documents(school_id)) with check(app.can_manage_documents(school_id));

drop policy if exists document_requests_select_step23 on public.document_requests;
create policy document_requests_select_step23 on public.document_requests for select using(
  app.can_manage_documents(school_id)
  or requested_by=auth.uid()
  or (student_id is not null and (app.is_self_student(student_id) or app.is_parent_of_student(student_id)))
  or (parent_id is not null and exists(select 1 from public.parents p where p.id=parent_id and p.user_id=auth.uid()))
  or (employee_id is not null and exists(select 1 from public.employees e where e.id=employee_id and e.user_id=auth.uid()))
);
drop policy if exists document_requests_manage_step23 on public.document_requests;
create policy document_requests_manage_step23 on public.document_requests for update using(app.can_manage_documents(school_id)) with check(app.can_manage_documents(school_id));

drop policy if exists document_access_logs_select_step23 on public.document_access_logs;
create policy document_access_logs_select_step23 on public.document_access_logs for select using(app.can_manage_documents(school_id) or user_id=auth.uid());
revoke insert,update,delete on public.document_access_logs from authenticated;
grant select on public.document_access_logs to authenticated;

drop policy if exists announcements_select_step23 on public.announcements;
create policy announcements_select_step23 on public.announcements for select using(app.can_manage_communication(school_id) or (status='published' and (expires_at is null or expires_at>now()) and exists(select 1 from public.notifications n where n.related_table='announcements' and n.related_id=id and n.recipient_user_id=auth.uid())) or app.is_super_admin());
drop policy if exists announcements_manage_step23 on public.announcements;
create policy announcements_manage_step23 on public.announcements for update using(app.can_manage_communication(school_id)) with check(app.can_manage_communication(school_id));
revoke insert,update,delete on public.announcements from authenticated;
grant select on public.announcements to authenticated;

drop policy if exists announcement_deliveries_select_step23 on public.announcement_deliveries;
create policy announcement_deliveries_select_step23 on public.announcement_deliveries for select using(app.can_manage_communication(school_id) or recipient_user_id=auth.uid());
revoke insert,update,delete on public.announcement_deliveries from authenticated;
grant select on public.announcement_deliveries to authenticated;

-- Notifications: recipients can read/update only themselves; managers can supervise.
drop policy if exists notifications_insert_step23 on public.notifications;
drop policy if exists notifications_delete_step23 on public.notifications;
revoke insert,delete on public.notifications from authenticated;
grant select,update on public.notifications to authenticated;

-- Harden document storage: path = school_id/document_id/file.
drop policy if exists storage_school_documents_select on storage.objects;
create policy storage_school_documents_select on storage.objects for select to authenticated
using(
  bucket_id='school-documents'
  and app.storage_school_id(name) in (select app.my_school_ids())
  and app.can_view_document(app.storage_document_id(name))
);
drop policy if exists storage_school_documents_insert on storage.objects;
create policy storage_school_documents_insert on storage.objects for insert to authenticated
with check(
  bucket_id='school-documents'
  and app.storage_school_id(name) in (select app.my_school_ids())
  and app.can_manage_documents(app.storage_school_id(name))
);
drop policy if exists storage_school_documents_update on storage.objects;
create policy storage_school_documents_update on storage.objects for update to authenticated
using(bucket_id='school-documents' and app.can_manage_documents(app.storage_school_id(name)))
with check(bucket_id='school-documents' and app.can_manage_documents(app.storage_school_id(name)));
drop policy if exists storage_school_documents_delete on storage.objects;
create policy storage_school_documents_delete on storage.objects for delete to authenticated
using(bucket_id='school-documents' and app.can_manage_documents(app.storage_school_id(name)));

commit;
