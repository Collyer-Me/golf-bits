-- Support mixed participant identities:
-- - guest players (no account)
-- - linked account players (matched by email -> user_id)
-- Safe to re-run.

-- 1) rounds: store participant metadata and identity-aware scores
alter table public.rounds add column if not exists participants jsonb not null default '[]'::jsonb;

-- 2) round_bit_events: optional participant identity columns
alter table public.round_bit_events add column if not exists participant_key text;
alter table public.round_bit_events add column if not exists participant_user_id uuid;

create index if not exists round_bit_events_round_participant_idx
  on public.round_bit_events (round_id, participant_key, hole);

-- 3) profiles: email needed for exact-match lookup by email
alter table public.profiles add column if not exists email text;
create index if not exists profiles_email_idx on public.profiles (lower(email));

-- Keep profile row in sync with auth.users, including email.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1),
      'Player'
    ),
    new.email
  )
  on conflict (id) do update
    set display_name = excluded.display_name,
        email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

-- Backfill email for existing rows.
update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id
  and (p.email is distinct from u.email);

-- 4) RPC for exact email lookup (used during Add Player).
--    SECURITY DEFINER allows reading auth.users-derived email safely via profiles.
create or replace function public.lookup_player_by_email(input_email text)
returns table(user_id uuid, display_name text, email text)
language sql
security definer
set search_path = public
as $$
  select p.id, p.display_name, p.email
  from public.profiles p
  where lower(p.email) = lower(trim(input_email))
  limit 1
$$;

grant execute on function public.lookup_player_by_email(text) to authenticated;
