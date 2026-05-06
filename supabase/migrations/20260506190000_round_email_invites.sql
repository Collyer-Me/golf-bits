-- Phase 2: round email invites + invite token claim path.
-- Safe to re-run.

create table if not exists public.round_invites (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.rounds(id) on delete cascade,
  invited_email text not null,
  invited_name text,
  invited_by_user_id uuid references auth.users(id) on delete set null,
  token text not null unique,
  status text not null default 'pending' check (status in ('pending', 'sent', 'accepted', 'failed')),
  invite_url text,
  sent_at timestamptz,
  accepted_at timestamptz,
  accepted_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists round_invites_round_idx on public.round_invites(round_id);
create index if not exists round_invites_email_idx on public.round_invites(lower(invited_email));
create index if not exists round_invites_status_idx on public.round_invites(status);

create or replace function public.touch_round_invites_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_round_invites_updated_at on public.round_invites;
create trigger trg_round_invites_updated_at
before update on public.round_invites
for each row execute function public.touch_round_invites_updated_at();

alter table public.round_invites enable row level security;

drop policy if exists "round_invites_select_own_or_invited" on public.round_invites;
create policy "round_invites_select_own_or_invited"
on public.round_invites
for select
to authenticated
using (
  invited_by_user_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(trim(coalesce(p.email, ''))) = lower(trim(public.round_invites.invited_email))
  )
);

drop policy if exists "round_invites_update_owner" on public.round_invites;
create policy "round_invites_update_owner"
on public.round_invites
for update
to authenticated
using (invited_by_user_id = auth.uid())
with check (invited_by_user_id = auth.uid());

drop policy if exists "round_invites_insert_owner" on public.round_invites;
create policy "round_invites_insert_owner"
on public.round_invites
for insert
to authenticated
with check (invited_by_user_id = auth.uid());

-- Claim invite token and link participants for the current authenticated user.
create or replace function public.accept_round_invite_for_current_user(invite_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  my_email text;
  inv record;
  r record;
  new_parts jsonb;
begin
  if uid is null or invite_token is null or length(trim(invite_token)) < 12 then
    return false;
  end if;

  select lower(trim(coalesce(p.email, ''))) into my_email
  from public.profiles p
  where p.id = uid;

  if length(my_email) < 3 then
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

grant execute on function public.accept_round_invite_for_current_user(text) to authenticated;
