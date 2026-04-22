import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: userErr,
  } = await userClient.auth.getUser();
  if (userErr || !user) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  let body: { courseId?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON' }, 400);
  }

  const courseId = body.courseId?.trim();
  if (!courseId) {
    return jsonResponse({ error: 'courseId required' }, 400);
  }

  const { data: course, error: cErr } = await userClient
    .from('courses')
    .select(
      'id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1,source,external_ids',
    )
    .eq('id', courseId)
    .maybeSingle();

  if (cErr) {
    return jsonResponse({ error: cErr.message }, 500);
  }
  if (!course) {
    await userClient.from('course_data_telemetry').insert({
      user_id: user.id,
      kind: 'course_detail_miss',
      payload: { courseId },
    });
    return jsonResponse({ error: 'Not found' }, 404);
  }

  const { data: teeRows, error: tErr } = await userClient
    .from('course_tees')
    .select(
      'id,sort_order,label,color_hint,course_rating,slope_rating,ratings_json,course_tee_holes(hole_number,par,stroke_index,yardage_yds)',
    )
    .eq('course_id', courseId)
    .order('sort_order', { ascending: true });

  if (tErr) {
    return jsonResponse({ error: tErr.message }, 500);
  }

  const teeList = teeRows ?? [];
  let holeRowCount = 0;

  const teesOut = teeList.map((t) => {
    const rawHoles = (t.course_tee_holes as Record<string, unknown>[] | null) ?? [];
    const holes = [...rawHoles]
      .map((h) => ({
        holeNumber: (h.hole_number as number),
        par: (h.par as number),
        strokeIndex: h.stroke_index == null ? null : (h.stroke_index as number),
        yardageYds: h.yardage_yds == null ? null : (h.yardage_yds as number),
      }))
      .sort((a, b) => a.holeNumber - b.holeNumber);
    holeRowCount += holes.length;
    return {
      id: t.id,
      sortOrder: t.sort_order,
      label: t.label,
      colorHint: t.color_hint,
      courseRating: t.course_rating,
      slopeRating: t.slope_rating,
      ratings: t.ratings_json ?? {},
      holes,
    };
  });

  await userClient.from('course_data_telemetry').insert({
    user_id: user.id,
    kind: 'cache_hit',
    payload: { courseId, teeCount: teeList.length, teeHoleRowCount: holeRowCount },
  });

  return jsonResponse({
    course: {
      id: course.id,
      name: course.name,
      subtitle: course.subtitle,
      coverageLevel: course.coverage_level,
      latitude: course.latitude,
      longitude: course.longitude,
      source: course.source,
      externalIds: course.external_ids ?? {},
      address: {
        street: course.street_line1,
        locality: course.locality,
        region: course.region,
        countryCode: course.country_code,
      },
    },
    tees: teesOut,
  });
});
