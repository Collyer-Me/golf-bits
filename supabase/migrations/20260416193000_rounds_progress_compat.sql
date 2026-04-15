-- In-progress round resume support.
-- Safe to re-run.

alter table public.rounds add column if not exists completed_at timestamptz;
alter table public.rounds add column if not exists current_hole int;
alter table public.rounds add column if not exists score_by_player jsonb;

update public.rounds
set completed_at = coalesce(completed_at, ended_at)
where completed_at is null and coalesce(completed, true) = true;

update public.rounds
set current_hole = coalesce(current_hole, 1)
where current_hole is null;

update public.rounds
set score_by_player = coalesce(score_by_player, '{}'::jsonb)
where score_by_player is null;

alter table public.rounds alter column current_hole set default 1;
alter table public.rounds alter column score_by_player set default '{}'::jsonb;
