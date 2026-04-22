-- RLS-safe read/write helpers for profile default events.

create or replace function public.get_my_default_events()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if auth.uid() is null then
    return '[]'::jsonb;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'user_id'
  ) then
    select coalesce(p.default_events_config, '[]'::jsonb)
    into result
    from public.profiles p
    where p.user_id = auth.uid()
    limit 1;
  else
    select coalesce(p.default_events_config, '[]'::jsonb)
    into result
    from public.profiles p
    where p.id = auth.uid()
    limit 1;
  end if;

  return coalesce(result, '[]'::jsonb);
end;
$$;

grant execute on function public.get_my_default_events() to authenticated;

create or replace function public.save_my_default_events(input_config jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized jsonb := coalesce(input_config, '[]'::jsonb);
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'user_id'
  ) then
    insert into public.profiles (id, user_id, default_events_config, updated_at)
    values (auth.uid(), auth.uid(), normalized, now())
    on conflict (user_id) do update
      set id = excluded.id,
          default_events_config = excluded.default_events_config,
          updated_at = now();
  else
    insert into public.profiles (id, default_events_config, updated_at)
    values (auth.uid(), normalized, now())
    on conflict (id) do update
      set default_events_config = excluded.default_events_config,
          updated_at = now();
  end if;
end;
$$;

grant execute on function public.save_my_default_events(jsonb) to authenticated;
