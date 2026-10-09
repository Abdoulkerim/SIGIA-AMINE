-- =========================================================
-- SIGIA-AMINE — SEED OFFICIEL INITIAL AL AMINE
-- Étape 2 — données institutionnelles uniquement
--
-- IMPORTANT :
-- - Aucune donnée personnelle réelle d'élève, parent ou personnel.
-- - Les rôles/permissions sont déjà semés par la migration 013.
-- - Les niveaux/classes/matières ne sont pas inventés ici : le cahier
--   des charges les prévoit, mais ne fournit pas la liste réelle.
-- - L'année 2026-2027 ci-dessous est un paramètre de déploiement initial
--   à confirmer par la Direction avant la production.
-- =========================================================

begin;

insert into public.schools (
  code, name, short_name, country, timezone, currency_code, is_active
)
values (
  'AL-AMINE',
  'Complexe Scolaire Al Amine',
  'Al Amine',
  'Burkina Faso',
  'Africa/Ouagadougou',
  'XOF',
  true
)
on conflict (code) do update
set
  name = excluded.name,
  short_name = excluded.short_name,
  country = excluded.country,
  timezone = excluded.timezone,
  currency_code = excluded.currency_code,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.school_settings (
  school_id, default_language, grading_scale, passing_score,
  late_tolerance_minutes, receipt_prefix, invoice_prefix,
  student_prefix, settings
)
select
  s.id,
  'fr',
  20,
  10,
  15,
  'REC',
  'FAC',
  'ELV',
  jsonb_build_object(
    'product_name', 'SIGIA-AMINE',
    'institution_motto', 'Former pour bâtir l’avenir.',
    'deployment_stage', 'local-development',
    'academic_year_confirmation_required', true,
    'official_data_policy', 'Aucune donnée personnelle réelle ne doit être placée dans le seed local.'
  )
from public.schools s
where s.code = 'AL-AMINE'
on conflict (school_id) do update
set
  default_language = excluded.default_language,
  grading_scale = excluded.grading_scale,
  passing_score = excluded.passing_score,
  late_tolerance_minutes = excluded.late_tolerance_minutes,
  receipt_prefix = excluded.receipt_prefix,
  invoice_prefix = excluded.invoice_prefix,
  student_prefix = excluded.student_prefix,
  settings = excluded.settings,
  updated_at = now();

insert into public.school_years (
  school_id, name, start_date, end_date, is_current
)
select
  id,
  '2026-2027',
  date '2026-09-01',
  date '2027-07-31',
  true
from public.schools
where code = 'AL-AMINE'
on conflict (school_id, name) do update
set
  start_date = excluded.start_date,
  end_date = excluded.end_date,
  is_current = excluded.is_current,
  updated_at = now();

insert into public.academic_periods (
  school_year_id, name, code, start_date, end_date, sequence_no, is_closed
)
select
  sy.id,
  p.name,
  p.code,
  sy.start_date,
  sy.end_date,
  p.sequence_no,
  false
from public.school_years sy
cross join (
  values
    ('Trimestre 1', 'T1', 1),
    ('Trimestre 2', 'T2', 2),
    ('Trimestre 3', 'T3', 3)
) as p(name, code, sequence_no)
join public.schools s on s.id = sy.school_id
where s.code = 'AL-AMINE'
on conflict (school_year_id, code) do update
set
  name = excluded.name,
  start_date = excluded.start_date,
  end_date = excluded.end_date,
  sequence_no = excluded.sequence_no,
  is_closed = false;

insert into public.document_types (school_id, code, name, module, is_active)
select s.id, d.code, d.name, 'administration', true
from public.schools s
cross join (
  values
    ('DOSSIER_INSCRIPTION', 'Dossier d’inscription'),
    ('FICHE_INSCRIPTION', 'Fiche d’inscription'),
    ('CERTIFICAT_SCOLARITE', 'Certificat de scolarité'),
    ('ATTESTATION', 'Attestation'),
    ('BULLETIN', 'Bulletin scolaire')
) as d(code, name)
where s.code = 'AL-AMINE'
on conflict (school_id, code) do update
set
  name = excluded.name,
  module = excluded.module,
  is_active = excluded.is_active;

commit;
