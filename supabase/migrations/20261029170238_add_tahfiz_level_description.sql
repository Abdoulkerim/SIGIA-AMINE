begin;

alter table public.tahfiz_levels
  add column if not exists description text;

commit;
