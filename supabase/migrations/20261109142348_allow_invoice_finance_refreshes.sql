-- Finance refresh triggers only change status/totals and updated_at. Do not
-- rerun the education-stage guard for those derived-only updates. Any change
-- to invoice scope or any other invoice field still runs the guard.

drop trigger if exists trg_apply_education_stage on public.invoices;
drop trigger if exists trg_apply_education_stage_insert on public.invoices;
drop trigger if exists trg_apply_education_stage_update on public.invoices;

create trigger trg_apply_education_stage_insert
before insert on public.invoices
for each row execute function app.apply_education_stage();

create trigger trg_apply_education_stage_update
before update on public.invoices
for each row
when (
  (to_jsonb(old) - array['status', 'subtotal', 'total', 'updated_at'])
  is distinct from
  (to_jsonb(new) - array['status', 'subtotal', 'total', 'updated_at'])
)
execute function app.apply_education_stage();
