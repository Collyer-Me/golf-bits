-- Realistic stroke-index ranks for demo seed courses (SI ≠ hole number).
update public.course_tee_holes cth
set stroke_index = v.si
from public.course_tees ct
join (
  values
    (1, 11),
    (2, 7),
    (3, 3),
    (4, 15),
    (5, 1),
    (6, 13),
    (7, 9),
    (8, 17),
    (9, 5),
    (10, 12),
    (11, 8),
    (12, 2),
    (13, 14),
    (14, 18),
    (15, 4),
    (16, 16),
    (17, 6),
    (18, 10)
) as v(hole_number, si) on true
where ct.id = cth.course_tee_id
  and cth.hole_number = v.hole_number
  and ct.course_id in (
    'b1111111-1111-4111-8111-111111111101'::uuid,
    'b1111111-1111-4111-8111-111111111102'::uuid,
    'b1111111-1111-4111-8111-111111111103'::uuid
  );
