-- SIGIA-AMINE — Contrat Étape 21 Wushu
-- À exécuter via: npx supabase test db --local

begin;
select plan(16);

select has_table('public','wushu_groups','wushu_groups existe');
select has_table('public','student_wushu','student_wushu existe');
select has_table('public','wushu_sessions','wushu_sessions existe');
select has_table('public','wushu_attendance','wushu_attendance existe');
select has_table('public','wushu_evaluations','wushu_evaluations existe');
select has_table('public','wushu_competitions','wushu_competitions existe');
select has_table('public','wushu_competition_results','wushu_competition_results existe');
select has_table('public','wushu_progress_history','wushu_progress_history existe');

select has_function('public','create_wushu_group','create_wushu_group existe');
select has_function('public','assign_student_wushu','assign_student_wushu existe');
select has_function('public','create_wushu_session','create_wushu_session existe');
select has_function('public','record_wushu_attendance','record_wushu_attendance existe');
select has_function('public','create_wushu_evaluation','create_wushu_evaluation existe');
select has_function('public','create_wushu_competition','create_wushu_competition existe');
select has_function('public','record_wushu_competition_result','record_wushu_competition_result existe');
select has_function('public','get_student_wushu','get_student_wushu existe');

select * from finish();
rollback;
