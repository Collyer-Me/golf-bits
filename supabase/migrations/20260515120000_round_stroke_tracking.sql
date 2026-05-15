-- Optional gross stroke scorecard on rounds (alongside Bits gameplay).

alter table public.rounds
  add column if not exists stroke_tracking_mode text not null default 'off'
    check (stroke_tracking_mode in ('off', 'self', 'all'));

alter table public.rounds
  add column if not exists stroke_by_hole jsonb not null default '{}'::jsonb;

alter table public.rounds
  add column if not exists gross_by_player jsonb not null default '{}'::jsonb;

comment on column public.rounds.stroke_tracking_mode is 'off | self (organizer only) | all (every participant)';
comment on column public.rounds.stroke_by_hole is 'participant_key -> hole number string -> gross strokes';
comment on column public.rounds.gross_by_player is 'participant_key -> total gross strokes (denormalized)';
