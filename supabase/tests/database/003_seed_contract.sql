select plan(7);
select ok(exists(select 1 from public.schools where code='AL-AMINE' and name='Complexe Scolaire Al Amine'),'official Al Amine school seeded');
select ok(exists(select 1 from public.school_settings ss join public.schools s on s.id=ss.school_id where s.code='AL-AMINE' and ss.default_language='fr' and ss.grading_scale=20),'school settings seeded');
select ok(exists(select 1 from public.school_years sy join public.schools s on s.id=sy.school_id where s.code='AL-AMINE' and sy.name='2026-2027' and sy.is_current),'development academic year seeded');
select is((select count(*)::int from public.academic_periods ap join public.school_years sy on sy.id=ap.school_year_id join public.schools s on s.id=sy.school_id where s.code='AL-AMINE'),3,'three academic periods seeded');
select ok(exists(select 1 from public.document_types dt join public.schools s on s.id=dt.school_id where s.code='AL-AMINE' and dt.code='DOSSIER_INSCRIPTION'),'document type seeded');
select is((select count(*)::int from public.students s join public.schools sc on sc.id=s.school_id where sc.code='AL-AMINE'),0,'no personal student data in official seed');
select is((select count(*)::int from public.parents p join public.schools sc on sc.id=p.school_id where sc.code='AL-AMINE'),0,'no personal parent data in official seed');
select * from finish();
