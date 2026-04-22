-- Store par + stroke index per tee per hole (supports different par by tee box).
-- Drops course_holes after backfilling into course_tee_holes.

alter table public.course_tee_holes
  add column if not exists par smallint,
  add column if not exists stroke_index smallint;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'course_holes'
  ) then
    -- Target alias `cth` must not appear inside JOIN ON here (PostgreSQL 42P01).
    update public.course_tee_holes cth
    set
      par = ch.par,
      stroke_index = ch.stroke_index
    from public.course_tees ct
    inner join public.course_holes ch
      on ch.course_id = ct.course_id
    where ct.id = cth.course_tee_id
      and ch.hole_number = cth.hole_number;
  end if;
end $$;

-- Safe default if a row had no course_holes source (should be rare).
update public.course_tee_holes
set par = 4
where par is null;

alter table public.course_tee_holes
  alter column par set not null;

do $$
begin
  alter table public.course_tee_holes
    add constraint course_tee_holes_par_ck check (par >= 3 and par <= 6);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table public.course_tee_holes
    add constraint course_tee_holes_stroke_index_ck
      check (stroke_index is null or (stroke_index >= 1 and stroke_index <= 18));
exception
  when duplicate_object then null;
end $$;

-- Remove course-level hole table (policies drop with the table).
drop table if exists public.course_holes cascade;
