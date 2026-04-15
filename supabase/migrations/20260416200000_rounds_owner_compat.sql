-- Compatibility for legacy rounds owner columns (`user_id`, `owner_id`) that may
-- still be NOT NULL in older projects.
-- Safe to re-run.

do $$
begin
  -- If `user_id` exists and `created_by` exists, backfill created_by from user_id.
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'user_id'
  ) and exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'created_by'
  ) then
    execute 'update public.rounds set created_by = user_id where created_by is null and user_id is not null';
  end if;

  -- Keep legacy columns auto-populated for anon-key inserts.
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'user_id'
  ) then
    execute 'alter table public.rounds alter column user_id set default auth.uid()';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'owner_id'
  ) then
    execute 'alter table public.rounds alter column owner_id set default auth.uid()';
  end if;
end $$;
