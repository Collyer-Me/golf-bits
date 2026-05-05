-- Fill participants[].user_id on saved rounds where email matches the caller's profile email.
-- SECURITY DEFINER: updates rounds the user does not own (they appear only as email in JSON).

create or replace function public.claim_participant_identity_for_current_user()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  my_email text;
  r record;
  new_parts jsonb;
  updated_rounds int := 0;
begin
  if uid is null then
    return 0;
  end if;

  select lower(trim(coalesce(p.email, ''))) into my_email
  from public.profiles p
  where p.id = uid;

  if length(my_email) < 3 then
    return 0;
  end if;

  for r in
    select id, participants
    from public.rounds
  loop
    select coalesce(
      (
        select jsonb_agg(x.new_elem order by x.ord)
        from (
          select
            e.ord,
            case
              when (e.elem ? 'email')
                   and lower(trim(e.elem->>'email')) = my_email
                   and (
                     not e.elem ? 'user_id'
                     or nullif(trim(e.elem->>'user_id'), '') is null
                   )
                then e.elem || jsonb_build_object('user_id', uid::text)
              else e.elem
            end as new_elem
          from jsonb_array_elements(coalesce(r.participants, '[]'::jsonb))
            with ordinality as e(elem, ord)
        ) x
      ),
      '[]'::jsonb
    ) into new_parts;

    if new_parts is distinct from coalesce(r.participants, '[]'::jsonb) then
      update public.rounds set participants = new_parts where id = r.id;
      updated_rounds := updated_rounds + 1;
    end if;
  end loop;

  return updated_rounds;
end;
$$;

grant execute on function public.claim_participant_identity_for_current_user() to authenticated;
