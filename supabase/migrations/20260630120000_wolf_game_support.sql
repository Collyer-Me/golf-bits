-- Wolf game format: dual ledgers, handicaps, per-hole Wolf state.

alter table public.profiles
  add column if not exists handicap smallint;

alter table public.rounds
  add column if not exists round_formats jsonb default '["bits"]'::jsonb,
  add column if not exists game_config jsonb,
  add column if not exists wolf_hole_results jsonb,
  add column if not exists wolf_points_by_player jsonb,
  add column if not exists hole_stroke_indexes jsonb,
  add column if not exists hole_yardages jsonb,
  add column if not exists wolf_hole_phase text,
  add column if not exists start_hole smallint default 1;

comment on column public.rounds.round_formats is 'Active formats: ["bits"], ["wolf"], or ["wolf","bits"]';
comment on column public.rounds.wolf_hole_phase is 'In-round Wolf UI phase: call | score';
