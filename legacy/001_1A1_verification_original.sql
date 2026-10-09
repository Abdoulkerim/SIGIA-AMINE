-- SIGIA-AMINE | Vérification post-1A.1
-- À exécuter après 001_1A1_hardening.sql dans Supabase SQL Editor.

-- 1. RLS actif sur toutes les tables public exposées
select count(*) as tables_public, count(*) filter(where c.relrowsecurity) as tables_rls
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r';

-- 2. Policies présentes
select tablename, count(*) as policy_count
from pg_policies where schemaname='public'
group by tablename order by tablename;

-- 3. Contraintes et index critiques
select indexname,indexdef from pg_indexes
where schemaname='public' and indexname in (
 'uq_enrollment_active_student_year','uq_active_boarding_student','uq_active_boarding_bed',
 'uq_active_employee_contract','uq_student_primary_parent','uq_students_user_id','uq_parents_user_id'
) order by indexname;

-- 4. Triggers de sécurité/métier
select event_object_table,trigger_name,event_manipulation
from information_schema.triggers
where trigger_schema='public'
  and trigger_name in (
    'trg_school_integrity','trg_relation_school_integrity','trg_identity_school',
    'trg_validate_enrollment','trg_validate_grade_hardened','trg_validate_assessment_publication',
    'trg_validate_report_card_lock','trg_validate_payment_allocation','trg_invoice_total_hardened',
    'trg_validate_cash_transaction','trg_apply_stock_movement','trg_validate_boarding_assignment',
    'trg_prevent_overlapping_leave','trg_audit_immutable_update','trg_audit_immutable_delete','trg_audit_grade_change'
  ) order by event_object_table,trigger_name;

-- 5. Fonctions SECURITY DEFINER importantes
select n.nspname as schema_name,p.proname,
       pg_get_function_identity_arguments(p.oid) as args
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='app' and p.prosecdef=true
order by p.proname;

-- 6. Storage buckets privés
select id,name,public from storage.buckets order by id;

-- 7. Détecter les relations multi-écoles existantes avant mise en production
select e.id as enrollment_id from public.enrollments e
join public.students s on s.id=e.student_id
join public.school_years y on y.id=e.school_year_id
join public.classes c on c.id=e.class_id
where e.school_id<>s.school_id or e.school_id<>y.school_id or e.school_id<>c.school_id;

select ta.id as teacher_assignment_id from public.teacher_assignments ta
join public.employees e on e.id=ta.teacher_id
join public.classes c on c.id=ta.class_id
join public.subjects s on s.id=ta.subject_id
where ta.school_id<>e.school_id or ta.school_id<>c.school_id or ta.school_id<>s.school_id;

-- 8. Doublons métier à nettoyer avant prod
select student_id,school_year_id,count(*)
from public.enrollments
where status in ('pending','approved','enrolled')
group by student_id,school_year_id having count(*)>1;

select student_id,count(*)
from public.boarding_assignments
where status='active' and end_date is null
group by student_id having count(*)>1;

select bed_id,count(*)
from public.boarding_assignments
where status='active' and end_date is null
group by bed_id having count(*)>1;

select employee_id,count(*)
from public.employee_contracts
where status='active'
group by employee_id having count(*)>1;

-- 9. Contrôle factures / allocations
select pa.id
from public.payment_allocations pa
left join public.payments p on p.id=pa.payment_id
where p.id is null;

select i.id
from public.invoice_items i
where i.discount>i.quantity*i.unit_amount;

-- 10. Contrôle stock
select sb.product_id,sb.location_id,sb.quantity
from public.stock_balances sb
where sb.quantity<0;
