begin;

-- =========================================================
-- 24. STATISTIQUES / TABLEAUX DE BORD
-- =========================================================

insert into public.permissions(code,name,module,action,description) values
('dashboard.direction','Tableau de bord direction','dashboards','direction','Pilotage global de l’établissement'),
('dashboard.pedagogy','Tableau de bord pédagogie','dashboards','pedagogy','Résultats, évaluations et assiduité'),
('dashboard.finance','Tableau de bord finance','dashboards','finance','Recettes, dépenses, encaissements et soldes'),
('dashboard.boarding','Tableau de bord internat','dashboards','boarding','Effectifs, occupation et mouvements'),
('dashboard.activities','Tableau de bord activités','dashboards','activities','Agriculture, élevage et AGR')
on conflict(code) do nothing;

-- Direction: pilotage global.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r cross join public.permissions p
where r.code in ('super_admin','founder','direction')
  and p.code in ('dashboard.direction','dashboard.pedagogy','dashboard.finance','dashboard.boarding','dashboard.activities')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('dashboard.direction','dashboard.pedagogy')
where r.code='academic_director' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='dashboard.pedagogy'
where r.code='teacher' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='dashboard.finance'
where r.code='accountant' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='dashboard.boarding'
where r.code='boarding_manager' on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='dashboard.activities'
where r.code in ('agriculture_manager','livestock_manager') on conflict do nothing;

create index if not exists ix_report_cards_dashboard_school_year_status
on public.report_cards(school_id,school_year_id,status,class_id);

create index if not exists ix_attendance_sessions_dashboard_school_date
on public.attendance_sessions(school_id,session_date desc,class_id);

create index if not exists ix_attendance_records_dashboard_student_session
on public.attendance_records(student_id,session_id,status);

create index if not exists ix_payments_dashboard_school_date_status
on public.payments(school_id,payment_date desc,status);

create index if not exists ix_expenses_dashboard_school_date_status
on public.expenses(school_id,expense_date desc,approval_status);

create index if not exists ix_boarding_assignments_dashboard_school_status
on public.boarding_assignments(school_id,status,start_date,end_date);

create index if not exists ix_sales_dashboard_school_date
on public.sales(school_id,sale_date desc,activity_id);

create index if not exists ix_economic_activity_expenses_dashboard_school_date
on public.economic_activity_expenses(school_id,expense_date desc,activity_id);

-- =========================================================
-- Lecture sécurisée des dashboards disponibles pour l'utilisateur.
-- =========================================================
create or replace function public.get_available_dashboards(p_school_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  sid uuid;
  dashboards jsonb := '[]'::jsonb;
begin
  select coalesce(p_school_id,(select school_id from public.users where id=auth.uid())) into sid;
  if sid is null or (not app.is_super_admin() and sid not in (select app.my_school_ids())) then
    raise exception 'FORBIDDEN';
  end if;

  if app.is_super_admin() or app.has_permission('dashboard.direction',sid) then dashboards:=dashboards||jsonb_build_array('direction'); end if;
  if app.is_super_admin() or app.has_permission('dashboard.pedagogy',sid) then dashboards:=dashboards||jsonb_build_array('pedagogy'); end if;
  if app.is_super_admin() or app.has_permission('dashboard.finance',sid) then dashboards:=dashboards||jsonb_build_array('finance'); end if;
  if app.is_super_admin() or app.has_permission('dashboard.boarding',sid) then dashboards:=dashboards||jsonb_build_array('boarding'); end if;
  if app.is_super_admin() or app.has_permission('dashboard.activities',sid) then dashboards:=dashboards||jsonb_build_array('activities'); end if;

  return dashboards;
end;
$$;

-- =========================================================
-- Dashboard Direction / Coordination
-- =========================================================
create or replace function public.get_dashboard_direction(p_school_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  sid uuid;
  current_year_id uuid;
  result jsonb;
  finance jsonb;
  activities jsonb;
begin
  select coalesce(p_school_id,(select school_id from public.users where id=auth.uid())) into sid;
  if sid is null or (not app.is_super_admin() and sid not in (select app.my_school_ids())) then raise exception 'FORBIDDEN'; end if;
  if not app.is_super_admin() and not app.has_permission('dashboard.direction',sid) then raise exception 'FORBIDDEN'; end if;

  select id into current_year_id from public.school_years where school_id=sid and is_current=true order by start_date desc limit 1;
  finance := public.get_finance_dashboard(sid);
  select jsonb_build_object(
    'activities',coalesce((select count(*) from public.economic_activities where school_id=sid and status='active'),0),
    'agriculture',coalesce((select count(*) from public.economic_activities where school_id=sid and activity_type='agriculture' and status='active'),0),
    'livestock',coalesce((select count(*) from public.economic_activities where school_id=sid and activity_type='livestock' and status='active'),0),
    'agr',coalesce((select count(*) from public.economic_activities where school_id=sid and activity_type='agr' and status='active'),0),
    'productions',coalesce((select sum(p.quantity) from public.productions p join public.economic_activities ea on ea.id=p.activity_id where ea.school_id=sid),0),
    'livestock_units',coalesce((select sum(l.quantity) from public.livestock l join public.economic_activities ea on ea.id=l.activity_id where ea.school_id=sid and l.status='active'),0),
    'revenue',coalesce((select sum(s.amount) from public.sales s where s.school_id=sid),0),
    'expenses',coalesce((select sum(e.amount) from public.economic_activity_expenses e where e.school_id=sid),0),
    'result',coalesce((select sum(s.amount) from public.sales s where s.school_id=sid),0)-coalesce((select sum(e.amount) from public.economic_activity_expenses e where e.school_id=sid),0)
  ) into activities;

  select jsonb_build_object(
    'school_id',sid,
    'school_year',coalesce((select jsonb_build_object('id',sy.id,'name',sy.name,'start_date',sy.start_date,'end_date',sy.end_date) from public.school_years sy where sy.id=current_year_id),'{}'::jsonb),
    'students',jsonb_build_object(
      'enrolled',coalesce((select count(*) from public.enrollments e where e.school_id=sid and e.school_year_id=current_year_id and e.status='enrolled'),0),
      'active_profiles',coalesce((select count(*) from public.students s where s.school_id=sid and s.status='active'),0),
      'internal',coalesce((select count(*) from public.enrollments e where e.school_id=sid and e.school_year_id=current_year_id and e.status='enrolled' and e.residence_type='internal'),0),
      'external',coalesce((select count(*) from public.enrollments e where e.school_id=sid and e.school_year_id=current_year_id and e.status='enrolled' and e.residence_type='external'),0)
    ),
    'classes',coalesce((select count(*) from public.classes c where c.school_id=sid and c.school_year_id=current_year_id and c.is_active=true),0),
    'employees',coalesce((select count(*) from public.employees e where e.school_id=sid and e.status='active'),0),
    'results',jsonb_build_object(
      'published_report_cards',coalesce((select count(*) from public.report_cards r where r.school_id=sid and r.school_year_id=current_year_id and r.status='published'),0),
      'general_average',coalesce((select round(avg(r.general_average),2) from public.report_cards r where r.school_id=sid and r.school_year_id=current_year_id and r.status='published' and r.general_average is not null),0)
    ),
    'attendance_30d',jsonb_build_object(
      'present',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where a.school_id=sid and a.session_date>=current_date-29 and ar.status='present'),0),
      'absent',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where a.school_id=sid and a.session_date>=current_date-29 and ar.status='absent'),0),
      'late',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where a.school_id=sid and a.session_date>=current_date-29 and ar.status='late'),0),
      'excused',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where a.school_id=sid and a.session_date>=current_date-29 and ar.status='excused'),0)
    ),
    'boarding',jsonb_build_object(
      'active_assignments',coalesce((select count(*) from public.boarding_assignments where school_id=sid and status='active'),0),
      'beds',coalesce((select count(*) from public.boarding_beds b join public.boarding_rooms r on r.id=b.room_id join public.boarding_dormitories d on d.id=r.dormitory_id join public.boarding_buildings bb on bb.id=d.building_id where bb.school_id=sid),0)
    ),
    'finance',finance,
    'activities',activities,
    'top_classes',coalesce((select jsonb_agg(x order by x.active_students desc,x.class_name) from (select class_id,class_name,active_students from public.v_class_effectives where school_id=sid and school_year_id=current_year_id order by active_students desc,class_name limit 10) x),'[]'::jsonb)
  ) into result;
  return result;
end;
$$;

-- =========================================================
-- Dashboard Pédagogie
-- =========================================================
create or replace function public.get_dashboard_pedagogy(p_school_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  sid uuid;
  current_year_id uuid;
  result jsonb;
begin
  select coalesce(p_school_id,(select school_id from public.users where id=auth.uid())) into sid;
  if sid is null or (not app.is_super_admin() and sid not in (select app.my_school_ids())) then raise exception 'FORBIDDEN'; end if;
  if not app.is_super_admin() and not app.has_permission('dashboard.pedagogy',sid) then raise exception 'FORBIDDEN'; end if;
  select id into current_year_id from public.school_years where school_id=sid and is_current=true order by start_date desc limit 1;

  select jsonb_build_object(
    'school_id',sid,
    'school_year',coalesce((select jsonb_build_object('id',sy.id,'name',sy.name) from public.school_years sy where sy.id=current_year_id),'{}'::jsonb),
    'assessments',jsonb_build_object(
      'total',coalesce((select count(*) from public.assessments a where a.school_id=sid and a.school_year_id=current_year_id),0),
      'published',coalesce((select count(*) from public.assessments a where a.school_id=sid and a.school_year_id=current_year_id and a.is_published=true),0),
      'grades',coalesce((select count(*) from public.grades g join public.assessments a on a.id=g.assessment_id where a.school_id=sid and a.school_year_id=current_year_id),0)
    ),
    'report_cards',jsonb_build_object(
      'published',coalesce((select count(*) from public.report_cards r where r.school_id=sid and r.school_year_id=current_year_id and r.status='published'),0),
      'average',coalesce((select round(avg(r.general_average),2) from public.report_cards r where r.school_id=sid and r.school_year_id=current_year_id and r.status='published' and r.general_average is not null),0)
    ),
    'attendance_30d',jsonb_build_object(
      'present',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where a.school_id=sid and a.session_date>=current_date-29 and ar.status='present'),0),
      'absent',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where a.school_id=sid and a.session_date>=current_date-29 and ar.status='absent'),0),
      'late',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where a.school_id=sid and a.session_date>=current_date-29 and ar.status='late'),0)
    ),
    'class_performance',coalesce((select jsonb_agg(x order by x.average desc nulls last,x.class_name) from (
      select r.class_id,c.name class_name,round(avg(r.general_average),2) average,count(*) report_cards
      from public.report_cards r join public.classes c on c.id=r.class_id
      where r.school_id=sid and r.school_year_id=current_year_id and r.status='published' and r.general_average is not null
      group by r.class_id,c.name
      order by average desc nulls last,c.name limit 20
    ) x),'[]'::jsonb),
    'subject_performance',coalesce((select jsonb_agg(x order by x.average desc nulls last,x.subject_name) from (
      select s.id subject_id,s.name subject_name,round(avg(i.average),2) average,count(*) items
      from public.report_card_items i join public.report_cards r on r.id=i.report_card_id join public.subjects s on s.id=i.subject_id
      where r.school_id=sid and r.school_year_id=current_year_id and r.status='published' and i.average is not null
      group by s.id,s.name
      order by average desc nulls last,s.name limit 30
    ) x),'[]'::jsonb)
  ) into result;
  return result;
end;
$$;

-- =========================================================
-- Dashboard Finance
-- =========================================================
create or replace function public.get_dashboard_finance(p_school_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  sid uuid;
  base jsonb;
  result jsonb;
  start_month date;
begin
  select coalesce(p_school_id,(select school_id from public.users where id=auth.uid())) into sid;
  if sid is null or (not app.is_super_admin() and sid not in (select app.my_school_ids())) then raise exception 'FORBIDDEN'; end if;
  if not app.is_super_admin() and not app.has_permission('dashboard.finance',sid) then raise exception 'FORBIDDEN'; end if;
  base:=public.get_finance_dashboard(sid);
  start_month:=date_trunc('month',current_date)::date - interval '5 months';

  select base || jsonb_build_object(
    'monthly',coalesce((select jsonb_agg(x order by x.month_date) from (
      select gs::date month_date,
        coalesce((select sum(p.amount) from public.payments p where p.school_id=sid and p.status='paid' and p.payment_date>=gs and p.payment_date<gs+interval '1 month'),0) payments,
        coalesce((select sum(e.amount) from public.expenses e where e.school_id=sid and e.approval_status='approved' and e.expense_date>=gs::date and e.expense_date<(gs+interval '1 month')::date),0) expenses
      from generate_series(date_trunc('month',start_month),date_trunc('month',current_date),interval '1 month') gs
    ) x),'[]'::jsonb),
    'expense_categories',coalesce((select jsonb_agg(x order by x.amount desc,x.name) from (
      select coalesce(ec.name,'Sans catégorie') name,round(sum(e.amount),2) amount
      from public.expenses e left join public.expense_categories ec on ec.id=e.category_id
      where e.school_id=sid and e.approval_status='approved' and e.expense_date>=current_date-365
      group by ec.name
    ) x),'[]'::jsonb),
    'receipts_12m',coalesce((select count(*) from public.receipts where school_id=sid and issued_at>=current_date-365),0)
  ) into result;
  return result;
end;
$$;

-- =========================================================
-- Dashboard Internat
-- =========================================================
create or replace function public.get_dashboard_boarding(p_school_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  sid uuid;
  result jsonb;
  total_beds integer;
  active_assignments integer;
begin
  select coalesce(p_school_id,(select school_id from public.users where id=auth.uid())) into sid;
  if sid is null or (not app.is_super_admin() and sid not in (select app.my_school_ids())) then raise exception 'FORBIDDEN'; end if;
  if not app.is_super_admin() and not app.has_permission('dashboard.boarding',sid) then raise exception 'FORBIDDEN'; end if;

  select count(*) into total_beds
  from public.boarding_beds b
  join public.boarding_rooms r on r.id=b.room_id
  join public.boarding_dormitories d on d.id=r.dormitory_id
  join public.boarding_buildings bb on bb.id=d.building_id
  where bb.school_id=sid;

  select count(*) into active_assignments from public.boarding_assignments where school_id=sid and status='active';

  select jsonb_build_object(
    'school_id',sid,
    'active_boarders',active_assignments,
    'total_beds',total_beds,
    'occupied_beds',least(active_assignments,total_beds),
    'available_beds',greatest(total_beds-active_assignments,0),
    'occupancy_rate',case when total_beds>0 then round((least(active_assignments,total_beds)::numeric/total_beds::numeric)*100,2) else 0 end,
    'attendance_7d',coalesce((select jsonb_agg(x order by x.status) from (
      select ba.status,count(*) count from public.boarding_attendance ba where ba.school_id=sid and ba.attendance_date>=current_date-6 group by ba.status
    ) x),'[]'::jsonb),
    'movements_30d',coalesce((select jsonb_agg(x order by x.movement_type) from (
      select bm.movement_type,count(*) count from public.boarding_movements bm where bm.school_id=sid and bm.movement_at>=now()-interval '30 days' group by bm.movement_type
    ) x),'[]'::jsonb),
    'dormitories',coalesce((select jsonb_agg(x order by x.building_name,x.dormitory_name) from (
      select bb.name building_name,d.name dormitory_name,count(b.id) beds,count(ba.id) occupied
      from public.boarding_buildings bb
      join public.boarding_dormitories d on d.building_id=bb.id
      left join public.boarding_rooms r on r.dormitory_id=d.id
      left join public.boarding_beds b on b.room_id=r.id
      left join public.boarding_assignments ba on ba.bed_id=b.id and ba.school_id=sid and ba.status='active'
      where bb.school_id=sid
      group by bb.name,d.name
    ) x),'[]'::jsonb)
  ) into result;
  return result;
end;
$$;

-- =========================================================
-- Dashboard Activités économiques
-- =========================================================
create or replace function public.get_dashboard_activities(p_school_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  sid uuid;
  result jsonb;
begin
  select coalesce(p_school_id,(select school_id from public.users where id=auth.uid())) into sid;
  if sid is null or (not app.is_super_admin() and sid not in (select app.my_school_ids())) then raise exception 'FORBIDDEN'; end if;
  if not app.is_super_admin() and not app.has_permission('dashboard.activities',sid) then raise exception 'FORBIDDEN'; end if;

  select jsonb_build_object(
    'activities',coalesce((select count(*) from public.economic_activities where school_id=sid and status='active'),0),
    'agriculture',coalesce((select count(*) from public.economic_activities where school_id=sid and activity_type='agriculture' and status='active'),0),
    'livestock',coalesce((select count(*) from public.economic_activities where school_id=sid and activity_type='livestock' and status='active'),0),
    'agr',coalesce((select count(*) from public.economic_activities where school_id=sid and activity_type='agr' and status='active'),0),
    'campaigns',coalesce((select count(*) from public.agriculture_campaigns ac join public.economic_activities ea on ea.id=ac.activity_id where ea.school_id=sid),0),
    'livestock_units',coalesce((select sum(l.quantity) from public.livestock l join public.economic_activities ea on ea.id=l.activity_id where ea.school_id=sid and l.status='active'),0),
    'productions',coalesce((select sum(p.quantity) from public.productions p join public.economic_activities ea on ea.id=p.activity_id where ea.school_id=sid),0),
    'revenue',coalesce((select sum(s.amount) from public.sales s where s.school_id=sid),0),
    'expenses',coalesce((select sum(e.amount) from public.economic_activity_expenses e where e.school_id=sid),0),
    'result',coalesce((select sum(s.amount) from public.sales s where s.school_id=sid),0)-coalesce((select sum(e.amount) from public.economic_activity_expenses e where e.school_id=sid),0),
    'by_type',coalesce((select jsonb_agg(x order by x.activity_type) from (
      select ea.activity_type,
        count(*) filter(where ea.status='active') activities,
        round(coalesce((select sum(s.amount) from public.sales s where s.school_id=sid and s.activity_id in (select id from public.economic_activities where activity_type=ea.activity_type and school_id=sid)),0),2) revenue,
        round(coalesce((select sum(e.amount) from public.economic_activity_expenses e where e.school_id=sid and e.activity_id in (select id from public.economic_activities where activity_type=ea.activity_type and school_id=sid)),0),2) expenses
      from public.economic_activities ea
      where ea.school_id=sid
      group by ea.activity_type
    ) x),'[]'::jsonb),
    'recent_sales',coalesce((select jsonb_agg(x order by x.sale_date desc) from (
      select s.sale_date,s.sale_number,s.amount,ea.name activity_name,ea.activity_type
      from public.sales s left join public.economic_activities ea on ea.id=s.activity_id
      where s.school_id=sid order by s.sale_date desc,s.created_at desc limit 15
    ) x),'[]'::jsonb)
  ) into result;
  return result;
end;
$$;

-- =========================================================
-- Exécution : uniquement authentifié.
-- =========================================================
revoke all on function public.get_available_dashboards(uuid) from public,anon;
grant execute on function public.get_available_dashboards(uuid) to authenticated;
revoke all on function public.get_dashboard_direction(uuid) from public,anon;
grant execute on function public.get_dashboard_direction(uuid) to authenticated;
revoke all on function public.get_dashboard_pedagogy(uuid) from public,anon;
grant execute on function public.get_dashboard_pedagogy(uuid) to authenticated;
revoke all on function public.get_dashboard_finance(uuid) from public,anon;
grant execute on function public.get_dashboard_finance(uuid) to authenticated;
revoke all on function public.get_dashboard_boarding(uuid) from public,anon;
grant execute on function public.get_dashboard_boarding(uuid) to authenticated;
revoke all on function public.get_dashboard_activities(uuid) from public,anon;
grant execute on function public.get_dashboard_activities(uuid) to authenticated;

comment on function public.get_dashboard_direction(uuid) is 'Tableau de bord global Direction/Coordination selon les permissions dashboard.direction.';
comment on function public.get_dashboard_pedagogy(uuid) is 'Tableau de bord pédagogique : évaluations, notes, bulletins, résultats et assiduité.';
comment on function public.get_dashboard_finance(uuid) is 'Tableau de bord financier : encaissements, dépenses, impayés et séries mensuelles.';
comment on function public.get_dashboard_boarding(uuid) is 'Tableau de bord internat : occupation, présences et mouvements.';
comment on function public.get_dashboard_activities(uuid) is 'Tableau de bord agriculture/élevage/AGR : activités, ventes et dépenses.';

commit;
