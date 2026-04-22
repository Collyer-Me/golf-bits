-- Friends graph + helper RPCs for search and list.

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null references auth.users (id) on delete cascade,
  addressee_user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending',
  acted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  responded_at timestamptz
);

alter table public.friendships
  add constraint friendships_status_ck
  check (status in ('pending', 'accepted', 'declined', 'blocked'));

alter table public.friendships
  add constraint friendships_distinct_users_ck
  check (requester_user_id <> addressee_user_id);

create unique index if not exists friendships_pair_unique_idx
  on public.friendships (least(requester_user_id, addressee_user_id), greatest(requester_user_id, addressee_user_id));

create index if not exists friendships_requester_status_idx
  on public.friendships (requester_user_id, status, created_at desc);

create index if not exists friendships_addressee_status_idx
  on public.friendships (addressee_user_id, status, created_at desc);

alter table public.friendships enable row level security;

drop policy if exists friendships_select_own on public.friendships;
create policy friendships_select_own
  on public.friendships for select
  using (auth.uid() = requester_user_id or auth.uid() = addressee_user_id);

drop policy if exists friendships_insert_requester on public.friendships;
create policy friendships_insert_requester
  on public.friendships for insert
  with check (auth.uid() = requester_user_id and status = 'pending');

drop policy if exists friendships_update_participant on public.friendships;
create policy friendships_update_participant
  on public.friendships for update
  using (auth.uid() = requester_user_id or auth.uid() = addressee_user_id)
  with check (auth.uid() = requester_user_id or auth.uid() = addressee_user_id);

drop policy if exists friendships_delete_participant on public.friendships;
create policy friendships_delete_participant
  on public.friendships for delete
  using (auth.uid() = requester_user_id or auth.uid() = addressee_user_id);

create or replace function public.set_friendships_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists friendships_updated_at on public.friendships;
create trigger friendships_updated_at
before update on public.friendships
for each row execute function public.set_friendships_updated_at();

create or replace function public.search_friend_candidates(input_query text, input_limit int default 20)
returns table(user_id uuid, display_name text, email text)
language sql
security definer
set search_path = public
as $$
  select p.id, p.display_name, p.email
  from public.profiles p
  where p.id <> auth.uid()
    and length(trim(coalesce(input_query, ''))) >= 2
    and (
      lower(coalesce(p.display_name, '')) like '%' || lower(trim(input_query)) || '%'
      or lower(coalesce(p.email, '')) like '%' || lower(trim(input_query)) || '%'
    )
  order by p.display_name asc nulls last
  limit greatest(1, least(input_limit, 50));
$$;

grant execute on function public.search_friend_candidates(text, int) to authenticated;

create or replace function public.friend_overview()
returns table(
  friendship_id uuid,
  status text,
  requester_user_id uuid,
  addressee_user_id uuid,
  other_user_id uuid,
  other_display_name text,
  other_email text,
  created_at timestamptz,
  responded_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    f.id as friendship_id,
    f.status,
    f.requester_user_id,
    f.addressee_user_id,
    case when f.requester_user_id = auth.uid() then f.addressee_user_id else f.requester_user_id end as other_user_id,
    p.display_name as other_display_name,
    p.email as other_email,
    f.created_at,
    f.responded_at
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_user_id = auth.uid() then f.addressee_user_id else f.requester_user_id end
  where auth.uid() in (f.requester_user_id, f.addressee_user_id)
  order by f.updated_at desc, f.created_at desc;
$$;

grant execute on function public.friend_overview() to authenticated;
