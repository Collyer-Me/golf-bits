-- Canonical co-player links for reliable People/Recent lists.
-- Safe to re-run.

create table if not exists public.round_coplayer_links (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  round_id uuid not null references public.rounds (id) on delete cascade,
  participant_name text not null,
  participant_name_normalized text not null,
  participant_email text,
  participant_email_normalized text,
  participant_user_id uuid,
  identity_key text not null,
  played_at timestamptz not null,
  source text not null default 'participants',
  created_at timestamptz not null default now(),
  unique (owner_user_id, round_id, identity_key)
);

create index if not exists round_coplayer_links_owner_played_idx
  on public.round_coplayer_links (owner_user_id, played_at desc);

create index if not exists round_coplayer_links_owner_identity_idx
  on public.round_coplayer_links (owner_user_id, identity_key);

create index if not exists round_coplayer_links_owner_user_idx
  on public.round_coplayer_links (owner_user_id, participant_user_id)
  where participant_user_id is not null;

create index if not exists round_coplayer_links_owner_email_idx
  on public.round_coplayer_links (owner_user_id, participant_email_normalized)
  where participant_email_normalized is not null;

alter table public.round_coplayer_links enable row level security;

drop policy if exists round_coplayer_links_select_own on public.round_coplayer_links;
create policy round_coplayer_links_select_own
  on public.round_coplayer_links for select
  using (auth.uid() = owner_user_id);

drop policy if exists round_coplayer_links_insert_own on public.round_coplayer_links;
create policy round_coplayer_links_insert_own
  on public.round_coplayer_links for insert
  with check (auth.uid() = owner_user_id);

drop policy if exists round_coplayer_links_update_own on public.round_coplayer_links;
create policy round_coplayer_links_update_own
  on public.round_coplayer_links for update
  using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

drop policy if exists round_coplayer_links_delete_own on public.round_coplayer_links;
create policy round_coplayer_links_delete_own
  on public.round_coplayer_links for delete
  using (auth.uid() = owner_user_id);

create or replace function public.rebuild_round_coplayer_links_for_round(input_round_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.round_coplayer_links
  where round_id = input_round_id;

  with round_row as (
    select
      r.id as round_id,
      r.created_by as owner_user_id,
      coalesce(
        nullif(to_jsonb(r)->>'ended_at', '')::timestamptz,
        nullif(to_jsonb(r)->>'completed_at', '')::timestamptz,
        nullif(to_jsonb(r)->>'created_at', '')::timestamptz,
        now()
      ) as played_at,
      to_jsonb(r)->'participants' as participants_json,
      to_jsonb(r)->'players' as players_json,
      lower(nullif(trim(p.display_name), '')) as owner_name_normalized
    from public.rounds r
    left join public.profiles p on p.id = r.created_by
    where r.id = input_round_id
      and r.created_by is not null
  ),
  participant_cells as (
    select
      rr.round_id,
      rr.owner_user_id,
      rr.played_at,
      nullif(trim(coalesce(e.elem->>'display_name', e.elem->>'displayName', e.elem->>'name')), '') as participant_name,
      nullif(trim(coalesce(e.elem->>'email', e.elem->>'Email')), '') as participant_email,
      lower(nullif(trim(coalesce(e.elem->>'email', e.elem->>'Email')), '')) as participant_email_normalized,
      case
        when nullif(trim(coalesce(e.elem->>'user_id', e.elem->>'userId')), '') ~*
          '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
        then nullif(trim(coalesce(e.elem->>'user_id', e.elem->>'userId')), '')::uuid
        else null::uuid
      end as participant_user_id,
      coalesce(
        nullif(lower(trim(coalesce(e.elem->>'is_you', e.elem->>'isYou'))), '') = 'true',
        false
      ) as is_you,
      1 as source_rank,
      'participants'::text as source,
      rr.owner_name_normalized
    from round_row rr
    cross join lateral jsonb_array_elements(
      case
        when jsonb_typeof(rr.participants_json) = 'array' then rr.participants_json
        else '[]'::jsonb
      end
    ) as e(elem)
    union all
    select
      rr.round_id,
      rr.owner_user_id,
      rr.played_at,
      nullif(trim(x.player_name), '') as participant_name,
      null::text as participant_email,
      null::text as participant_email_normalized,
      null::uuid as participant_user_id,
      false as is_you,
      2 as source_rank,
      'players'::text as source,
      rr.owner_name_normalized
    from round_row rr
    cross join lateral jsonb_array_elements_text(
      case
        when jsonb_typeof(rr.players_json) = 'array' then rr.players_json
        else '[]'::jsonb
      end
    ) as x(player_name)
  ),
  prepared as (
    select
      c.round_id,
      c.owner_user_id,
      c.played_at,
      c.participant_name,
      lower(c.participant_name) as participant_name_normalized,
      c.participant_email,
      c.participant_email_normalized,
      c.participant_user_id,
      c.source,
      c.source_rank,
      case
        when c.participant_user_id is not null then 'u:' || c.participant_user_id::text
        when c.participant_email_normalized is not null then 'e:' || c.participant_email_normalized
        else 'n:' || lower(c.participant_name)
      end as identity_key,
      c.is_you,
      c.owner_name_normalized
    from participant_cells c
    where c.participant_name is not null
  ),
  deduped as (
    select distinct on (owner_user_id, round_id, identity_key)
      owner_user_id,
      round_id,
      participant_name,
      participant_name_normalized,
      participant_email,
      participant_email_normalized,
      participant_user_id,
      identity_key,
      played_at,
      source,
      is_you,
      owner_name_normalized
    from prepared
    order by owner_user_id, round_id, identity_key, source_rank asc
  )
  insert into public.round_coplayer_links (
    owner_user_id,
    round_id,
    participant_name,
    participant_name_normalized,
    participant_email,
    participant_email_normalized,
    participant_user_id,
    identity_key,
    played_at,
    source
  )
  select
    d.owner_user_id,
    d.round_id,
    d.participant_name,
    d.participant_name_normalized,
    d.participant_email,
    d.participant_email_normalized,
    d.participant_user_id,
    d.identity_key,
    d.played_at,
    d.source
  from deduped d
  where not d.is_you
    and (d.participant_user_id is null or d.participant_user_id <> d.owner_user_id)
    and (d.owner_name_normalized is null or d.participant_name_normalized <> d.owner_name_normalized);
end;
$$;

create or replace function public.rebuild_all_round_coplayer_links()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in select id from public.rounds loop
    perform public.rebuild_round_coplayer_links_for_round(r.id);
  end loop;
end;
$$;

create or replace function public.on_rounds_sync_coplayer_links()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.rebuild_round_coplayer_links_for_round(new.id);
  return new;
end;
$$;

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
    where table_schema = 'public' and table_name = 'rounds' and column_name = 'ended_at'
  ) then
    update_cols := update_cols || ', ended_at';
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

create or replace function public.coplayer_overview(input_limit int default 500)
returns table(
  display_name text,
  rounds_played int,
  last_played_at timestamptz,
  participant_user_id uuid,
  participant_email text
)
language sql
security definer
set search_path = public
as $$
  with base as (
    select *
    from public.round_coplayer_links
    where owner_user_id = auth.uid()
  ),
  aggregated as (
    select
      identity_key,
      count(*)::int as rounds_played,
      max(played_at) as last_played_at,
      (array_agg(participant_user_id order by played_at desc) filter (where participant_user_id is not null))[1]
        as participant_user_id,
      max(participant_email) filter (where participant_email is not null and trim(participant_email) <> '') as participant_email
    from base
    group by identity_key
  ),
  name_pick as (
    select distinct on (b.identity_key)
      b.identity_key,
      b.participant_name as display_name
    from base b
    order by b.identity_key, b.played_at desc, b.created_at desc
  )
  select
    n.display_name,
    a.rounds_played,
    a.last_played_at,
    a.participant_user_id,
    a.participant_email
  from aggregated a
  join name_pick n on n.identity_key = a.identity_key
  order by a.last_played_at desc, a.rounds_played desc, lower(n.display_name) asc
  limit greatest(1, least(input_limit, 1000));
$$;

grant execute on function public.coplayer_overview(int) to authenticated;

create or replace function public.recent_coplayers(input_limit int default 8)
returns table(display_name text, rounds_played int, last_played_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select display_name, rounds_played, last_played_at
  from public.coplayer_overview(greatest(1, least(input_limit, 1000)))
  order by last_played_at desc, rounds_played desc, lower(display_name) asc
  limit greatest(1, least(input_limit, 1000));
$$;

grant execute on function public.recent_coplayers(int) to authenticated;

revoke execute on function public.rebuild_round_coplayer_links_for_round(uuid) from public, anon, authenticated;
revoke execute on function public.rebuild_all_round_coplayer_links() from public, anon, authenticated;
revoke execute on function public.on_rounds_sync_coplayer_links() from public, anon, authenticated;

-- Backfill from historical rounds immediately.
select public.rebuild_all_round_coplayer_links();
