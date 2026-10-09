begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- =========================================================
-- ÉTAPE 25 — INTELLIGENCE ARTIFICIELLE
-- Couche d'assistance lecture seule + analyses + alertes à validation humaine.
-- L'IA ne modifie jamais directement les données métier.
-- =========================================================

insert into public.permissions(code,name,module,action,description) values
('ai.manage','Administrer IA','ai','manage','Prompts, exécutions et gouvernance IA'),
('ai.alerts.review','Valider alertes IA','ai','alerts_review','Revue et validation humaine des alertes IA')
on conflict(code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code in ('super_admin','founder','direction')
  and p.code in ('ai.manage','ai.alerts.review')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('ai.use','ai.alerts.review')
where r.code='academic_director'
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='ai.use'
where r.code in ('admin','teacher','accountant','boarding_manager','agriculture_manager','livestock_manager','parent','student')
on conflict do nothing;

alter table public.ai_conversations
  add column if not exists status text not null default 'active' check(status in ('active','archived')),
  add column if not exists mode text not null default 'assistant',
  add column if not exists model text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists last_message_at timestamptz;

alter table public.ai_alerts
  add column if not exists source_run_id uuid,
  add column if not exists evidence jsonb not null default '{}'::jsonb,
  add column if not exists recommended_action text,
  add column if not exists review_note text;

create table if not exists public.ai_prompt_templates(
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  system_prompt text not null,
  capabilities jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,code)
);

create unique index if not exists uq_ai_prompt_templates_global_code
  on public.ai_prompt_templates(lower(code)) where school_id is null;

create table if not exists public.ai_runs(
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  conversation_id uuid references public.ai_conversations(id) on delete set null,
  mode text not null default 'assistant',
  provider text not null default 'openai',
  model text not null,
  status text not null default 'running' check(status in ('running','completed','failed','cancelled')),
  input_tokens integer check(input_tokens is null or input_tokens >= 0),
  output_tokens integer check(output_tokens is null or output_tokens >= 0),
  latency_ms integer check(latency_ms is null or latency_ms >= 0),
  error_code text,
  error_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_tool_calls(
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.ai_runs(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  tool_name text not null,
  arguments jsonb not null default '{}'::jsonb,
  result jsonb,
  status text not null default 'completed' check(status in ('completed','failed','denied')),
  error_message text,
  duration_ms integer check(duration_ms is null or duration_ms >= 0),
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_conversations_user_updated on public.ai_conversations(user_id,updated_at desc);
create index if not exists idx_ai_runs_school_created on public.ai_runs(school_id,created_at desc);
create index if not exists idx_ai_runs_user_created on public.ai_runs(user_id,created_at desc);
create index if not exists idx_ai_tool_calls_run_created on public.ai_tool_calls(run_id,created_at);
create index if not exists idx_ai_alerts_school_status on public.ai_alerts(school_id,status,generated_at desc);
create index if not exists idx_ai_prompt_templates_school_active on public.ai_prompt_templates(school_id,is_active,code);

create or replace function app.ai_touch_conversation()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  update public.ai_conversations
  set updated_at=now(), last_message_at=now()
  where id=new.conversation_id;
  return new;
end;
$$;

drop trigger if exists trg_ai_messages_touch_conversation on public.ai_messages;
create trigger trg_ai_messages_touch_conversation
after insert on public.ai_messages
for each row execute function app.ai_touch_conversation();

create or replace function public.ai_tool_student_summary(p_student_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  sid uuid;
  can_staff boolean := false;
  can_finance boolean := false;
  can_discipline boolean := false;
  can_specialized boolean := false;
  out_json jsonb;
begin
  select s.school_id into sid from public.students s where s.id=p_student_id;
  if sid is null or sid not in (select app.my_school_ids()) then raise exception 'FORBIDDEN'; end if;

  if app.is_super_admin() or app.has_permission('students.view',sid) or app.has_permission('students.manage',sid)
     or app.is_self_student(p_student_id) or app.is_parent_of_student(p_student_id) or app.is_teacher_for_student(p_student_id) then
    can_staff := true;
  end if;
  if not can_staff then raise exception 'FORBIDDEN'; end if;

  can_finance := app.is_self_student(p_student_id) or app.is_parent_of_student(p_student_id)
    or app.has_permission('finance.view',sid) or app.has_permission('finance.manage',sid) or app.is_super_admin();
  can_discipline := app.is_self_student(p_student_id) or app.has_permission('discipline.manage',sid)
    or app.has_role_code('direction',sid) or app.has_role_code('founder',sid) or app.is_super_admin();
  can_specialized := app.is_self_student(p_student_id) or app.is_parent_of_student(p_student_id)
    or app.has_permission('tahfiz.manage',sid) or app.has_permission('arabic.manage',sid)
    or app.has_permission('wushu.manage',sid) or app.is_super_admin();

  select jsonb_build_object(
    'student', jsonb_build_object(
      'id',s.id,'student_number',s.student_number,'first_name',s.first_name,'last_name',s.last_name,
      'gender',s.gender,'status',s.status
    ),
    'enrollment', coalesce((select jsonb_build_object(
      'school_year',sy.name,'class',c.name,'residence_type',e.residence_type,'status',e.status
    ) from public.enrollments e
      join public.school_years sy on sy.id=e.school_year_id
      join public.classes c on c.id=e.class_id
      where e.student_id=s.id and e.status='enrolled'
      order by sy.is_current desc,sy.start_date desc limit 1),'{}'::jsonb),
    'results', jsonb_build_object(
      'published_report_cards',coalesce((select count(*) from public.report_cards r where r.student_id=s.id and r.status='published'),0),
      'latest_average',coalesce((select r.general_average from public.report_cards r where r.student_id=s.id and r.status='published' order by r.generated_at desc nulls last,r.created_at desc limit 1),0)
    ),
    'attendance_30d', jsonb_build_object(
      'present',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where ar.student_id=s.id and a.session_date>=current_date-29 and ar.status='present'),0),
      'absent',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where ar.student_id=s.id and a.session_date>=current_date-29 and ar.status='absent'),0),
      'late',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where ar.student_id=s.id and a.session_date>=current_date-29 and ar.status='late'),0),
      'excused',coalesce((select count(*) from public.attendance_records ar join public.attendance_sessions a on a.id=ar.session_id where ar.student_id=s.id and a.session_date>=current_date-29 and ar.status='excused'),0)
    ),
    'finance',case when can_finance then jsonb_build_object('balance',app.student_balance(s.id)) else '{}'::jsonb end,
    'discipline',case when can_discipline then jsonb_build_object(
      'events_90d',coalesce((select count(*) from public.discipline_events d where d.student_id=s.id and d.event_date>=current_date-89),0),
      'followups_90d',coalesce((select count(*) from public.student_followups f where f.student_id=s.id and f.followup_date>=current_date-89),0),
      'rewards_90d',coalesce((select count(*) from public.student_rewards r where r.student_id=s.id and r.reward_date>=current_date-89),0)
    ) else '{}'::jsonb end,
    'specialized',case when can_specialized then jsonb_build_object(
      'tahfiz_progress',coalesce((select st.current_progress from public.student_tahfiz st where st.student_id=s.id),null),
      'arabic_progress',coalesce((select sa.current_progress from public.student_arabic sa where sa.student_id=s.id),null),
      'wushu_grade',coalesce((select sw.current_grade from public.student_wushu sw where sw.student_id=s.id),null),
      'wushu_status',coalesce((select sw.status from public.student_wushu sw where sw.student_id=s.id),null)
    ) else '{}'::jsonb end
  ) into out_json
  from public.students s where s.id=p_student_id;

  return out_json;
end;
$$;

create or replace function public.ai_tool_search_students(p_query text,p_limit integer default 8)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  q text := lower(btrim(coalesce(p_query,'')));
  lim integer := least(greatest(coalesce(p_limit,8),1),20);
  result jsonb;
begin
  if q='' then return '[]'::jsonb; end if;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into result
  from (
    select s.id,s.student_number,s.first_name,s.last_name,c.name class_name
    from public.students s
    left join lateral (
      select c.name
      from public.enrollments e join public.classes c on c.id=e.class_id
      join public.school_years sy on sy.id=e.school_year_id
      where e.student_id=s.id and e.status='enrolled' and sy.is_current=true
      order by sy.start_date desc limit 1
    ) c on true
    where s.school_id in (select app.my_school_ids())
      and (lower(s.first_name||' '||s.last_name) like '%'||q||'%'
        or lower(s.last_name||' '||s.first_name) like '%'||q||'%'
        or lower(coalesce(s.student_number,'')) like '%'||q||'%')
      and (
        app.is_super_admin()
        or app.has_permission('students.view',s.school_id)
        or app.has_permission('students.manage',s.school_id)
        or app.is_parent_of_student(s.id)
        or app.is_self_student(s.id)
        or app.is_teacher_for_student(s.id)
      )
    order by s.last_name,s.first_name
    limit lim
  ) x;
  return result;
end;
$$;

-- RLS dedicated to the new AI governance tables.
alter table public.ai_prompt_templates enable row level security;
alter table public.ai_runs enable row level security;
alter table public.ai_tool_calls enable row level security;

drop policy if exists ai_prompt_templates_select on public.ai_prompt_templates;
drop policy if exists ai_prompt_templates_manage on public.ai_prompt_templates;
create policy ai_prompt_templates_select on public.ai_prompt_templates for select to authenticated using(
  app.is_super_admin() or app.has_permission('ai.use',coalesce(school_id,(select u.school_id from public.users u where u.id=auth.uid())))
);
create policy ai_prompt_templates_manage on public.ai_prompt_templates for all to authenticated using(
  app.is_super_admin() or app.has_permission('ai.manage',coalesce(school_id,(select u.school_id from public.users u where u.id=auth.uid())))
) with check(
  app.is_super_admin() or app.has_permission('ai.manage',coalesce(school_id,(select u.school_id from public.users u where u.id=auth.uid())))
);

drop policy if exists ai_runs_select_secure on public.ai_runs;
drop policy if exists ai_runs_insert_secure on public.ai_runs;
drop policy if exists ai_runs_update_secure on public.ai_runs;
create policy ai_runs_select_secure on public.ai_runs for select to authenticated using(
  user_id=auth.uid() or app.has_permission('ai.manage',school_id) or app.is_super_admin()
);
create policy ai_runs_insert_secure on public.ai_runs for insert to authenticated with check(
  user_id=auth.uid() and (app.has_permission('ai.use',school_id) or app.is_super_admin())
);
create policy ai_runs_update_secure on public.ai_runs for update to authenticated using(
  user_id=auth.uid() or app.has_permission('ai.manage',school_id) or app.is_super_admin()
) with check(
  user_id=auth.uid() or app.has_permission('ai.manage',school_id) or app.is_super_admin()
);

drop policy if exists ai_tool_calls_select_secure on public.ai_tool_calls;
create policy ai_tool_calls_select_secure on public.ai_tool_calls for select to authenticated using(
  exists(select 1 from public.ai_runs r where r.id=run_id and (r.user_id=auth.uid() or app.has_permission('ai.manage',r.school_id) or app.is_super_admin()))
);
drop policy if exists ai_tool_calls_insert_secure on public.ai_tool_calls;
create policy ai_tool_calls_insert_secure on public.ai_tool_calls for insert to authenticated with check(
  exists(select 1 from public.ai_runs r where r.id=run_id and r.user_id=auth.uid() and (app.has_permission('ai.use',r.school_id) or app.is_super_admin()))
);

-- Messages: history is append-only through the authenticated session.
drop policy if exists ai_messages_secure on public.ai_messages;
drop policy if exists ai_messages_select_secure on public.ai_messages;
drop policy if exists ai_messages_insert_secure on public.ai_messages;
drop policy if exists ai_messages_update_secure on public.ai_messages;
drop policy if exists ai_messages_delete_secure on public.ai_messages;
create policy ai_messages_select_secure on public.ai_messages for select to authenticated using(
  exists(select 1 from public.ai_conversations c where c.id=conversation_id and (c.user_id=auth.uid() or app.has_permission('ai.manage',c.school_id) or app.is_super_admin()))
);
create policy ai_messages_insert_secure on public.ai_messages for insert to authenticated with check(
  exists(select 1 from public.ai_conversations c where c.id=conversation_id and c.user_id=auth.uid() and (app.has_permission('ai.use',c.school_id) or app.is_super_admin()))
);

-- Conversations: user owns its private history; AI managers may audit the school's histories.
drop policy if exists ai_conversations_select_secure on public.ai_conversations;
drop policy if exists ai_conversations_insert_secure on public.ai_conversations;
drop policy if exists ai_conversations_update_secure on public.ai_conversations;
drop policy if exists ai_conversations_delete_secure on public.ai_conversations;
create policy ai_conversations_select_secure on public.ai_conversations for select to authenticated using(
  user_id=auth.uid() or app.has_permission('ai.manage',school_id) or app.is_super_admin()
);
create policy ai_conversations_insert_secure on public.ai_conversations for insert to authenticated with check(
  user_id=auth.uid() and (app.has_permission('ai.use',school_id) or app.is_super_admin())
);
create policy ai_conversations_update_secure on public.ai_conversations for update to authenticated using(
  user_id=auth.uid() or app.has_permission('ai.manage',school_id) or app.is_super_admin()
) with check(
  user_id=auth.uid() or app.has_permission('ai.manage',school_id) or app.is_super_admin()
);
create policy ai_conversations_delete_secure on public.ai_conversations for delete to authenticated using(
  user_id=auth.uid() or app.has_permission('ai.manage',school_id) or app.is_super_admin()
);

-- Alerts are drafts until a responsible user reviews them.
drop policy if exists ai_alerts_select_secure on public.ai_alerts;
drop policy if exists ai_alerts_insert_secure on public.ai_alerts;
drop policy if exists ai_alerts_update_secure on public.ai_alerts;
drop policy if exists ai_alerts_delete_secure on public.ai_alerts;
create policy ai_alerts_select_secure on public.ai_alerts for select to authenticated using(
  app.has_permission('ai.alerts.review',school_id) or app.has_permission('ai.manage',school_id)
  or app.has_role_code('direction',school_id) or app.has_role_code('founder',school_id) or app.is_super_admin()
);
create policy ai_alerts_insert_secure on public.ai_alerts for insert to authenticated with check(
  app.has_permission('ai.use',school_id) or app.is_super_admin()
);
create policy ai_alerts_update_secure on public.ai_alerts for update to authenticated using(
  app.has_permission('ai.alerts.review',school_id) or app.has_permission('ai.manage',school_id) or app.is_super_admin()
) with check(
  app.has_permission('ai.alerts.review',school_id) or app.has_permission('ai.manage',school_id) or app.is_super_admin()
);
create policy ai_alerts_delete_secure on public.ai_alerts for delete to authenticated using(
  app.has_permission('ai.manage',school_id) or app.is_super_admin()
);

revoke all on public.ai_conversations from anon;
revoke all on public.ai_messages from anon;
revoke all on public.ai_alerts from anon;
revoke all on public.ai_prompt_templates from anon;
revoke all on public.ai_runs from anon;
revoke all on public.ai_tool_calls from anon;

grant select,insert,update,delete on public.ai_conversations to authenticated;
grant select,insert,update,delete on public.ai_messages to authenticated;
grant select,insert,update,delete on public.ai_alerts to authenticated;
grant select,insert,update,delete on public.ai_prompt_templates to authenticated;
grant select,insert,update on public.ai_runs to authenticated;
grant select,insert on public.ai_tool_calls to authenticated;

grant execute on function public.ai_tool_student_summary(uuid) to authenticated;
grant execute on function public.ai_tool_search_students(text,integer) to authenticated;

-- Initial reusable prompts. They are generic by design; school-specific rules remain in data/configuration.
insert into public.ai_prompt_templates(school_id,code,name,description,system_prompt,capabilities)
values
(null,'school_assistant','Assistant SIGIA-AMINE','Assistant général de gestion scolaire',
'Vous êtes l''assistant du SIGIA-AMINE. Répondez en français, avec des faits issus des outils autorisés. N''inventez jamais une donnée absente. Séparez clairement les chiffres observés des interprétations. Ne modifiez jamais directement les données métier. Pour toute décision sensible, formulez une recommandation à valider par un responsable humain.',
'["search","analyze","compare","summarize","draft"]'::jsonb),
(null,'pedagogy_analysis','Analyse pédagogique','Analyse des résultats et de l’assiduité',
'Analysez uniquement les résultats, évaluations, bulletins et indicateurs d''assiduité fournis par les outils. Signalez les tendances et anomalies sans poser de diagnostic sur une personne.',
'["analyze","compare","summarize"]'::jsonb),
(null,'finance_analysis','Analyse financière','Analyse des recettes, dépenses et soldes',
'Analysez uniquement les données financières retournées par les outils. Ne donnez pas de conseil fiscal ou juridique personnalisé. Signalez les écarts et points à vérifier.',
'["analyze","compare","summarize"]'::jsonb),
(null,'alert_scan','Détection d’alertes','Repérage de situations nécessitant une revue humaine',
'Repérez uniquement des signaux observables dans les données. Créez des alertes en statut open et indiquez toujours les éléments factuels qui les justifient. Une alerte IA n''est pas une décision.',
'["alert"]'::jsonb)
on conflict do nothing;

comment on table public.ai_runs is 'Traçabilité des exécutions IA : fournisseur, modèle, durée, statut et consommation.';
comment on table public.ai_tool_calls is 'Traçabilité des outils de lecture utilisés par une exécution IA.';
comment on table public.ai_prompt_templates is 'Prompts gouvernés, réutilisables et paramétrables par établissement.';
comment on column public.ai_alerts.status is 'Cycle de revue humaine. Une alerte générée par IA reste un signal, pas une décision.';

commit;
