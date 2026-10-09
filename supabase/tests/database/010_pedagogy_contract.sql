begin;
select plan(24);

select has_table('public','timetable_slots','timetable_slots');
select has_table('public','assessment_types','assessment_types');
select has_table('public','assessments','assessments');
select has_table('public','grades','grades');
select has_table('public','grade_audit','grade_audit');
select has_table('public','report_cards','report_cards');
select has_table('public','report_card_items','report_card_items');

select has_column('public','assessment_types','is_active','assessment type active column');
select has_column('public','assessment_types','updated_at','assessment type updated column');
select has_column('public','report_cards','status','report card status column');

select has_function('public','create_timetable_slot'::name);
select has_function('public','update_timetable_slot'::name);
select has_function('public','set_timetable_slot_active'::name);
select has_function('public','create_assessment_type'::name);
select has_function('public','create_assessment'::name);
select has_function('public','set_assessment_published'::name);
select has_function('public','save_assessment_grades'::name);
select has_function('public','generate_report_card_draft'::name);
select has_function('public','publish_report_card'::name);

select has_function('app','is_teacher_for_assessment'::name);
select has_function('app','is_teacher_for_timetable_slot'::name);
select has_function('app','can_manage_assessment_for_class_subject'::name);

select policies_are('public','grades',ARRAY['grades_delete_021','grades_insert_021','grades_select_021','grades_update_021']);
select policies_are('public','report_cards',ARRAY['report_cards_delete_021','report_cards_insert_021','report_cards_select_021','report_cards_update_021']);

select * from finish();
rollback;
