-- Pre-beta: JWT email auth, friend search hardening, invite expiry, coplayer perf,
-- claim_participant filter, client_errors observability.

-- ─── helpers ───────────────────────────────────────────────────────────────

create or replace function public.current_user_verified_email()
returns text
language sql
stable
set search_path = public
as $$
  select nullif(lower(trim(coalesce(auth.jwt()->>'email', ''))), '');
$$;

create or replace function public.current_user_is_anonymous()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce((auth.jwt()->>'is_anonymous')::boolean, false);
$$;

create or replace function public.escape_like_pattern(input text)
returns text
language sql
immutable
as $$
  select replace(replace(replace(coalesce(input, ''), '\', '\\'), '%', '\%'), '_', '\_');
$$;

-- ─── profiles.email server-managed ─────────────────────────────────────────

create or replace function public.profiles_sync_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select u.email into new.email from auth.users u where u.id = new.id;
  return new;
end;
$$;

drop trigger if exists profiles_sync_email_from_auth on public.profiles;
create trigger profiles_sync_email_from_auth
  before insert or update on public.profiles
  for each row
  execute function public.profiles_sync_email_from_auth();

update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id
  and (p.email is distinct from u.email);

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

-- ─── round invites: JWT email + expiry + dedup ─────────────────────────────

alter table public.round_invites
  add column if not exists expires_at timestamptz not null default (now() + interval '14 days');

update public.round_invites
set expires_at = created_at + interval '14 days'
where expires_at is null;

-- Remove duplicate (round_id, email) rows before unique index; keep newest.
delete from public.round_invites ri
using (
  select round_id, lower(trim(invited_email)) as email_norm, max(created_at) as max_created
  from public.round_invites
  group by round_id, lower(trim(invited_email))
  having count(*) > 1
) d
where ri.round_id = d.round_id
  and lower(trim(ri.invited_email)) = d.email_norm
  and ri.created_at < d.max_created;

create unique index if not exists round_invites_round_email_unique_idx
  on public.round_invites (round_id, invited_email);

drop policy if exists "round_invites_select_own_or_invited" on public.round_invites;
create policy "round_invites_select_own_or_invited"
on public.round_invites
for select
to authenticated
using (
  invited_by_user_id = auth.uid()
  or (
    public.current_user_verified_email() is not null
    and lower(trim(public.round_invites.invited_email)) = public.current_user_verified_email()
  )
);

create or replace function public.accept_round_invite_for_current_user(invite_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  my_email text := public.current_user_verified_email();
  inv record;
  r record;
  new_parts jsonb;
begin
  if uid is null or invite_token is null or length(trim(invite_token)) < 12 then
    return false;
  end if;

  if my_email is null or length(my_email) < 3 then
    return false;
  end if;

  select *
  into inv
  from public.round_invites ri
  where ri.token = trim(invite_token)
  limit 1;

  if not found then
    return false;
  end if;

  if lower(trim(inv.invited_email)) <> my_email then
    return false;
  end if;

  if inv.status = 'accepted' and inv.accepted_by_user_id = uid then
    return true;
  end if;

  if inv.status not in ('pending', 'sent') then
    return false;
  end if;

  if inv.expires_at is not null and inv.expires_at < now() then
    return false;
  end if;

  select id, participants
  into r
  from public.rounds
  where id = inv.round_id
  limit 1;

  if found then
    select coalesce(
      (
        select jsonb_agg(x.new_elem order by x.ord)
        from (
          select
            e.ord,
            case
              when (e.elem ? 'email')
                   and lower(trim(e.elem->>'email')) = my_email
                then e.elem || jsonb_build_object('user_id', uid::text, 'key', 'u_' || uid::text)
              else e.elem
            end as new_elem
          from jsonb_array_elements(coalesce(r.participants, '[]'::jsonb))
            with ordinality as e(elem, ord)
        ) x
      ),
      '[]'::jsonb
    ) into new_parts;

    if new_parts is distinct from coalesce(r.participants, '[]'::jsonb) then
      update public.rounds set participants = new_parts where id = r.id;
    end if;
  end if;

  update public.round_invites
  set status = 'accepted',
      accepted_at = now(),
      accepted_by_user_id = uid
  where id = inv.id;

  return true;
end;
$$;

-- ─── friend search + lookup hardening ──────────────────────────────────────

drop function if exists public.search_friend_candidates(text, int);

create or replace function public.search_friend_candidates(input_query text, input_limit int default 20)
returns table(user_id uuid, display_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  q text;
begin
  if public.current_user_is_anonymous() then
    return;
  end if;

  q := lower(trim(coalesce(input_query, '')));
  if length(q) < 3 then
    return;
  end if;

  return query
  select p.id, p.display_name
  from public.profiles p
  where p.id <> auth.uid()
    and lower(coalesce(p.display_name, '')) like '%' || public.escape_like_pattern(q) || '%' escape '\'
  order by p.display_name asc nulls last
  limit greatest(1, least(input_limit, 50));
end;
$$;

grant execute on function public.search_friend_candidates(text, int) to authenticated;

drop function if exists public.lookup_player_by_email(text);

create or replace function public.lookup_player_by_email(input_email text)
returns table(user_id uuid, display_name text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_user_is_anonymous() then
    return;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'user_id'
  ) then
    return query
    select p.user_id, p.display_name
    from public.profiles p
    where lower(p.email) = lower(trim(input_email))
    limit 1;
  else
    return query
    select p.id, p.display_name
    from public.profiles p
    where lower(p.email) = lower(trim(input_email))
    limit 1;
  end if;
end;
$$;

grant execute on function public.lookup_player_by_email(text) to authenticated;

-- ─── coplayer trigger perf: last_activity_at + round_id index ──────────────

create index if not exists round_coplayer_links_round_id_idx
  on public.round_coplayer_links (round_id);

alter table public.rounds
  add column if not exists last_activity_at timestamptz;

drop trigger if exists rounds_sync_coplayer_links on public.rounds;
do $$
declare
  update_cols text := 'created_by';
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'participants'
  ) then
    update_cols := update_cols || ', participants';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'players'
  ) then
    update_cols := update_cols || ', players';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'last_activity_at'
  ) then
    update_cols := update_cols || ', last_activity_at';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'completed_at'
  ) then
    update_cols := update_cols || ', completed_at';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'created_at'
  ) then
    update_cols := update_cols || ', created_at';
  end if;

  execute format(
    'create trigger rounds_sync_coplayer_links
     after insert or update of %s
     on public.rounds
     for each row
     execute function public.on_rounds_sync_coplayer_links()',
    update_cols
  );
end $$;

-- ─── claim_participant_identity: filtered scan ──────────────────────────────

create index if not exists rounds_participants_gin_idx
  on public.rounds using gin (participants jsonb_path_ops);

create or replace function public.claim_participant_identity_for_current_user()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  my_email text := public.current_user_verified_email();
  r record;
  new_parts jsonb;
  updated_rounds int := 0;
begin
  if uid is null then
    return 0;
  end if;

  if my_email is null or length(my_email) < 3 then
    return 0;
  end if;

  for r in
    select id, participants
    from public.rounds
    where exists (
      select 1
      from jsonb_array_elements(coalesce(participants, '[]'::jsonb)) elem
      where lower(trim(coalesce(elem->>'email', ''))) = my_email
        and (
          not elem ? 'user_id'
          or nullif(trim(elem->>'user_id'), '') is null
        )
    )
  loop
    select coalesce(
      (
        select jsonb_agg(x.new_elem order by x.ord)
        from (
          select
            e.ord,
            case
              when (e.elem ? 'email')
                   and lower(trim(e.elem->>'email')) = my_email
                   and (
                     not e.elem ? 'user_id'
                     or nullif(trim(e.elem->>'user_id'), '') is null
                   )
                then e.elem || jsonb_build_object('user_id', uid::text)
              else e.elem
            end as new_elem
          from jsonb_array_elements(coalesce(r.participants, '[]'::jsonb))
            with ordinality as e(elem, ord)
        ) x
      ),
      '[]'::jsonb
    ) into new_parts;

    if new_parts is distinct from coalesce(r.participants, '[]'::jsonb) then
      update public.rounds set participants = new_parts where id = r.id;
      updated_rounds := updated_rounds + 1;
    end if;
  end loop;

  return updated_rounds;
end;
$$;

-- ─── client_errors observability ───────────────────────────────────────────

create table if not exists public.client_errors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  message text not null,
  stack text,
  context jsonb,
  app_version text,
  url text,
  created_at timestamptz not null default now()
);

create index if not exists client_errors_created_at_idx
  on public.client_errors (created_at desc);

alter table public.client_errors enable row level security;

drop policy if exists client_errors_insert_own on public.client_errors;
create policy client_errors_insert_own
  on public.client_errors for insert
  to authenticated
  with check (user_id is null or user_id = auth.uid());

drop policy if exists client_errors_select_none on public.client_errors;
-- No select policy for clients; service role / dashboard only.
