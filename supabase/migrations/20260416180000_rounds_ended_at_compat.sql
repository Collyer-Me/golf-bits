-- App expects `ended_at` for ordering and display. Some `rounds` tables omit it.
-- Safe to re-run.

alter table public.rounds add column if not exists ended_at timestamptz;

update public.rounds
set ended_at = coalesce(
  ended_at,
  completed_at,
  created_at,
  now()
)
where ended_at is null;

alter table public.rounds alter column ended_at set default now();
