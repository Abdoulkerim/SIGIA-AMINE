create or replace function public.seed_default_academic_periods()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_day_count integer := new.end_date - new.start_date + 1;
begin
  if v_day_count < 3 then
    return new;
  end if;

  insert into public.academic_periods (
    school_year_id, name, code, start_date, end_date, sequence_no
  ) values
    (new.id, 'Trimestre 1', 'T1', new.start_date, new.start_date + (v_day_count / 3) - 1, 1),
    (new.id, 'Trimestre 2', 'T2', new.start_date + (v_day_count / 3), new.start_date + ((v_day_count * 2) / 3) - 1, 2),
    (new.id, 'Trimestre 3', 'T3', new.start_date + ((v_day_count * 2) / 3), new.end_date, 3)
  on conflict (school_year_id, code) do nothing;

  return new;
end;
$$;

drop trigger if exists school_years_seed_default_periods on public.school_years;
create trigger school_years_seed_default_periods
after insert on public.school_years
for each row execute function public.seed_default_academic_periods();

insert into public.academic_periods (
  school_year_id, name, code, start_date, end_date, sequence_no
)
select
  sy.id,
  period.name,
  period.code,
  period.start_date,
  period.end_date,
  period.sequence_no
from public.school_years sy
cross join lateral (
  select
    bounds.sequence_no,
    bounds.name,
    bounds.code,
    case bounds.sequence_no
      when 1 then sy.start_date
      when 2 then sy.start_date + ((sy.end_date - sy.start_date + 1) / 3)
      else sy.start_date + (((sy.end_date - sy.start_date + 1) * 2) / 3)
    end as start_date,
    case bounds.sequence_no
      when 1 then sy.start_date + ((sy.end_date - sy.start_date + 1) / 3) - 1
      when 2 then sy.start_date + (((sy.end_date - sy.start_date + 1) * 2) / 3) - 1
      else sy.end_date
    end as end_date
  from (values
    (1, 'Trimestre 1'::text, 'T1'::text),
    (2, 'Trimestre 2'::text, 'T2'::text),
    (3, 'Trimestre 3'::text, 'T3'::text)
  ) as bounds(sequence_no, name, code)
) period
where sy.end_date - sy.start_date + 1 >= 3
  and not exists (
    select 1 from public.academic_periods ap where ap.school_year_id = sy.id
  );
