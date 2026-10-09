begin;

select plan(21);

select has_table('public','ai_conversations','ai_conversations exists');
select has_table('public','ai_messages','ai_messages exists');
select has_table('public','ai_alerts','ai_alerts exists');
select has_table('public','ai_prompt_templates','ai_prompt_templates exists');
select has_table('public','ai_runs','ai_runs exists');
select has_table('public','ai_tool_calls','ai_tool_calls exists');

select has_column('public','ai_conversations','mode','conversation mode exists');
select has_column('public','ai_conversations','updated_at','conversation updated_at exists');
select has_column('public','ai_alerts','source_run_id','alert source_run_id exists');
select has_column('public','ai_alerts','evidence','alert evidence exists');

select has_function('public','ai_tool_student_summary',array['uuid'],'student summary tool exists');
select has_function('public','ai_tool_search_students',array['text','integer'],'student search tool exists');

select ok((select relrowsecurity from pg_class where oid='public.ai_conversations'::regclass),'ai conversations RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.ai_messages'::regclass),'ai messages RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.ai_alerts'::regclass),'ai alerts RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.ai_prompt_templates'::regclass),'ai prompt templates RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.ai_runs'::regclass),'ai runs RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.ai_tool_calls'::regclass),'ai tool calls RLS enabled');

select has_index('public','ai_runs','idx_ai_runs_school_created','ai runs school index exists');
select has_index('public','ai_tool_calls','idx_ai_tool_calls_run_created','tool calls index exists');

select pass('AI step 25 contract completed');

select * from finish();
rollback;
