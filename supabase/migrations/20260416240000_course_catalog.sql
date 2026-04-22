-- Course catalog: normalized courses, tees, holes, optional provider cache, telemetry.
-- Hybrid model: public seed + OSM-backed rows (service role) + user-private manual courses.

-- ─── courses ───────────────────────────────────────────────────────────────
create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  subtitle text,
  latitude double precision,
  longitude double precision,
  street_line1 text,
  locality text,
  region text,
  postal_code text,
  country_code text,
  coverage_level text not null
    check (coverage_level in ('geo_only', 'partial_scorecard', 'full_scorecard', 'manual')),
  source text not null
    check (source in ('seed', 'osm', 'user', 'provider')),
  owner_user_id uuid references auth.users (id) on delete cascade,
  visibility text not null default 'public'
    check (visibility in ('public', 'private')),
  external_ids jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint courses_owner_private_ck check (
    (visibility = 'public' and owner_user_id is null)
    or (visibility = 'private' and owner_user_id is not null)
  )
);

create index if not exists courses_name_lower_idx on public.courses (lower(name));
create index if not exists courses_locality_lower_idx on public.courses (lower(locality));
create index if not exists courses_visibility_owner_idx
  on public.courses (visibility, owner_user_id);

create unique index if not exists courses_external_osm_uidx
  on public.courses ((external_ids ->> 'osm'))
  where source = 'osm' and (external_ids ->> 'osm') is not null;

-- ─── course_tees ───────────────────────────────────────────────────────────
create table if not exists public.course_tees (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  sort_order int not null default 0,
  label text not null,
  color_hint text,
  course_rating numeric(5, 1),
  slope_rating smallint,
  ratings_json jsonb not null default '{}'::jsonb
);

create index if not exists course_tees_course_sort_idx
  on public.course_tees (course_id, sort_order);

-- ─── course_holes (course-level par / stroke index) ────────────────────────
create table if not exists public.course_holes (
  course_id uuid not null references public.courses (id) on delete cascade,
  hole_number smallint not null check (hole_number >= 1 and hole_number <= 18),
  par smallint not null check (par >= 3 and par <= 6),
  stroke_index smallint check (stroke_index is null or (stroke_index >= 1 and stroke_index <= 18)),
  primary key (course_id, hole_number)
);

-- ─── course_tee_holes (yardage per tee / hole) ──────────────────────────────
create table if not exists public.course_tee_holes (
  course_tee_id uuid not null references public.course_tees (id) on delete cascade,
  hole_number smallint not null check (hole_number >= 1 and hole_number <= 18),
  yardage_yds int check (yardage_yds is null or (yardage_yds > 0 and yardage_yds < 900)),
  primary key (course_tee_id, hole_number)
);

-- ─── Provider payload mirror (Edge Functions / service role only) ──────────
create table if not exists public.course_provider_cache (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  external_course_id text not null,
  payload jsonb not null,
  fetched_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (provider, external_course_id)
);

-- ─── Lightweight telemetry (authenticated inserts only) ─────────────────────
create table if not exists public.course_data_telemetry (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists course_data_telemetry_user_created_idx
  on public.course_data_telemetry (user_id, created_at desc);

-- ─── rounds: link to catalog + coverage snapshot ─────────────────────────────
alter table public.rounds add column if not exists course_catalog_id uuid references public.courses (id);
alter table public.rounds add column if not exists course_coverage_level text;
alter table public.rounds add column if not exists hole_pars jsonb;

create index if not exists rounds_course_catalog_id_idx on public.rounds (course_catalog_id);

-- Table privileges (RLS still enforces row access).
grant select, insert, update, delete on public.courses to authenticated;
grant select on public.course_tees to authenticated;
grant select on public.course_holes to authenticated;
grant select on public.course_tee_holes to authenticated;
grant insert, select on public.course_data_telemetry to authenticated;

-- ─── RLS: courses ───────────────────────────────────────────────────────────
alter table public.courses enable row level security;

drop policy if exists "courses_select_visible" on public.courses;
create policy "courses_select_visible"
  on public.courses for select to authenticated
  using (
    visibility = 'public'
    or owner_user_id = auth.uid()
  );

drop policy if exists "courses_insert_private_manual" on public.courses;
create policy "courses_insert_private_manual"
  on public.courses for insert to authenticated
  with check (
    owner_user_id = auth.uid()
    and visibility = 'private'
    and source = 'user'
    and coverage_level = 'manual'
  );

drop policy if exists "courses_update_own_private" on public.courses;
create policy "courses_update_own_private"
  on public.courses for update to authenticated
  using (owner_user_id = auth.uid() and visibility = 'private')
  with check (owner_user_id = auth.uid() and visibility = 'private');

drop policy if exists "courses_delete_own_private" on public.courses;
create policy "courses_delete_own_private"
  on public.courses for delete to authenticated
  using (owner_user_id = auth.uid() and visibility = 'private');

-- ─── RLS: children follow parent visibility ─────────────────────────────────
alter table public.course_tees enable row level security;
drop policy if exists "course_tees_select" on public.course_tees;
create policy "course_tees_select"
  on public.course_tees for select to authenticated
  using (
    exists (
      select 1 from public.courses c
      where c.id = course_tees.course_id
        and (c.visibility = 'public' or c.owner_user_id = auth.uid())
    )
  );

alter table public.course_holes enable row level security;
drop policy if exists "course_holes_select" on public.course_holes;
create policy "course_holes_select"
  on public.course_holes for select to authenticated
  using (
    exists (
      select 1 from public.courses c
      where c.id = course_holes.course_id
        and (c.visibility = 'public' or c.owner_user_id = auth.uid())
    )
  );

alter table public.course_tee_holes enable row level security;
drop policy if exists "course_tee_holes_select" on public.course_tee_holes;
create policy "course_tee_holes_select"
  on public.course_tee_holes for select to authenticated
  using (
    exists (
      select 1
      from public.course_tees t
      join public.courses c on c.id = t.course_id
      where t.id = course_tee_holes.course_tee_id
        and (c.visibility = 'public' or c.owner_user_id = auth.uid())
    )
  );

-- Provider cache: no authenticated policies (service role bypasses RLS).
alter table public.course_provider_cache enable row level security;

alter table public.course_data_telemetry enable row level security;
drop policy if exists "course_data_telemetry_insert_own" on public.course_data_telemetry;
create policy "course_data_telemetry_insert_own"
  on public.course_data_telemetry for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "course_data_telemetry_select_own" on public.course_data_telemetry;
create policy "course_data_telemetry_select_own"
  on public.course_data_telemetry for select to authenticated
  using (user_id = auth.uid());

-- ─── Seed: three Australian demo courses (synthetic yardages / ratings) ─────
insert into public.courses (
  id, name, subtitle, latitude, longitude, locality, region, country_code,
  coverage_level, source, owner_user_id, visibility, external_ids
)
values
  (
    'b1111111-1111-4111-8111-111111111101'::uuid,
    'Royal Melbourne Golf Club',
    'Black Rock, VIC',
    -37.9750, 145.0200,
    'Black Rock', 'Victoria', 'AU',
    'full_scorecard', 'seed', null, 'public',
    '{"seed_key":"royal_melbourne"}'::jsonb
  ),
  (
    'b1111111-1111-4111-8111-111111111102'::uuid,
    'Royal Sydney Golf Club',
    'Rose Bay, NSW',
    -33.8700, 151.2650,
    'Rose Bay', 'New South Wales', 'AU',
    'full_scorecard', 'seed', null, 'public',
    '{"seed_key":"royal_sydney"}'::jsonb
  ),
  (
    'b1111111-1111-4111-8111-111111111103'::uuid,
    'Royal Queensland Golf Club',
    'Eagle Farm, QLD',
    -27.4250, 153.0800,
    'Eagle Farm', 'Queensland', 'AU',
    'full_scorecard', 'seed', null, 'public',
    '{"seed_key":"royal_queensland"}'::jsonb
  )
on conflict (id) do nothing;

-- Tees per course (stable UUIDs for reference / tests)
insert into public.course_tees (id, course_id, sort_order, label, color_hint, course_rating, slope_rating, ratings_json)
values
  ('c2111111-1111-4111-8111-111111111101'::uuid, 'b1111111-1111-4111-8111-111111111101'::uuid, 0, 'CHAMP', 'black', 73.2, 142,
    '{"men":{"rating":73.2,"slope":142},"women":{"rating":75.0,"slope":148}}'::jsonb),
  ('c2111111-1111-4111-8111-111111111102'::uuid, 'b1111111-1111-4111-8111-111111111101'::uuid, 1, 'WHITE', 'white', 70.1, 128,
    '{"men":{"rating":70.1,"slope":128},"women":{"rating":72.0,"slope":134}}'::jsonb),
  ('c2111111-1111-4111-8111-111111111103'::uuid, 'b1111111-1111-4111-8111-111111111101'::uuid, 2, 'RED', 'red', 66.8, 118,
    '{"men":{"rating":66.8,"slope":118},"women":{"rating":68.5,"slope":124}}'::jsonb),
  ('c2111111-1111-4111-8111-111111112101'::uuid, 'b1111111-1111-4111-8111-111111111102'::uuid, 0, 'CHAMP', 'black', 72.8, 138,
    '{"men":{"rating":72.8,"slope":138},"women":{"rating":74.5,"slope":144}}'::jsonb),
  ('c2111111-1111-4111-8111-111111112102'::uuid, 'b1111111-1111-4111-8111-111111111102'::uuid, 1, 'WHITE', 'white', 69.4, 126,
    '{"men":{"rating":69.4,"slope":126},"women":{"rating":71.0,"slope":132}}'::jsonb),
  ('c2111111-1111-4111-8111-111111112103'::uuid, 'b1111111-1111-4111-8111-111111111102'::uuid, 2, 'RED', 'red', 66.2, 116,
    '{"men":{"rating":66.2,"slope":116},"women":{"rating":67.8,"slope":122}}'::jsonb),
  ('c2111111-1111-4111-8111-111111113101'::uuid, 'b1111111-1111-4111-8111-111111111103'::uuid, 0, 'CHAMP', 'black', 72.5, 136,
    '{"men":{"rating":72.5,"slope":136},"women":{"rating":74.0,"slope":142}}'::jsonb),
  ('c2111111-1111-4111-8111-111111113102'::uuid, 'b1111111-1111-4111-8111-111111111103'::uuid, 1, 'WHITE', 'white', 69.0, 124,
    '{"men":{"rating":69.0,"slope":124},"women":{"rating":70.6,"slope":130}}'::jsonb),
  ('c2111111-1111-4111-8111-111111113103'::uuid, 'b1111111-1111-4111-8111-111111111103'::uuid, 2, 'RED', 'red', 65.9, 114,
    '{"men":{"rating":65.9,"slope":114},"women":{"rating":67.4,"slope":120}}'::jsonb)
on conflict (id) do nothing;

-- Holes: same par template for all three seeds (72 total)
insert into public.course_holes (course_id, hole_number, par, stroke_index)
select c.id, h.n,
  (array[4,5,3,4,4,4,3,4,5,4,4,3,5,4,3,4,4,5])[h.n],
  h.n
from (values
  ('b1111111-1111-4111-8111-111111111101'::uuid),
  ('b1111111-1111-4111-8111-111111111102'::uuid),
  ('b1111111-1111-4111-8111-111111111103'::uuid)
) as c(id)
cross join lateral generate_series(1, 18) as h(n)
on conflict (course_id, hole_number) do nothing;

-- Yardages: deterministic offsets per course + tee tier
insert into public.course_tee_holes (course_tee_id, hole_number, yardage_yds)
select t.id,
  h.n,
  greatest(
    120,
    310 + (h.n * 11)
      + (t.sort_order * 18)
      + case c.idx when 1 then 0 when 2 then 6 else 12 end
      + ((h.n + t.sort_order) % 5) * 7
  )
from (
  values
    (1, 'c2111111-1111-4111-8111-111111111101'::uuid),
    (1, 'c2111111-1111-4111-8111-111111111102'::uuid),
    (1, 'c2111111-1111-4111-8111-111111111103'::uuid),
    (2, 'c2111111-1111-4111-8111-111111112101'::uuid),
    (2, 'c2111111-1111-4111-8111-111111112102'::uuid),
    (2, 'c2111111-1111-4111-8111-111111112103'::uuid),
    (3, 'c2111111-1111-4111-8111-111111113101'::uuid),
    (3, 'c2111111-1111-4111-8111-111111113102'::uuid),
    (3, 'c2111111-1111-4111-8111-111111113103'::uuid)
) as c(idx, id)
join public.course_tees t on t.id = c.id
cross join lateral generate_series(1, 18) as h(n)
on conflict (course_tee_id, hole_number) do nothing;
