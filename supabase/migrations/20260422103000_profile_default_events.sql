-- User-level default round event settings (built-ins + custom events).
alter table public.profiles
  add column if not exists default_events_config jsonb not null default '[]'::jsonb;
