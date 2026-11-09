-- Payment allocations must always point to an invoice or student charge.
-- When an invoice is deleted, remove its allocation rather than setting the
-- invoice reference to NULL and leaving an invalid orphan row.

alter table public.payment_allocations
  drop constraint if exists payment_allocations_invoice_id_fkey;

alter table public.payment_allocations
  add constraint payment_allocations_invoice_id_fkey
    foreign key (invoice_id) references public.invoices(id) on delete cascade;
