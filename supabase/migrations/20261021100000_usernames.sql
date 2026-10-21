begin;

alter table public.users
  add column if not exists username text;

alter table public.users
  add constraint users_username_format_check
  check (username is null or username = lower(btrim(username)) and username ~ '^[a-z0-9._-]{3,40}$');

create unique index if not exists users_username_unique
  on public.users (username)
  where username is not null;

comment on column public.users.username is 'Login identifier, normalized to lowercase; nullable for legacy accounts.';

commit;
