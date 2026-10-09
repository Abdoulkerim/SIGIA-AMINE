-- SIGIA-AMINE
-- Migration 026: Personnel / RH / Paie
-- Étape 18
-- Scope source: dossier administratif, fonction/service, contrats, présence/absences,
-- congés, rémunération, formations/compétences et historique professionnel.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- 1. PERMISSIONS FINES
-- =========================================================
insert into public.permissions(code,name,module,action,description) values
('hr.view','Consulter personnel','hr','view','Consulter les dossiers RH autorisés'),
('hr.manage','Gérer personnel','hr','manage','Créer/modifier les dossiers RH, contrats et congés'),
('payroll.view','Consulter paie','payroll','view','Consulter les périodes et bulletins de paie autorisés'),
('payroll.manage','Gérer paie','payroll','manage','Préparer, valider et clôturer la paie')
on conflict(code) do update set
  name=excluded.name,
  module=excluded.module,
  action=excluded.action,
  description=excluded.description;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.permissions p on p.code in ('hr.view','hr.manage','payroll.view','payroll.manage')
where r.code in ('super_admin','founder','direction')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.permissions p on p.code in ('hr.view','hr.manage','payroll.view','payroll.manage')
where r.code='hr_manager'
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.permissions p on p.code='payroll.view'
where r.code='accountant'
on conflict do nothing;

-- =========================================================
-- 2. TABLES COMPLEMENTAIRES FORMATIONS / COMPÉTENCES
-- =========================================================
create table if not exists public.employee_skills(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  skill_name text not null,
  level text,
  acquired_at date,
  notes text,
  created_at timestamptz not null default now(),
  unique(employee_id, skill_name)
);

create table if not exists public.employee_trainings(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  title text not null,
  provider text,
  start_date date,
  end_date date,
  certificate_reference text,
  status text not null default 'completed',
  notes text,
  created_at timestamptz not null default now(),
  check(end_date is null or start_date is null or end_date>=start_date)
);

-- =========================================================
-- 3. QUALITÉ ET INDEX RH
-- =========================================================
alter table public.employees
  drop constraint if exists employees_hr_status_check,
  drop constraint if exists employees_department_not_blank,
  drop constraint if exists employees_job_title_not_blank;

alter table public.employees
  add constraint employees_hr_status_check check(status in ('active','inactive','suspended','terminated','archived')),
  add constraint employees_department_not_blank check(department is null or length(trim(department))>0),
  add constraint employees_job_title_not_blank check(job_title is null or length(trim(job_title))>0);

alter table public.employee_contracts
  drop constraint if exists employee_contracts_status_check,
  drop constraint if exists employee_contracts_salary_check,
  drop constraint if exists employee_contracts_type_check;

alter table public.employee_contracts
  add constraint employee_contracts_status_check check(status in ('draft','active','suspended','terminated','expired','archived')),
  add constraint employee_contracts_salary_check check(salary is null or salary>=0),
  add constraint employee_contracts_type_check check(length(trim(contract_type))>0);

alter table public.employee_leaves
  add column if not exists decision_note text,
  drop constraint if exists employee_leaves_type_not_blank;
alter table public.employee_leaves
  add constraint employee_leaves_type_not_blank check(length(trim(leave_type))>0);

alter table public.payroll_periods
  drop constraint if exists payroll_period_status_check;
alter table public.payroll_periods
  add constraint payroll_period_status_check check(status in ('draft','open','approved','paid','closed','cancelled'));

alter table public.payroll_items
  add column if not exists paid_at timestamptz,
  add column if not exists paid_by uuid references public.users(id) on delete set null,
  add column if not exists notes text;

alter table public.payroll_items
  drop constraint if exists payroll_items_status_consistency_check;
alter table public.payroll_items
  add constraint payroll_items_status_consistency_check
  check(net_salary>=0);

create index if not exists idx_employee_contracts_employee_dates
  on public.employee_contracts(employee_id,start_date,end_date,status);
create index if not exists idx_employee_attendance_school_date_employee
  on public.employee_attendance(school_id,attendance_date,employee_id);
create index if not exists idx_employee_leaves_school_dates_status
  on public.employee_leaves(school_id,start_date,end_date,status,employee_id);
create index if not exists idx_employee_skills_school_employee
  on public.employee_skills(school_id,employee_id,skill_name);
create index if not exists idx_employee_trainings_school_employee_dates
  on public.employee_trainings(school_id,employee_id,start_date,end_date);
create index if not exists idx_payroll_periods_school_dates
  on public.payroll_periods(school_id,start_date,end_date,status);
create index if not exists idx_payroll_items_period_employee_status
  on public.payroll_items(payroll_period_id,employee_id,payment_status);

-- =========================================================
-- 4. TRIGGERS DE COHÉRENCE
-- =========================================================
create or replace function app.validate_employee_contract_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
begin
  select e.school_id into v_school
  from public.employees e
  where e.id = new.employee_id;

  if v_school is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  if new.end_date is not null and new.end_date < new.start_date then raise exception 'INVALID_CONTRACT_DATES'; end if;

  if new.status in ('active','suspended','draft') and exists(
    select 1
    from public.employee_contracts c
    where c.employee_id=new.employee_id
      and c.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
      and c.status in ('active','suspended','draft')
      and daterange(c.start_date,coalesce(c.end_date,'9999-12-31'::date),'[]')
          && daterange(new.start_date,coalesce(new.end_date,'9999-12-31'::date),'[]')
  ) then
    raise exception 'OVERLAPPING_EMPLOYEE_CONTRACT';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_employee_contract_integrity on public.employee_contracts;
create trigger trg_validate_employee_contract_integrity
before insert or update on public.employee_contracts
for each row execute function app.validate_employee_contract_integrity();

create or replace function app.validate_employee_attendance_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
begin
  select e.school_id into v_school from public.employees e where e.id=new.employee_id;
  if v_school is null or v_school<>new.school_id then raise exception 'CROSS_SCHOOL: employee_attendance'; end if;
  if new.check_in is not null and new.check_out is not null and new.check_out<new.check_in then
    raise exception 'INVALID_ATTENDANCE_TIMES';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_employee_attendance_integrity on public.employee_attendance;
create trigger trg_validate_employee_attendance_integrity
before insert or update on public.employee_attendance
for each row execute function app.validate_employee_attendance_integrity();

create or replace function app.validate_employee_leave_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
begin
  select e.school_id into v_school from public.employees e where e.id=new.employee_id;
  if v_school is null or v_school<>new.school_id then raise exception 'CROSS_SCHOOL: employee_leaves'; end if;
  if new.end_date<new.start_date then raise exception 'INVALID_LEAVE_DATES'; end if;
  if new.status in ('submitted','approved') and exists(
    select 1 from public.employee_leaves x
    where x.employee_id=new.employee_id
      and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
      and x.status in ('submitted','approved')
      and daterange(x.start_date,x.end_date,'[]') && daterange(new.start_date,new.end_date,'[]')
  ) then raise exception 'OVERLAPPING_LEAVE'; end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_employee_leave_integrity on public.employee_leaves;
create trigger trg_validate_employee_leave_integrity
before insert or update on public.employee_leaves
for each row execute function app.validate_employee_leave_integrity();

create or replace function app.validate_payroll_period_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.end_date<new.start_date then raise exception 'INVALID_PAYROLL_PERIOD_DATES'; end if;
  if exists(
    select 1 from public.payroll_periods p
    where p.school_id=new.school_id
      and p.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
      and p.status<>'cancelled'
      and daterange(p.start_date,p.end_date,'[]') && daterange(new.start_date,new.end_date,'[]')
  ) then raise exception 'OVERLAPPING_PAYROLL_PERIOD'; end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_payroll_period_integrity on public.payroll_periods;
create trigger trg_validate_payroll_period_integrity
before insert or update on public.payroll_periods
for each row execute function app.validate_payroll_period_integrity();

-- =========================================================
-- 5. RLS — DOSSIERS RH
-- =========================================================
alter table public.employee_skills enable row level security;
alter table public.employee_trainings enable row level security;

-- Employees: Data API lecture only; all writes pass through RPCs.
drop policy if exists employees_select_018 on public.employees;
drop policy if exists employees_insert_018 on public.employees;
drop policy if exists employees_update_018 on public.employees;
drop policy if exists employees_delete_018 on public.employees;
drop policy if exists employees_select_019 on public.employees;
drop policy if exists employees_insert_019 on public.employees;
drop policy if exists employees_update_019 on public.employees;
drop policy if exists employees_delete_019 on public.employees;
create policy employees_select_026 on public.employees
for select to authenticated using (
  app.is_super_admin()
  or (
    school_id in (select app.my_school_ids())
    and (
      user_id=auth.uid()
      or app.has_permission('hr.view',school_id)
      or app.has_permission('hr.manage',school_id)
      or app.has_role_code('direction',school_id)
      or app.has_role_code('founder',school_id)
      or (app.employee_is_teacher(id) and (app.has_permission('teachers.view',school_id) or app.has_permission('teachers.manage',school_id)))
    )
  )
);

drop policy if exists employee_contracts_manage_026 on public.employee_contracts;
drop policy if exists employee_attendance_manage_026 on public.employee_attendance;
drop policy if exists employee_leaves_manage_026 on public.employee_leaves;
drop policy if exists employee_skills_manage_026 on public.employee_skills;
drop policy if exists employee_trainings_manage_026 on public.employee_trainings;
drop policy if exists payroll_periods_manage_026 on public.payroll_periods;
drop policy if exists payroll_items_manage_026 on public.payroll_items;

-- Contracts: salary details are visible only to employee self, HR, direction or payroll.view.
drop policy if exists employee_contracts_secure on public.employee_contracts;
drop policy if exists employee_contracts_manage on public.employee_contracts;
create policy employee_contracts_select_026 on public.employee_contracts
for select to authenticated using (
  exists(select 1 from public.employees e where e.id=employee_id and (
    e.user_id=auth.uid()
    or app.has_permission('hr.view',e.school_id)
    or app.has_permission('hr.manage',e.school_id)
    or app.has_permission('payroll.view',e.school_id)
    or app.has_permission('payroll.manage',e.school_id)
    or app.has_role_code('direction',e.school_id)
    or app.has_role_code('founder',e.school_id)
    or app.is_super_admin()
  ))
);

-- Attendance: employee self can consult; only HR records official attendance.
drop policy if exists employee_attendance_delete_secure on public.employee_attendance;
drop policy if exists employee_attendance_insert_secure on public.employee_attendance;
drop policy if exists employee_attendance_select_secure on public.employee_attendance;
drop policy if exists employee_attendance_update_secure on public.employee_attendance;
drop policy if exists employee_attendance_secure on public.employee_attendance;
drop policy if exists employee_attendance_manage on public.employee_attendance;
create policy employee_attendance_select_026 on public.employee_attendance
for select to authenticated using (
  app.is_super_admin()
  or exists(select 1 from public.employees e where e.id=employee_id and (
    e.user_id=auth.uid()
    or app.has_permission('hr.view',e.school_id)
    or app.has_permission('hr.manage',e.school_id)
    or app.has_role_code('direction',e.school_id)
    or app.has_role_code('founder',e.school_id)
  ))
);

-- Leaves: read self/HR, mutations through RPC only for employee self and HR.
drop policy if exists employee_leaves_delete_secure on public.employee_leaves;
drop policy if exists employee_leaves_insert_secure on public.employee_leaves;
drop policy if exists employee_leaves_select_secure on public.employee_leaves;
drop policy if exists employee_leaves_update_secure on public.employee_leaves;
drop policy if exists employee_leaves_secure on public.employee_leaves;
drop policy if exists employee_leaves_manage on public.employee_leaves;
create policy employee_leaves_select_026 on public.employee_leaves
for select to authenticated using (
  app.is_super_admin()
  or exists(select 1 from public.employees e where e.id=employee_id and (
    e.user_id=auth.uid()
    or app.has_permission('hr.view',e.school_id)
    or app.has_permission('hr.manage',e.school_id)
    or app.has_role_code('direction',e.school_id)
    or app.has_role_code('founder',e.school_id)
  ))
);

-- Skills/training.
drop policy if exists employee_skills_select_026 on public.employee_skills;
drop policy if exists employee_skills_manage_026 on public.employee_skills;
drop policy if exists employee_trainings_select_026 on public.employee_trainings;
drop policy if exists employee_trainings_manage_026 on public.employee_trainings;
create policy employee_skills_select_026 on public.employee_skills
for select to authenticated using (
  app.is_super_admin()
  or exists(select 1 from public.employees e where e.id=employee_id and (
    e.user_id=auth.uid() or app.has_permission('hr.view',e.school_id) or app.has_permission('hr.manage',e.school_id)
    or app.has_role_code('direction',e.school_id) or app.has_role_code('founder',e.school_id)
  ))
);
create policy employee_trainings_select_026 on public.employee_trainings
for select to authenticated using (
  app.is_super_admin()
  or exists(select 1 from public.employees e where e.id=employee_id and (
    e.user_id=auth.uid() or app.has_permission('hr.view',e.school_id) or app.has_permission('hr.manage',e.school_id)
    or app.has_role_code('direction',e.school_id) or app.has_role_code('founder',e.school_id)
  ))
);

-- Payroll.
drop policy if exists payroll_periods_delete_secure on public.payroll_periods;
drop policy if exists payroll_periods_insert_secure on public.payroll_periods;
drop policy if exists payroll_periods_select_secure on public.payroll_periods;
drop policy if exists payroll_periods_update_secure on public.payroll_periods;
drop policy if exists payroll_periods_secure on public.payroll_periods;
drop policy if exists payroll_periods_manage on public.payroll_periods;
drop policy if exists payroll_items_secure on public.payroll_items;
drop policy if exists payroll_items_manage on public.payroll_items;
create policy payroll_periods_select_026 on public.payroll_periods
for select to authenticated using (
  app.is_super_admin()
  or app.has_permission('payroll.view',school_id)
  or app.has_permission('payroll.manage',school_id)
  or app.has_role_code('direction',school_id)
  or app.has_role_code('founder',school_id)
);
create policy payroll_items_select_026 on public.payroll_items
for select to authenticated using (
  app.is_super_admin()
  or exists(select 1 from public.payroll_periods pp where pp.id=payroll_period_id and (
    app.has_permission('payroll.view',pp.school_id)
    or app.has_permission('payroll.manage',pp.school_id)
    or app.has_role_code('direction',pp.school_id)
    or app.has_role_code('founder',pp.school_id)
  ))
);

revoke all on public.employees,public.employee_skills,public.employee_trainings,public.employee_contracts,public.employee_attendance,public.employee_leaves,public.payroll_periods,public.payroll_items from anon;
revoke insert,update,delete on public.employees,public.employee_skills,public.employee_trainings,public.employee_contracts,public.employee_attendance,public.employee_leaves,public.payroll_periods,public.payroll_items from authenticated;
grant select on public.employees,public.employee_skills,public.employee_trainings,public.employee_contracts,public.employee_attendance,public.employee_leaves,public.payroll_periods,public.payroll_items to authenticated;

-- =========================================================
-- 6. RPC RH
-- =========================================================
create or replace function public.create_employee(
  p_employee_number text,
  p_first_name text,
  p_last_name text,
  p_job_title text default null,
  p_department text default null,
  p_qualification text default null,
  p_hire_date date default null,
  p_gender app.gender_type default null,
  p_date_of_birth date default null,
  p_place_of_birth text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid;
  v_id uuid;
begin
  select school_id into v_school from public.users where id=auth.uid() and status='active';
  if v_school is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_HR_MANAGE'; end if;
  if length(trim(coalesce(p_employee_number,'')))=0 then raise exception 'EMPLOYEE_NUMBER_REQUIRED'; end if;
  if length(trim(coalesce(p_first_name,'')))=0 then raise exception 'FIRST_NAME_REQUIRED'; end if;
  if length(trim(coalesce(p_last_name,'')))=0 then raise exception 'LAST_NAME_REQUIRED'; end if;

  insert into public.employees(
    school_id,employee_number,first_name,last_name,job_title,department,qualification,hire_date,
    gender,date_of_birth,place_of_birth,phone,email,address,status
  ) values (
    v_school,trim(p_employee_number),trim(p_first_name),trim(p_last_name),nullif(trim(p_job_title),''),
    nullif(trim(p_department),''),nullif(trim(p_qualification),''),p_hire_date,p_gender,p_date_of_birth,
    nullif(trim(p_place_of_birth),''),nullif(trim(p_phone),''),nullif(trim(p_email),''),nullif(trim(p_address),''),'active'
  ) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.set_employee_status(p_employee_id uuid,p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid;
begin
  select school_id into v_school from public.employees where id=p_employee_id;
  if v_school is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  if p_status not in ('active','inactive','suspended','terminated','archived') then raise exception 'INVALID_EMPLOYEE_STATUS'; end if;
  if not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_HR_MANAGE'; end if;
  update public.employees set status=p_status,updated_at=now() where id=p_employee_id;
end;
$$;

create or replace function public.create_employee_contract(
  p_employee_id uuid,
  p_contract_type text,
  p_start_date date,
  p_end_date date default null,
  p_salary numeric default null,
  p_document_id uuid default null,
  p_status text default 'active'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.employees where id=p_employee_id;
  if v_school is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  if not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_HR_MANAGE'; end if;
  if p_end_date is not null and p_end_date<p_start_date then raise exception 'INVALID_CONTRACT_DATES'; end if;
  insert into public.employee_contracts(employee_id,contract_type,start_date,end_date,salary,status,document_id)
  values(p_employee_id,trim(p_contract_type),p_start_date,p_end_date,p_salary,p_status,p_document_id)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.record_employee_attendance(
  p_employee_id uuid,
  p_attendance_date date,
  p_status app.attendance_status,
  p_check_in time default null,
  p_check_out time default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.employees where id=p_employee_id;
  if v_school is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  if not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_HR_MANAGE'; end if;
  insert into public.employee_attendance(school_id,employee_id,attendance_date,status,check_in,check_out,notes)
  values(v_school,p_employee_id,p_attendance_date,p_status,p_check_in,p_check_out,nullif(trim(p_notes),''))
  on conflict(employee_id,attendance_date) do update set
    status=excluded.status,check_in=excluded.check_in,check_out=excluded.check_out,notes=excluded.notes
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.request_employee_leave(
  p_employee_id uuid,
  p_leave_type text,
  p_start_date date,
  p_end_date date,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_user_employee uuid; v_id uuid;
begin
  select school_id into v_school from public.employees where id=p_employee_id;
  if v_school is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  select id into v_user_employee from public.employees where user_id=auth.uid() and school_id=v_school;
  if v_user_employee<>p_employee_id and not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_LEAVE'; end if;
  insert into public.employee_leaves(school_id,employee_id,leave_type,start_date,end_date,reason,status)
  values(v_school,p_employee_id,trim(p_leave_type),p_start_date,p_end_date,nullif(trim(p_reason),''),'submitted')
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.decide_employee_leave(
  p_leave_id uuid,
  p_decision app.approval_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid;
begin
  select school_id into v_school from public.employee_leaves where id=p_leave_id;
  if v_school is null then raise exception 'LEAVE_NOT_FOUND'; end if;
  if not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_HR_MANAGE'; end if;
  if p_decision not in ('approved','rejected','cancelled') then raise exception 'INVALID_LEAVE_DECISION'; end if;
  update public.employee_leaves
  set status=p_decision,approved_by=case when p_decision='approved' then auth.uid() else approved_by end,
      decision_note=nullif(trim(p_reason),'')
  where id=p_leave_id;
end;
$$;

create or replace function public.add_employee_skill(
  p_employee_id uuid,
  p_skill_name text,
  p_level text default null,
  p_acquired_at date default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.employees where id=p_employee_id;
  if v_school is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  if not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_HR_MANAGE'; end if;
  insert into public.employee_skills(school_id,employee_id,skill_name,level,acquired_at,notes)
  values(v_school,p_employee_id,trim(p_skill_name),nullif(trim(p_level),''),p_acquired_at,nullif(trim(p_notes),''))
  on conflict(employee_id,skill_name) do update set level=excluded.level,acquired_at=excluded.acquired_at,notes=excluded.notes
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.add_employee_training(
  p_employee_id uuid,
  p_title text,
  p_provider text default null,
  p_start_date date default null,
  p_end_date date default null,
  p_certificate_reference text default null,
  p_status text default 'completed',
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.employees where id=p_employee_id;
  if v_school is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  if not app.has_permission('hr.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_HR_MANAGE'; end if;
  insert into public.employee_trainings(school_id,employee_id,title,provider,start_date,end_date,certificate_reference,status,notes)
  values(v_school,p_employee_id,trim(p_title),nullif(trim(p_provider),''),p_start_date,p_end_date,nullif(trim(p_certificate_reference),''),trim(p_status),nullif(trim(p_notes),''))
  returning id into v_id;
  return v_id;
end;
$$;

-- =========================================================
-- 7. RPC PAIE
-- =========================================================
create or replace function public.create_payroll_period(
  p_period_label text,
  p_start_date date,
  p_end_date date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_id uuid;
begin
  select school_id into v_school from public.users where id=auth.uid() and status='active';
  if v_school is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app.has_permission('payroll.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_PAYROLL_MANAGE'; end if;
  insert into public.payroll_periods(school_id,period_label,start_date,end_date,status)
  values(v_school,trim(p_period_label),p_start_date,p_end_date,'draft')
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.open_payroll_period(p_payroll_period_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_status text;
begin
  select school_id,status into v_school,v_status from public.payroll_periods where id=p_payroll_period_id;
  if v_school is null then raise exception 'PAYROLL_PERIOD_NOT_FOUND'; end if;
  if not app.has_permission('payroll.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_PAYROLL_MANAGE'; end if;
  if v_status not in ('draft','open') then raise exception 'PAYROLL_PERIOD_NOT_OPENABLE'; end if;
  update public.payroll_periods set status='open' where id=p_payroll_period_id;
end;
$$;

create or replace function public.generate_payroll(p_payroll_period_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school uuid; v_start date; v_end date; v_status text; v_count integer;
begin
  select school_id,start_date,end_date,status into v_school,v_start,v_end,v_status
  from public.payroll_periods where id=p_payroll_period_id for update;
  if v_school is null then raise exception 'PAYROLL_PERIOD_NOT_FOUND'; end if;
  if not app.has_permission('payroll.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_PAYROLL_MANAGE'; end if;
  if v_status not in ('draft','open') then raise exception 'PAYROLL_PERIOD_LOCKED'; end if;

  insert into public.payroll_items(payroll_period_id,employee_id,base_salary,allowances,deductions,payment_status)
  select
    p_payroll_period_id,
    e.id,
    coalesce(c.salary,0),
    0,
    0,
    'pending'::app.payment_status
  from public.employees e
  join public.employee_contracts c on c.employee_id=e.id
    and c.status='active'
    and c.start_date<=v_start
    and (c.end_date is null or c.end_date>=v_end)
  where e.school_id=v_school and e.status='active'
  on conflict(payroll_period_id,employee_id) do nothing;

  get diagnostics v_count = row_count;
  update public.payroll_periods set status='open' where id=p_payroll_period_id;
  return v_count;
end;
$$;

create or replace function public.update_payroll_item(
  p_payroll_item_id uuid,
  p_base_salary numeric,
  p_allowances numeric,
  p_deductions numeric,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_status text; v_net numeric;
begin
  select pp.school_id,pp.status into v_school,v_status
  from public.payroll_items pi join public.payroll_periods pp on pp.id=pi.payroll_period_id
  where pi.id=p_payroll_item_id;
  if v_school is null then raise exception 'PAYROLL_ITEM_NOT_FOUND'; end if;
  if not app.has_permission('payroll.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_PAYROLL_MANAGE'; end if;
  if v_status not in ('draft','open') then raise exception 'PAYROLL_PERIOD_LOCKED'; end if;
  if coalesce(p_base_salary,0)<0 or coalesce(p_allowances,0)<0 or coalesce(p_deductions,0)<0 then raise exception 'PAYROLL_VALUES_NEGATIVE'; end if;
  v_net:=coalesce(p_base_salary,0)+coalesce(p_allowances,0)-coalesce(p_deductions,0);
  if v_net<0 then raise exception 'PAYROLL_NET_NEGATIVE'; end if;
  update public.payroll_items
  set base_salary=p_base_salary,allowances=p_allowances,deductions=p_deductions,notes=nullif(trim(p_notes),''),payment_status='pending'
  where id=p_payroll_item_id;
end;
$$;

create or replace function public.approve_payroll(p_payroll_period_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_status text; v_total integer;
begin
  select school_id,status into v_school,v_status from public.payroll_periods where id=p_payroll_period_id for update;
  if v_school is null then raise exception 'PAYROLL_PERIOD_NOT_FOUND'; end if;
  if not app.has_permission('payroll.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_PAYROLL_MANAGE'; end if;
  if v_status not in ('open','draft') then raise exception 'PAYROLL_PERIOD_NOT_APPROVABLE'; end if;
  select count(*) into v_total from public.payroll_items where payroll_period_id=p_payroll_period_id;
  if v_total=0 then raise exception 'PAYROLL_EMPTY'; end if;
  update public.payroll_periods set status='approved' where id=p_payroll_period_id;
end;
$$;

create or replace function public.mark_payroll_item_paid(p_payroll_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_status text; v_item_status app.payment_status;
begin
  select pp.school_id,pp.status,pi.payment_status into v_school,v_status,v_item_status
  from public.payroll_items pi join public.payroll_periods pp on pp.id=pi.payroll_period_id
  where pi.id=p_payroll_item_id for update;
  if v_school is null then raise exception 'PAYROLL_ITEM_NOT_FOUND'; end if;
  if not app.has_permission('payroll.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_PAYROLL_MANAGE'; end if;
  if v_status<>'approved' then raise exception 'PAYROLL_NOT_APPROVED'; end if;
  if v_item_status='paid' then return; end if;
  update public.payroll_items set payment_status='paid',paid_at=now(),paid_by=auth.uid() where id=p_payroll_item_id;
  if not exists(select 1 from public.payroll_items where payroll_period_id=(select payroll_period_id from public.payroll_items where id=p_payroll_item_id) and payment_status not in ('paid','cancelled')) then
    update public.payroll_periods set status='paid' where id=(select payroll_period_id from public.payroll_items where id=p_payroll_item_id);
  end if;
end;
$$;

create or replace function public.close_payroll(p_payroll_period_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_school uuid; v_status text; v_pending integer;
begin
  select school_id,status into v_school,v_status from public.payroll_periods where id=p_payroll_period_id for update;
  if v_school is null then raise exception 'PAYROLL_PERIOD_NOT_FOUND'; end if;
  if not app.has_permission('payroll.manage',v_school) and not app.is_super_admin() then raise exception 'FORBIDDEN_PAYROLL_MANAGE'; end if;
  if v_status not in ('approved','paid') then raise exception 'PAYROLL_NOT_READY_TO_CLOSE'; end if;
  select count(*) into v_pending from public.payroll_items where payroll_period_id=p_payroll_period_id and payment_status not in ('paid','cancelled');
  if v_pending>0 then raise exception 'PAYROLL_UNPAID_ITEMS'; end if;
  update public.payroll_periods set status='closed' where id=p_payroll_period_id;
end;
$$;

-- =========================================================
-- 8. DASHBOARD RH
-- =========================================================
create or replace function public.get_hr_dashboard(p_school_id uuid,p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_school uuid;
  v_employee_total integer;
  v_active integer;
  v_present integer;
  v_absent integer;
  v_late integer;
  v_on_leave integer;
  v_open_payroll integer;
  v_approved_payroll integer;
  v_pending_amount numeric;
begin
  select school_id into v_auth_school from public.users where id=auth.uid() and status='active';
  if not app.is_super_admin() and (v_auth_school is null or v_auth_school<>p_school_id) then raise exception 'FORBIDDEN_SCHOOL_SCOPE'; end if;
  if not app.is_super_admin() and not (
    app.has_permission('hr.view',p_school_id)
    or app.has_permission('hr.manage',p_school_id)
    or app.has_permission('payroll.view',p_school_id)
    or app.has_permission('payroll.manage',p_school_id)
    or app.has_role_code('direction',p_school_id)
    or app.has_role_code('founder',p_school_id)
  ) then raise exception 'FORBIDDEN_HR_VIEW'; end if;

  select count(*) into v_employee_total from public.employees where school_id=p_school_id;
  select count(*) into v_active from public.employees where school_id=p_school_id and status='active';
  select count(*) filter(where status='present') , count(*) filter(where status='absent'), count(*) filter(where status='late')
  into v_present,v_absent,v_late
  from public.employee_attendance where school_id=p_school_id and attendance_date=p_date;
  select count(*) into v_on_leave from public.employee_leaves where school_id=p_school_id and status='approved' and p_date between start_date and end_date;
  select count(*) into v_open_payroll from public.payroll_periods where school_id=p_school_id and status in ('draft','open');
  select count(*) into v_approved_payroll from public.payroll_periods where school_id=p_school_id and status='approved';
  select coalesce(sum(pi.net_salary),0) into v_pending_amount
  from public.payroll_items pi join public.payroll_periods pp on pp.id=pi.payroll_period_id
  where pp.school_id=p_school_id and pp.status in ('approved','paid') and pi.payment_status='pending';

  return jsonb_build_object(
    'employees',v_employee_total,
    'active_employees',v_active,
    'present_today',coalesce(v_present,0),
    'absent_today',coalesce(v_absent,0),
    'late_today',coalesce(v_late,0),
    'on_leave_today',v_on_leave,
    'open_payroll_periods',v_open_payroll,
    'approved_payroll_periods',v_approved_payroll,
    'pending_payroll_amount',v_pending_amount
  );
end;
$$;

-- =========================================================
-- 9. DOSSIER EMPLOYÉ
-- =========================================================
create or replace function public.get_employee_dossier(p_employee_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_employee public.employees%rowtype; v_school uuid;
begin
  select * into v_employee from public.employees where id=p_employee_id;
  if v_employee.id is null then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  v_school:=v_employee.school_id;
  if not app.is_super_admin() and not (
    v_employee.user_id=auth.uid()
    or app.has_permission('hr.view',v_school)
    or app.has_permission('hr.manage',v_school)
    or app.has_permission('payroll.view',v_school)
    or app.has_permission('payroll.manage',v_school)
    or app.has_role_code('direction',v_school)
    or app.has_role_code('founder',v_school)
  ) then raise exception 'FORBIDDEN_EMPLOYEE_DOSSIER'; end if;

  return jsonb_build_object(
    'employee',to_jsonb(v_employee),
    'contracts',coalesce((select jsonb_agg(to_jsonb(c) order by c.start_date desc) from public.employee_contracts c where c.employee_id=p_employee_id),'[]'::jsonb),
    'attendance',coalesce((select jsonb_agg(to_jsonb(a) order by a.attendance_date desc) from public.employee_attendance a where a.employee_id=p_employee_id limit 60),'[]'::jsonb),
    'leaves',coalesce((select jsonb_agg(to_jsonb(l) order by l.start_date desc) from public.employee_leaves l where l.employee_id=p_employee_id),'[]'::jsonb),
    'skills',coalesce((select jsonb_agg(to_jsonb(s) order by s.skill_name) from public.employee_skills s where s.employee_id=p_employee_id),'[]'::jsonb),
    'trainings',coalesce((select jsonb_agg(to_jsonb(t) order by t.start_date desc nulls last) from public.employee_trainings t where t.employee_id=p_employee_id),'[]'::jsonb),
    'documents',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from public.documents d where d.employee_id=p_employee_id),'[]'::jsonb)
  );
end;
$$;

-- =========================================================
-- 10. GRANTS / EXECUTE
-- =========================================================
revoke all on function public.create_employee(text,text,text,text,text,text,date,app.gender_type,date,text,text,text,text) from public,anon;
revoke all on function public.set_employee_status(uuid,text) from public,anon;
revoke all on function public.create_employee_contract(uuid,text,date,date,numeric,uuid,text) from public,anon;
revoke all on function public.record_employee_attendance(uuid,date,app.attendance_status,time,time,text) from public,anon;
revoke all on function public.request_employee_leave(uuid,text,date,date,text) from public,anon;
revoke all on function public.decide_employee_leave(uuid,app.approval_status,text) from public,anon;
revoke all on function public.add_employee_skill(uuid,text,text,date,text) from public,anon;
revoke all on function public.add_employee_training(uuid,text,text,date,date,text,text,text) from public,anon;
revoke all on function public.create_payroll_period(text,date,date) from public,anon;
revoke all on function public.open_payroll_period(uuid) from public,anon;
revoke all on function public.generate_payroll(uuid) from public,anon;
revoke all on function public.update_payroll_item(uuid,numeric,numeric,numeric,text) from public,anon;
revoke all on function public.approve_payroll(uuid) from public,anon;
revoke all on function public.mark_payroll_item_paid(uuid) from public,anon;
revoke all on function public.close_payroll(uuid) from public,anon;
revoke all on function public.get_hr_dashboard(uuid,date) from public,anon;
revoke all on function public.get_employee_dossier(uuid) from public,anon;
grant execute on function public.create_employee(text,text,text,text,text,text,date,app.gender_type,date,text,text,text,text) to authenticated;
grant execute on function public.set_employee_status(uuid,text) to authenticated;
grant execute on function public.create_employee_contract(uuid,text,date,date,numeric,uuid,text) to authenticated;
grant execute on function public.record_employee_attendance(uuid,date,app.attendance_status,time,time,text) to authenticated;
grant execute on function public.request_employee_leave(uuid,text,date,date,text) to authenticated;
grant execute on function public.decide_employee_leave(uuid,app.approval_status,text) to authenticated;
grant execute on function public.add_employee_skill(uuid,text,text,date,text) to authenticated;
grant execute on function public.add_employee_training(uuid,text,text,date,date,text,text,text) to authenticated;
grant execute on function public.create_payroll_period(text,date,date) to authenticated;
grant execute on function public.open_payroll_period(uuid) to authenticated;
grant execute on function public.generate_payroll(uuid) to authenticated;
grant execute on function public.update_payroll_item(uuid,numeric,numeric,numeric,text) to authenticated;
grant execute on function public.approve_payroll(uuid) to authenticated;
grant execute on function public.mark_payroll_item_paid(uuid) to authenticated;
grant execute on function public.close_payroll(uuid) to authenticated;
grant execute on function public.get_hr_dashboard(uuid,date) to authenticated;
grant execute on function public.get_employee_dossier(uuid) to authenticated;

commit;
