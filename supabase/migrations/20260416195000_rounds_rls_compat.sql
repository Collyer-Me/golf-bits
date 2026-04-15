-- Ensure rounds RLS policies support current app writes.
-- Safe to re-run.

alter table public.rounds add column if not exists created_by uuid references auth.users (id) on delete cascade;

-- New inserts can omit created_by and still satisfy policy checks.
alter table public.rounds alter column created_by set default auth.uid();

alter table public.rounds enable row level security;

drop policy if exists "rounds_select_own" on public.rounds;
drop policy if exists "rounds_insert_own" on public.rounds;
drop policy if exists "rounds_update_own" on public.rounds;
drop policy if exists "rounds_delete_own" on public.rounds;

create policy "rounds_select_own"
  on public.rounds for select
  using (auth.uid() = created_by);

create policy "rounds_insert_own"
  on public.rounds for insert
  with check (auth.uid() = created_by);

create policy "rounds_update_own"
  on public.rounds for update
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

create policy "rounds_delete_own"
  on public.rounds for delete
  using (auth.uid() = created_by);
