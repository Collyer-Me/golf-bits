-- Run via Supabase CLI or paste into SQL Editor (Dashboard → SQL).
-- 1) Profiles mirror auth metadata
-- 2) Rounds history for signed-in users (created_by = auth.uid())

-- ─── profiles ─────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1),
      'Player'
    )
  )
  on conflict (id) do update
    set display_name = excluded.display_name,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Backfill profiles for accounts created before this migration (safe to re-run).
insert into public.profiles (id, display_name)
select
  u.id,
  coalesce(
    nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
    split_part(coalesce(u.email, ''), '@', 1),
    'Player'
  )
from auth.users u
on conflict (id) do nothing;

-- ─── rounds (history list + detail; JSON for nested rows) ──────────────────
create table if not exists public.rounds (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users (id) on delete cascade,
  course_name text not null,
  course_short_title text not null,
  hole_count int not null default 18,
  completed boolean not null default true,
  ended_at timestamptz not null default now(),
  winner_name text not null,
  winner_bits int not null default 0,
  players text[] not null default '{}',
  standings jsonb not null default '[]',
  left_early jsonb not null default '[]',
  created_at timestamptz not null default now()
);

create index if not exists rounds_created_by_ended_at_idx
  on public.rounds (created_by, ended_at desc);

alter table public.rounds enable row level security;

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
