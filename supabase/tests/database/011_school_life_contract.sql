begin;
select plan(36);

select has_table('public','attendance_sessions','attendance_sessions');
select has_table('public','attendance_records','attendance_records');
select has_table('public','absence_justifications','absence_justifications');
select has_table('public','discipline_categories','discipline_categories');
select has_table('public','discipline_events','discipline_events');
select has_table('public','student_followups','student_followups');
select has_table('public','student_rewards','student_rewards');

select has_column('public','attendance_sessions','updated_at','attendance session updated_at');
select has_column('public','attendance_records','updated_at','attendance record updated_at');
select has_column('public','absence_justifications','updated_at','justification updated_at');
select has_column('public','discipline_categories','is_active','discipline category active');
select has_column('public','discipline_events','updated_at','discipline event updated_at');
select has_column('public','student_followups','status','student followup status');
select has_column('public','student_rewards','category','student reward category');

select has_function('app','employee_belongs_to_school'::name);
select has_function('app','student_enrolled_in_class_on_date'::name);
select has_function('app','can_view_school_life_student'::name);
select has_function('app','validate_attendance_session'::name);
select has_function('app','validate_attendance_record'::name);
select has_function('app','validate_absence_justification'::name);
select has_function('app','validate_discipline_event'::name);
select has_function('app','validate_student_followup'::name);
select has_function('app','validate_student_reward'::name);

select has_function('public','create_attendance_session'::name);
select has_function('public','save_attendance_records'::name);
select has_function('public','review_absence_justification'::name);
select has_function('public','create_discipline_event'::name);
select has_function('public','create_student_followup'::name);
select has_function('public','create_student_reward'::name);
select has_function('public','get_student_school_life_summary'::name);

select policies_are('public','attendance_sessions',ARRAY['attendance_sessions_delete_step14','attendance_sessions_insert_step14','attendance_sessions_select_step14','attendance_sessions_update_step14']);
select policies_are('public','attendance_records',ARRAY['attendance_records_delete_step14','attendance_records_insert_step14','attendance_records_select_step14','attendance_records_update_step14']);
select policies_are('public','absence_justifications',ARRAY['absence_justifications_delete_step14','absence_justifications_insert_step14','absence_justifications_select_step14','absence_justifications_update_step14']);
select policies_are('public','discipline_events',ARRAY['discipline_events_delete_step14','discipline_events_insert_step14','discipline_events_select_step14','discipline_events_update_step14']);
select policies_are('public','student_followups',ARRAY['student_followups_delete_step14','student_followups_insert_step14','student_followups_select_step14','student_followups_update_step14']);
select policies_are('public','student_rewards',ARRAY['student_rewards_delete_step14','student_rewards_insert_step14','student_rewards_select_step14','student_rewards_update_step14']);

select * from finish();
rollback;
