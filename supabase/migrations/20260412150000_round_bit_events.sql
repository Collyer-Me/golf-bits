-- Bit events awarded during a round (linked to public.rounds).
-- Run after 20260412130000_profiles_and_rounds.sql.

-- If `public.rounds` already existed before our migrations, it may be missing
-- `created_by`. Add it defensively so RLS joins compile.
alter table public.rounds
  add column if not exists created_by uuid references auth.users (id) on delete cascade;

-- Best-effort backfill from common legacy owner columns.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'user_id'
  ) then
    execute 'update public.rounds set created_by = user_id where created_by is null';
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'owner_id'
  ) then
    execute 'update public.rounds set created_by = owner_id where created_by is null';
  end if;
end $$;

create table if not exists public.round_bit_events (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.rounds (id) on delete cascade,
  player_name text not null,
  hole int not null,
  event_label text not null,
  delta int not null,
  icon_key text,
  created_at timestamptz not null default now()
);

create index if not exists round_bit_events_round_player_idx
  on public.round_bit_events (round_id, player_name, hole);

alter table public.round_bit_events enable row level security;

drop policy if exists "round_bit_events_select" on public.round_bit_events;
create policy "round_bit_events_select"
  on public.round_bit_events for select
  using (
    exists (
      select 1 from public.rounds r
      where r.id = round_bit_events.round_id and r.created_by = auth.uid()
    )
  );

drop policy if exists "round_bit_events_insert" on public.round_bit_events;
create policy "round_bit_events_insert"
  on public.round_bit_events for insert
  with check (
    exists (
      select 1 from public.rounds r
      where r.id = round_bit_events.round_id and r.created_by = auth.uid()
    )
  );

drop policy if exists "round_bit_events_delete" on public.round_bit_events;
create policy "round_bit_events_delete"
  on public.round_bit_events for delete
  using (
    exists (
      select 1 from public.rounds r
      where r.id = round_bit_events.round_id and r.created_by = auth.uid()
    )
  );
