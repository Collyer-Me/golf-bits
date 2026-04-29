-- Marketing email consent (user-controlled; own row only via existing RLS).
alter table public.profiles
  add column if not exists marketing_opt_in boolean not null default false;
