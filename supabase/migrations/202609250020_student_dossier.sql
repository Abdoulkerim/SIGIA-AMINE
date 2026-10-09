-- SIGIA-AMINE
-- Migration 020: complete student dossier
-- Étape 12 — Dossier élève complet
--
-- Principe :
-- Aucun nouveau "student_profile" dupliqué.
-- Le dossier complet est une agrégation contrôlée des données existantes.
-- La fonction est SECURITY INVOKER : les RLS des tables sources restent applicables.
--
begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- A. INDEXES POUR LE DOSSIER ÉLÈVE
-- =========================================================
create index if not exists idx_student_parents_parent_student
  on public.student_parents(parent_id, student_id);

create index if not exists idx_authorized_pickup_student_active
  on public.authorized_pickup_persons(student_id, is_active);

create index if not exists idx_admission_student_year
  on public.admission_applications(student_id, desired_year_id)
  where student_id is not null;

create index if not exists idx_enrollment_history_student_changed
  on public.enrollment_history(student_id, changed_at desc);

create index if not exists idx_teacher_assignments_teacher_class_year
  on public.teacher_assignments(teacher_id, class_id, school_year_id);

-- =========================================================
-- B. RPC DE LECTURE — DOSSIER ÉLÈVE
-- =========================================================
create or replace function public.get_student_dossier(p_student_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public, app
as $$
with visible_student as (
  select
    s.id,
    s.school_id,
    s.student_number,
    s.first_name,
    s.last_name,
    s.gender,
    s.date_of_birth,
    s.place_of_birth,
    s.nationality,
    s.address,
    s.phone,
    s.email,
    s.photo_url,
    s.residence_type,
    s.status,
    s.emergency_contact,
    s.medical_notes,
    s.created_at,
    s.updated_at
  from public.students s
  where s.id = p_student_id
  limit 1
),
current_enrollment as (
  select jsonb_build_object(
    'id', e.id,
    'registration_number', e.registration_number,
    'school_year_id', e.school_year_id,
    'school_year_name', sy.name,
    'class_id', e.class_id,
    'class_name', c.name,
    'class_code', c.code,
    'level_id', c.level_id,
    'level_name', l.name,
    'level_code', l.code,
    'residence_type', e.residence_type,
    'enrollment_date', e.enrollment_date,
    'status', e.status,
    'is_reenrollment', e.is_reenrollment,
    'registration_fee', e.registration_fee,
    'notes', e.notes
  ) as current_enrollment
  from public.enrollments e
  join public.school_years sy on sy.id = e.school_year_id
  left join public.classes c on c.id = e.class_id
  left join public.levels l on l.id = c.level_id
  where e.student_id = p_student_id
    and e.status in ('approved','enrolled')
  order by
    case when e.status = 'enrolled' then 0 else 1 end,
    e.enrollment_date desc
  limit 1
),
parents as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'first_name', p.first_name,
        'last_name', p.last_name,
        'gender', p.gender,
        'profession', p.profession,
        'phone', p.phone,
        'email', p.email,
        'address', p.address,
        'relationship', sp.relationship,
        'is_primary', sp.is_primary,
        'has_financial_responsibility', sp.has_financial_responsibility,
        'receives_notifications', sp.receives_notifications
      )
      order by sp.is_primary desc, p.last_name, p.first_name
    ),
    '[]'::jsonb
  ) as parents
  from public.student_parents sp
  join public.parents p on p.id = sp.parent_id
  where sp.student_id = p_student_id
),
enrollments as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', e.id,
        'registration_number', e.registration_number,
        'school_year_id', e.school_year_id,
        'school_year_name', sy.name,
        'class_id', e.class_id,
        'class_name', c.name,
        'class_code', c.code,
        'level_id', c.level_id,
        'level_name', l.name,
        'residence_type', e.residence_type,
        'enrollment_date', e.enrollment_date,
        'status', e.status,
        'is_reenrollment', e.is_reenrollment,
        'registration_fee', e.registration_fee
      )
      order by sy.start_date desc, e.enrollment_date desc
    ),
    '[]'::jsonb
  ) as enrollments
  from public.enrollments e
  join public.school_years sy on sy.id = e.school_year_id
  left join public.classes c on c.id = e.class_id
  left join public.levels l on l.id = c.level_id
  where e.student_id = p_student_id
),
enrollment_history as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', eh.id,
        'old_class_name', oldc.name,
        'new_class_name', newc.name,
        'old_residence_type', eh.old_residence_type,
        'new_residence_type', eh.new_residence_type,
        'reason', eh.reason,
        'changed_at', eh.changed_at
      )
      order by eh.changed_at desc
    ),
    '[]'::jsonb
  ) as enrollment_history
  from public.enrollment_history eh
  left join public.classes oldc on oldc.id = eh.old_class_id
  left join public.classes newc on newc.id = eh.new_class_id
  where eh.student_id = p_student_id
),
admissions as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', aa.id,
        'application_number', aa.application_number,
        'applicant_name', aa.applicant_name,
        'status', aa.status,
        'desired_level_label', aa.desired_level_label,
        'desired_level_name', dl.name,
        'desired_year_name', dy.name,
        'desired_residence_type', aa.desired_residence_type,
        'submitted_at', aa.submitted_at,
        'reviewed_at', aa.reviewed_at,
        'notes', aa.notes
      )
      order by aa.created_at desc
    ),
    '[]'::jsonb
  ) as admissions
  from public.admission_applications aa
  left join public.levels dl on dl.id = aa.desired_level_id
  left join public.school_years dy on dy.id = aa.desired_year_id
  where aa.student_id = p_student_id
),
teachers as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'teacher_id', ta.teacher_id,
        'teacher_employee_number', emp.employee_number,
        'teacher_first_name', emp.first_name,
        'teacher_last_name', emp.last_name,
        'teacher_speciality', tp.speciality,
        'subject_id', sub.id,
        'subject_code', sub.code,
        'subject_name', sub.name,
        'class_id', c.id,
        'class_code', c.code,
        'class_name', c.name,
        'school_year_id', ta.school_year_id,
        'school_year_name', sy.name,
        'weekly_hours', ta.weekly_hours,
        'is_primary', ta.is_primary
      )
      order by sy.start_date desc, c.name, sub.name, emp.last_name, emp.first_name
    ),
    '[]'::jsonb
  ) as teachers
  from public.teacher_assignments ta
  join public.employees emp on emp.id = ta.teacher_id
  left join public.teacher_profiles tp on tp.employee_id = emp.id
  join public.subjects sub on sub.id = ta.subject_id
  join public.classes c on c.id = ta.class_id
  join public.school_years sy on sy.id = ta.school_year_id
  join public.enrollments en
    on en.class_id = ta.class_id
   and en.school_year_id = ta.school_year_id
   and en.student_id = p_student_id
  where en.status = 'enrolled'
),
pickup_persons as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ap.id,
        'full_name', ap.full_name,
        'relationship', ap.relationship,
        'phone', ap.phone,
        'identity_document', ap.identity_document,
        'is_active', ap.is_active
      )
      order by ap.is_active desc, ap.full_name
    ),
    '[]'::jsonb
  ) as pickup_persons
  from public.authorized_pickup_persons ap
  where ap.student_id = p_student_id
),
documents as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'document_type_id', d.document_type_id,
        'reference', d.reference,
        'title', d.title,
        'status', d.status,
        'file_path', d.file_path,
        'issue_date', d.issued_at,
        'created_at', d.created_at
      )
      order by d.created_at desc
    ),
    '[]'::jsonb
  ) as documents
  from public.documents d
  where d.student_id = p_student_id
)
select
  case
    when vs.id is null then null
    else jsonb_build_object(
      'student', to_jsonb(vs),
      'current_enrollment', coalesce(ce.current_enrollment, '{}'::jsonb),
      'parents', p.parents,
      'enrollments', e.enrollments,
      'enrollment_history', eh.enrollment_history,
      'admissions', a.admissions,
      'teachers', t.teachers,
      'authorized_pickup_persons', pp.pickup_persons,
      'documents', d.documents,
      'modules', jsonb_build_object(
        'pedagogy', 'ÉTAPE 13',
        'school_life', 'ÉTAPE 14',
        'finance', 'ÉTAPE 15',
        'boarding', 'ÉTAPE 16',
        'catering', 'ÉTAPE 17',
        'hr', 'ÉTAPE 18',
        'stock', 'ÉTAPE 19',
        'formation', 'ÉTAPE 20-21',
        'economic_activities', 'ÉTAPE 22',
        'communication_documents', 'ÉTAPE 23',
        'statistics', 'ÉTAPE 24',
        'ai', 'ÉTAPE 25'
      )
    )
  end
from visible_student vs
left join current_enrollment ce on true
cross join parents p
cross join enrollments e
cross join enrollment_history eh
cross join admissions a
cross join teachers t
cross join pickup_persons pp
cross join documents d;
$$;

revoke all on function public.get_student_dossier(uuid) from public;
grant execute on function public.get_student_dossier(uuid) to authenticated;

comment on function public.get_student_dossier(uuid)
is 'Agrégation sécurisée du dossier élève existant. Fonction SECURITY INVOKER : les RLS des tables sources restent applicables. Aucun stockage dupliqué.';

commit;
