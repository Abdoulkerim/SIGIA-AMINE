begin;

create unique index if not exists students_id_school_id_uidx
on public.students (id, school_id);
create table public.specialized_report_cards (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null,
  module text not null check (module in ('wushu','arabic','tahfiz')),
  period_start date not null,
  period_end date not null,
  average_score numeric(10,2) not null,
  evaluation_count integer not null check (evaluation_count > 0),
  evaluations jsonb not null default '[]'::jsonb,
  status text not null default 'draft' check (status in ('draft','published')),
  created_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
    constraint specialized_report_cards_dates
    check (period_start <= period_end),

  constraint specialized_report_cards_student_period
    unique (school_id, module, student_id, period_start, period_end),

  constraint specialized_report_cards_student_school_fkey
    foreign key (student_id, school_id)
    references public.students (id, school_id)
    on delete cascade
);

alter table public.specialized_report_cards enable row level security;

revoke all on table public.specialized_report_cards
from public, anon, authenticated;

grant select, insert, update
on public.specialized_report_cards
to authenticated;

create policy specialized_report_cards_read on public.specialized_report_cards
for select to authenticated using (
  (status = 'published' and (app.is_self_student(student_id) or app.is_parent_of_student(student_id)))
  or app.has_permission(module || '.view', school_id)
  or app.has_permission(module || '.manage', school_id)
  or app.is_super_admin()
);
create policy specialized_report_cards_manage on public.specialized_report_cards
for all to authenticated using (app.has_permission(module || '.manage', school_id) or app.is_super_admin())
with check (app.has_permission(module || '.manage', school_id) or app.is_super_admin());

create or replace function public.generate_specialized_report_cards(
  p_module text, p_period_start date, p_period_end date, p_school_id uuid
) returns integer
language plpgsql security invoker set search_path = '' as $$
declare
  v_school uuid;
  v_count integer := 0;
  v_rows integer := 0;
begin
    if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_module is null
     or p_module not in ('wushu', 'arabic', 'tahfiz')
     or p_period_start is null
     or p_period_end is null
     or p_period_start > p_period_end then
    raise exception 'Paramètres de bulletin invalides';
  end if;

  if p_school_id is null then
    raise exception 'SCHOOL_REQUIRED';
  end if;

  if not coalesce(
    app.has_permission(p_module || '.manage', p_school_id)
      or app.is_super_admin(),
    false
  ) then
    raise exception 'Permission de gestion du groupe requise';
  end if;

  v_school := p_school_id;
      if p_module = 'wushu' then
        insert into public.specialized_report_cards(school_id,student_id,module,period_start,period_end,average_score,evaluation_count,evaluations,created_by,updated_at)
        select v_school,e.student_id,p_module,p_period_start,p_period_end,round(avg(e.score)::numeric,2),count(*)::int,
          jsonb_agg(jsonb_build_object('date',e.evaluation_date,'type',e.evaluation_type,'score',e.score,'max_score',e.max_score,'grade',e.grade_awarded,'area',e.skill_area,'observation',e.observation) order by e.evaluation_date),auth.uid(),now()
        from public.wushu_evaluations e where e.school_id=v_school and e.evaluation_date between p_period_start and p_period_end and e.score is not null and e.is_published
        group by e.student_id
        on conflict (school_id,module,student_id,period_start,period_end) do update set average_score=excluded.average_score,evaluation_count=excluded.evaluation_count,evaluations=excluded.evaluations,updated_at=now()
        where public.specialized_report_cards.status='draft';
      elsif p_module = 'arabic' then
        insert into public.specialized_report_cards(school_id,student_id,module,period_start,period_end,average_score,evaluation_count,evaluations,created_by,updated_at)
        select v_school,e.student_id,p_module,p_period_start,p_period_end,round(avg(e.score)::numeric,2),count(*)::int,
          jsonb_agg(jsonb_build_object('date',e.evaluation_date,'type',e.title,'score',e.score,'area',e.skill_area,'observation',e.observation) order by e.evaluation_date),auth.uid(),now()
        from public.arabic_evaluations e where e.school_id=v_school and e.evaluation_date between p_period_start and p_period_end and e.score is not null and e.is_published
        group by e.student_id
        on conflict (school_id,module,student_id,period_start,period_end) do update set average_score=excluded.average_score,evaluation_count=excluded.evaluation_count,evaluations=excluded.evaluations,updated_at=now()
        where public.specialized_report_cards.status='draft';
      else
        insert into public.specialized_report_cards(school_id,student_id,module,period_start,period_end,average_score,evaluation_count,evaluations,created_by,updated_at)
        select v_school,e.student_id,p_module,p_period_start,p_period_end,round(avg(e.score)::numeric,2),count(*)::int,
          jsonb_agg(jsonb_build_object('date',e.session_date,'type','Évaluation Tahfiz','score',e.score,'surah',q.name_fr,'observation',e.observation) order by e.session_date),auth.uid(),now()
        from public.tahfiz_sessions e
        left join public.quran_surahs q on q.id = e.surah_id
        where e.school_id = v_school
          and e.session_date between p_period_start and p_period_end
          and e.session_type = 'evaluation'
          and e.score is not null
          and e.is_published
        group by e.student_id
        on conflict (school_id,module,student_id,period_start,period_end) do update set average_score=excluded.average_score,evaluation_count=excluded.evaluation_count,evaluations=excluded.evaluations,updated_at=now()
        where public.specialized_report_cards.status='draft';
      end if;
      get diagnostics v_rows = row_count;
      v_count := v_count + v_rows;
  return v_count;
end;
$$;

create or replace function public.publish_specialized_report_card(p_report_card_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare v_card public.specialized_report_cards%rowtype;
begin
  select * into v_card from public.specialized_report_cards where id=p_report_card_id for update;
  if not found then raise exception 'Bulletin introuvable'; end if;
    if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not coalesce(
    app.has_permission(v_card.module || '.manage', v_card.school_id)
      or app.is_super_admin(),
    false
  ) then
    raise exception 'Permission de gestion du groupe requise';
  end if;
  update public.specialized_report_cards set status='published',published_at=now(),updated_at=now() where id=p_report_card_id and status='draft';
end;
$$;

revoke all on function public.generate_specialized_report_cards(text,date,date,uuid) from public, anon;
revoke all on function public.publish_specialized_report_card(uuid) from public, anon;
grant execute on function public.generate_specialized_report_cards(text,date,date,uuid) to authenticated;
grant execute on function public.publish_specialized_report_card(uuid) to authenticated;

commit;
