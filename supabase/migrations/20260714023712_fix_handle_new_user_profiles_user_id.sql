-- Live profiles PK is user_id (NOT NULL). The pre-beta handle_new_user rewrite
-- only inserted (id, display_name, email) and used ON CONFLICT (id), so every
-- new auth user failed with: null value in column "user_id" violates not-null.
-- That surfaced in the app as: Database error creating anonymous user.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, user_id, display_name, email)
  values (
    new.id,
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Player'
    ),
    new.email
  )
  on conflict (user_id) do update
    set id = excluded.id,
        display_name = excluded.display_name,
        email = excluded.email,
        updated_at = now();
  return new;
end;
$$;
