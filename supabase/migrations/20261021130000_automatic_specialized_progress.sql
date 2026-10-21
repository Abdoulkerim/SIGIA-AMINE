begin;

-- Verse counts use the 6,236-verse Hafs count so Tahfiz progress can be based
-- on the distinct verses recorded as new memorization.
update public.quran_surahs as q
set verse_count = v.verse_count
from (values
  (1,7),(2,286),(3,200),(4,176),(5,120),(6,165),(7,206),(8,75),(9,129),(10,109),
  (11,123),(12,111),(13,43),(14,52),(15,99),(16,128),(17,111),(18,110),(19,98),(20,135),
  (21,112),(22,78),(23,118),(24,64),(25,77),(26,227),(27,93),(28,88),(29,69),(30,60),
  (31,34),(32,30),(33,73),(34,54),(35,45),(36,83),(37,182),(38,88),(39,75),(40,85),
  (41,54),(42,53),(43,89),(44,59),(45,37),(46,35),(47,38),(48,29),(49,18),(50,45),
  (51,60),(52,49),(53,62),(54,55),(55,78),(56,96),(57,29),(58,22),(59,24),(60,13),
  (61,14),(62,11),(63,11),(64,18),(65,12),(66,12),(67,30),(68,52),(69,52),(70,44),
  (71,28),(72,28),(73,20),(74,56),(75,40),(76,31),(77,50),(78,40),(79,46),(80,42),
  (81,29),(82,19),(83,36),(84,25),(85,22),(86,17),(87,19),(88,26),(89,30),(90,20),
  (91,15),(92,21),(93,11),(94,8),(95,8),(96,19),(97,5),(98,8),(99,8),(100,11),
  (101,11),(102,8),(103,3),(104,9),(105,5),(106,4),(107,7),(108,3),(109,6),(110,3),
  (111,5),(112,4),(113,5),(114,6)
) as v(surah_number, verse_count)
where q.surah_number = v.surah_number;

create or replace function app.refresh_specialized_progress(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_progress numeric(6,2);
  v_scale numeric;
  v_eval_progress numeric;
  v_attendance_progress numeric;
  v_eval_count integer;
  v_attendance_count integer;
  v_profile_id uuid;
begin
  -- Tahfiz: unique verses covered by new memorization sessions / all 6,236 verses.
  select round(least(100, count(*)::numeric * 100 / 6236), 2)
  into v_progress
  from (
    select distinct s.surah_id, verse.verse_number
    from public.tahfiz_sessions s
    join public.quran_surahs q on q.id = s.surah_id
    cross join lateral generate_series(s.from_verse::integer, s.to_verse::integer) as verse(verse_number)
    where s.student_id = p_student_id
      and s.session_type = 'new_memorization'
      and s.from_verse is not null
      and s.to_verse is not null
      and s.from_verse >= 1
      and s.to_verse <= q.verse_count
  ) covered_verses;
  v_progress := coalesce(v_progress, 0);
  update public.student_tahfiz
  set current_progress = v_progress, updated_at = now()
  where student_id = p_student_id and current_progress is distinct from v_progress
  returning id, school_id into v_profile_id, v_school_id;
  if found then
    insert into public.tahfiz_progress_history(school_id, student_tahfiz_id, student_id, progress, note, recorded_by)
    values(v_school_id, v_profile_id, p_student_id, v_progress, 'Calcul automatique des versets mémorisés', auth.uid());
  end if;

  -- Arabic: mean session and evaluation score, normalized to the school scale.
  select school_id into v_school_id from public.student_arabic where student_id = p_student_id;
  if found then
    select greatest(coalesce(ss.grading_scale, 20), 0.01) into v_scale
    from public.school_settings ss where ss.school_id = v_school_id;
    v_scale := coalesce(v_scale, 20);
    select round(least(100, coalesce(avg(score), 0) * 100 / v_scale), 2), count(*)
    into v_progress, v_eval_count
    from (
      select score from public.arabic_sessions where student_id = p_student_id and score is not null
      union all
      select score from public.arabic_evaluations where student_id = p_student_id and score is not null
    ) scores;
    update public.student_arabic
    set current_progress = coalesce(v_progress, 0), updated_at = now()
    where student_id = p_student_id and current_progress is distinct from coalesce(v_progress, 0)
    returning id into v_profile_id;
    if found then
      insert into public.arabic_progress_history(school_id, student_arabic_id, student_id, progress, note, recorded_by)
      values(v_school_id, v_profile_id, p_student_id, coalesce(v_progress, 0), 'Calcul automatique des séances et évaluations', auth.uid());
    end if;
  end if;

  -- Wushu: evaluations normalized by their own maximum (or school scale),
  -- combined with attendance when both kinds of evidence are available.
  select school_id into v_school_id from public.student_wushu where student_id = p_student_id;
  if found then
    select greatest(coalesce(ss.grading_scale, 20), 0.01) into v_scale
    from public.school_settings ss where ss.school_id = v_school_id;
    v_scale := coalesce(v_scale, 20);
    select avg(least(100, e.score * 100 / coalesce(nullif(e.max_score, 0), v_scale))), count(*)
    into v_eval_progress, v_eval_count
    from public.wushu_evaluations e
    where e.student_id = p_student_id and e.score is not null;
    select count(*) filter (where a.status::text in ('present','late'))::numeric * 100 / nullif(count(*), 0), count(*)
    into v_attendance_progress, v_attendance_count
    from public.wushu_attendance a
    where a.student_id = p_student_id;
    v_progress := case
      when coalesce(v_eval_count, 0) > 0 and coalesce(v_attendance_count, 0) > 0
        then round(v_eval_progress * 0.7 + v_attendance_progress * 0.3, 2)
      when coalesce(v_eval_count, 0) > 0 then round(v_eval_progress, 2)
      when coalesce(v_attendance_count, 0) > 0 then round(v_attendance_progress, 2)
      else 0
    end;
    update public.student_wushu
    set current_progress = v_progress, updated_at = now()
    where student_id = p_student_id and current_progress is distinct from v_progress;
  end if;
end;
$$;

create or replace function app.refresh_specialized_progress_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.refresh_specialized_progress(case when tg_op = 'DELETE' then old.student_id else new.student_id end);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_tahfiz_auto_progress on public.tahfiz_sessions;
create trigger trg_tahfiz_auto_progress
after insert or update or delete on public.tahfiz_sessions
for each row execute function app.refresh_specialized_progress_trigger();

drop trigger if exists trg_arabic_sessions_auto_progress on public.arabic_sessions;
create trigger trg_arabic_sessions_auto_progress
after insert or update or delete on public.arabic_sessions
for each row execute function app.refresh_specialized_progress_trigger();
drop trigger if exists trg_arabic_evaluations_auto_progress on public.arabic_evaluations;
create trigger trg_arabic_evaluations_auto_progress
after insert or update or delete on public.arabic_evaluations
for each row execute function app.refresh_specialized_progress_trigger();

drop trigger if exists trg_wushu_evaluations_auto_progress on public.wushu_evaluations;
create trigger trg_wushu_evaluations_auto_progress
after insert or update or delete on public.wushu_evaluations
for each row execute function app.refresh_specialized_progress_trigger();
drop trigger if exists trg_wushu_attendance_auto_progress on public.wushu_attendance;
create trigger trg_wushu_attendance_auto_progress
after insert or update or delete on public.wushu_attendance
for each row execute function app.refresh_specialized_progress_trigger();

drop trigger if exists trg_tahfiz_profile_initial_progress on public.student_tahfiz;
create trigger trg_tahfiz_profile_initial_progress
after insert on public.student_tahfiz
for each row execute function app.refresh_specialized_progress_trigger();
drop trigger if exists trg_tahfiz_profile_refresh_progress on public.student_tahfiz;
create trigger trg_tahfiz_profile_refresh_progress
after update of current_progress on public.student_tahfiz
for each row execute function app.refresh_specialized_progress_trigger();
drop trigger if exists trg_arabic_profile_initial_progress on public.student_arabic;
create trigger trg_arabic_profile_initial_progress
after insert on public.student_arabic
for each row execute function app.refresh_specialized_progress_trigger();
drop trigger if exists trg_arabic_profile_refresh_progress on public.student_arabic;
create trigger trg_arabic_profile_refresh_progress
after update of current_progress on public.student_arabic
for each row execute function app.refresh_specialized_progress_trigger();
drop trigger if exists trg_wushu_profile_initial_progress on public.student_wushu;
create trigger trg_wushu_profile_initial_progress
after insert on public.student_wushu
for each row execute function app.refresh_specialized_progress_trigger();
drop trigger if exists trg_wushu_profile_refresh_progress on public.student_wushu;
create trigger trg_wushu_profile_refresh_progress
after update of current_progress on public.student_wushu
for each row execute function app.refresh_specialized_progress_trigger();

-- Recalculate existing records after installing the new rules.
do $$
declare v_student record;
begin
  for v_student in select student_id from public.student_tahfiz
    union select student_id from public.student_arabic
    union select student_id from public.student_wushu
  loop
    perform app.refresh_specialized_progress(v_student.student_id);
  end loop;
end;
$$;

revoke all on function app.refresh_specialized_progress(uuid) from public, anon, authenticated;
revoke all on function app.refresh_specialized_progress_trigger() from public, anon, authenticated;

commit;
