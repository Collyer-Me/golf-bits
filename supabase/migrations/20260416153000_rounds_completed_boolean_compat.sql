-- App + repo expect a boolean `public.rounds.completed`. Some projects only have `completed_at`.
-- Safe to re-run.

alter table public.rounds add column if not exists completed boolean;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rounds'
      and column_name = 'completed_at'
  ) then
    update public.rounds
    set completed = (completed_at is not null)
    where completed is null;
  end if;
end $$;

update public.rounds set completed = true where completed is null;

alter table public.rounds alter column completed set default true;
