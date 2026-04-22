import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

// Inlined for single-file deploy (Dashboard paste); keep in sync with get-course-detail.
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

type NomItem = {
  lat: string;
  lon: string;
  display_name?: string;
  osm_type?: string;
  osm_id?: number;
  place_id?: number;
  address?: Record<string, string>;
};

type GcaSearchRow = Record<string, unknown>;
type GcaDetail = Record<string, unknown>;
type TeeHole = {
  holeNumber: number;
  par: number;
  strokeIndex: number | null;
  yardageYds: number | null;
};
type TeePayload = {
  label: string;
  colorHint: string | null;
  courseRating: number | null;
  slopeRating: number | null;
  ratings: Record<string, unknown>;
  holes: TeeHole[];
};
type NormalizedCourse = {
  externalCourseId: string;
  name: string;
  subtitle: string | null;
  latitude: number | null;
  longitude: number | null;
  locality: string | null;
  region: string | null;
  postalCode: string | null;
  countryCode: string | null;
  tees: TeePayload[];
  raw: Record<string, unknown>;
};

const countryNameToIso2: Record<string, string> = {
  australia: 'AU',
  'united states': 'US',
  usa: 'US',
  'new zealand': 'NZ',
  canada: 'CA',
  england: 'GB',
  uk: 'GB',
  'united kingdom': 'GB',
  scotland: 'GB',
  ireland: 'IE',
};

function sanitizeIlike(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_').replace(/,/g, ' ');
}

function toCourseRow(r: Record<string, unknown>) {
  const cov = (r.coverage_level ?? r.coverageLevel) as string;
  return {
    id: r.id as string,
    name: r.name as string,
    subtitle: (r.subtitle as string | null) ?? null,
    coverageLevel: cov,
    latitude: (r.latitude as number | null) ?? null,
    longitude: (r.longitude as number | null) ?? null,
    address: {
      street: (r.street_line1 as string | null) ?? null,
      locality: (r.locality as string | null) ?? null,
      region: (r.region as string | null) ?? null,
      countryCode: (r.country_code as string | null) ?? null,
    },
  };
}

function asNum(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

function asObj(v: unknown): Record<string, unknown> | null {
  if (v && typeof v === 'object' && !Array.isArray(v)) return v as Record<string, unknown>;
  return null;
}

function asArr(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

function asStr(v: unknown): string | null {
  if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t.length === 0 ? null : t;
}

function firstStr(...vals: unknown[]): string | null {
  for (const v of vals) {
    const s = asStr(v);
    if (s) return s;
  }
  return null;
}

function jwtRole(token: string): string | null {
  const parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
    const json = atob(padded);
    const payload = JSON.parse(json) as Record<string, unknown>;
    const role = payload.role;
    return typeof role === 'string' ? role : null;
  } catch {
    return null;
  }
}

function normalizeCountryCode(countryCode: string | null, countryName: string | null): string | null {
  if (countryCode && countryCode.length >= 2) return countryCode.slice(0, 2).toUpperCase();
  if (!countryName) return null;
  return countryNameToIso2[countryName.trim().toLowerCase()] ?? null;
}

function normalizeHoles(rawHoles: unknown[]): TeeHole[] {
  const rows: TeeHole[] = [];
  for (let i = 0; i < rawHoles.length; i++) {
    const holeRaw = rawHoles[i];
    const h = asObj(holeRaw);
    if (!h) continue;
    const holeNumber = asNum(h.hole_number ?? h.hole ?? h.number ?? h.index) ?? (i + 1);
    const par = asNum(h.par);
    if (!holeNumber || !par) continue;
    const ydsDirect = asNum(h.yards ?? h.yardage ?? h.yardage_yds ?? h.length_yards);
    const meters = asNum(h.meters ?? h.length_meters ?? h.yardage_m);
    const yardageYds = ydsDirect ?? (meters == null ? null : Math.round(meters / 0.9144));
    const strokeRaw = asNum(h.handicap ?? h.stroke_index ?? h.hcp);
    rows.push({
      holeNumber: Math.trunc(holeNumber),
      par: Math.trunc(par),
      strokeIndex: strokeRaw == null ? null : Math.trunc(strokeRaw),
      yardageYds: yardageYds == null ? null : Math.trunc(yardageYds),
    });
  }
  rows.sort((a, b) => a.holeNumber - b.holeNumber);
  return rows;
}

function normalizeTees(detail: GcaDetail): TeePayload[] {
  const teesObj = asObj(detail.tees);
  const teesFromSpecObj = teesObj
    ? [...asArr(teesObj.female), ...asArr(teesObj.male)]
    : [];
  const topLevel = asArr(detail.tees ?? detail.tee_boxes ?? detail.teeBoxes);
  const fromGroups: unknown[] = [];
  for (const groupKey of ['male_tees', 'female_tees', 'men_tees', 'women_tees']) {
    const g = asArr(detail[groupKey]);
    fromGroups.push(...g);
  }
  const source = topLevel.length > 0
    ? topLevel
    : (teesFromSpecObj.length > 0 ? teesFromSpecObj : fromGroups);
  const tees: TeePayload[] = [];
  for (const tr of source) {
    const tee = asObj(tr);
    if (!tee) continue;
    const label = firstStr(tee.tee_name, tee.name, tee.color, tee.label, tee.title) ?? 'TEE';
    const holes = normalizeHoles(asArr(tee.holes ?? tee.hole_data ?? tee.holeData));
    tees.push({
      label,
      colorHint: firstStr(tee.color, tee.tee_color),
      courseRating: asNum(tee.course_rating ?? tee.rating),
      slopeRating: asNum(tee.slope_rating ?? tee.slope),
      ratings: {},
      holes,
    });
  }
  return tees.filter((t) => t.holes.length > 0);
}

function coverageFromTees(tees: TeePayload[]): string {
  if (tees.length === 0) return 'geo_only';
  const totalHoles = tees.reduce((sum, t) => sum + t.holes.length, 0);
  const hasMostlyFullTees = tees.some((t) => t.holes.length >= 18);
  if (hasMostlyFullTees && totalHoles >= tees.length * 12) return 'full_scorecard';
  return 'partial_scorecard';
}

async function gcaFetchJson(url: string, apiKey: string): Promise<unknown> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    Authorization: `Key ${apiKey}`,
  };
  const res = await fetch(url, { headers });
  if (!res.ok) return null;
  return await res.json();
}

function searchVariants(input: string): string[] {
  const q = input.trim();
  if (q.length === 0) return [];
  const variants = [
    q,
    `${q} golf`,
    `${q} golf club`,
  ];
  if (q.toLowerCase().startsWith('the ')) {
    variants.push(q.slice(4));
  }
  return [...new Set(variants.map((v) => v.trim()).filter((v) => v.length > 0))];
}

async function fetchGcaSearchRows(
  baseUrl: string,
  apiKey: string,
  query: string,
): Promise<{ rows: GcaSearchRow[]; tried: string[] }> {
  const bases = [baseUrl, baseUrl.replace(/\/v1\/?$/, ''), baseUrl.replace(/\/api\/?$/, '')]
    .map((x) => x.replace(/\/$/, ''));
  const paths = [
    (b: string, q: string) => `${b}/v1/search?search_query=${encodeURIComponent(q)}`,
    (b: string, q: string) => `${b}/search?search_query=${encodeURIComponent(q)}`,
  ];
  const tried: string[] = [];
  const byId = new Map<string, GcaSearchRow>();
  for (const q of searchVariants(query)) {
    tried.push(q);
    for (const b of bases) {
      for (const p of paths) {
        const json = await gcaFetchJson(p(b, q), apiKey);
        if (!json) continue;
        const arr = asArr((json as Record<string, unknown>).courses ?? (json as Record<string, unknown>).data ?? json);
        for (const r of arr) {
          const row = asObj(r);
          if (!row) continue;
          const id = firstStr(row.id);
          if (!id) continue;
          if (!byId.has(id)) byId.set(id, row);
        }
      }
    }
  }
  return { rows: [...byId.values()], tried };
}

async function fetchGcaCourseDetail(baseUrl: string, apiKey: string, id: string): Promise<GcaDetail | null> {
  const bases = [baseUrl, baseUrl.replace(/\/v1\/?$/, ''), baseUrl.replace(/\/api\/?$/, '')]
    .map((x) => x.replace(/\/$/, ''));
  const paths = [
    (b: string) => `${b}/v1/courses/${encodeURIComponent(id)}`,
    (b: string) => `${b}/courses/${encodeURIComponent(id)}`,
  ];
  for (const b of bases) {
    for (const p of paths) {
      const json = await gcaFetchJson(p(b), apiKey);
      if (!json) continue;
      const obj = asObj((json as Record<string, unknown>).course ?? (json as Record<string, unknown>).data ?? json);
      if (obj) return obj;
    }
  }
  return null;
}

function normalizeFromGca(searchRow: GcaSearchRow, detail: GcaDetail): NormalizedCourse | null {
  const externalCourseId = firstStr(searchRow.id, detail.id);
  if (!externalCourseId) return null;
  const courseName = firstStr(detail.course_name, detail.name, searchRow.course_name, searchRow.name);
  const clubName = firstStr(detail.club_name, searchRow.club_name);
  const locationObj = asObj(detail.location) ?? asObj(searchRow.location) ?? {};
  const locality = firstStr(locationObj.city, detail.city);
  const region = firstStr(locationObj.state, detail.state);
  const countryName = firstStr(locationObj.country, detail.country);
  const countryCode = normalizeCountryCode(
    firstStr(locationObj.country_code),
    countryName,
  );
  const name = [clubName, courseName].filter(Boolean).join(' - ') || (courseName ?? clubName);
  if (!name) return null;
  const tees = normalizeTees(detail);
  return {
    externalCourseId,
    name: name.slice(0, 200),
    subtitle: [locality, region].filter(Boolean).join(', ').slice(0, 200) || null,
    latitude: asNum(locationObj.latitude ?? locationObj.lat ?? detail.latitude ?? detail.lat),
    longitude: asNum(locationObj.longitude ?? locationObj.lon ?? detail.longitude ?? detail.lon),
    locality,
    region,
    postalCode: firstStr(locationObj.postal_code, detail.postal_code),
    countryCode,
    tees,
    raw: detail,
  };
}

function scoreForCountryHint(c: NormalizedCourse, countryHint: string | null): number {
  if (!countryHint) return 0;
  const hint = countryHint.toUpperCase();
  if ((c.countryCode ?? '').toUpperCase() == hint) return 3;
  const region = (c.region ?? '').toUpperCase();
  if (hint == 'AU' && ['VIC', 'NSW', 'QLD', 'SA', 'WA', 'TAS', 'NT', 'ACT'].includes(region)) {
    return 2;
  }
  return 0;
}

async function upsertNormalizedCourse(
  svc: ReturnType<typeof createClient>,
  course: NormalizedCourse,
): Promise<Record<string, unknown> | null> {
  const externalId = course.externalCourseId;
  const { data: existing } = await svc
    .from('courses')
    .select('id')
    .eq('source', 'provider')
    .contains('external_ids', { golfcourseapi: externalId })
    .maybeSingle();

  const coverageLevel = coverageFromTees(course.tees);
  const row = {
    name: course.name,
    subtitle: course.subtitle,
    latitude: course.latitude,
    longitude: course.longitude,
    locality: course.locality,
    region: course.region,
    postal_code: course.postalCode,
    country_code: course.countryCode,
    coverage_level: coverageLevel,
    source: 'provider',
    owner_user_id: null,
    visibility: 'public',
    external_ids: { golfcourseapi: externalId },
  };

  let courseId = existing?.id as string | undefined;
  if (courseId) {
    await svc.from('courses').update(row).eq('id', courseId);
  } else {
    const { data: inserted, error: insErr } = await svc.from('courses').insert(row).select('id').single();
    if (insErr || !inserted) return null;
    courseId = inserted.id as string;
  }

  const { error: delErr } = await svc.from('course_tees').delete().eq('course_id', courseId);
  if (delErr) return null;

  for (let i = 0; i < course.tees.length; i++) {
    const t = course.tees[i];
    const { data: teeRow, error: teeErr } = await svc
      .from('course_tees')
      .insert({
        course_id: courseId,
        sort_order: i,
        label: t.label,
        color_hint: t.colorHint,
        course_rating: t.courseRating,
        slope_rating: t.slopeRating,
        ratings_json: t.ratings,
      })
      .select('id')
      .single();
    if (teeErr || !teeRow) continue;
    const teeId = teeRow.id as string;
    const holeRows = t.holes
      .filter((h) => h.par >= 3 && h.par <= 6 && h.holeNumber >= 1 && h.holeNumber <= 18)
      .map((h) => ({
        course_tee_id: teeId,
        hole_number: h.holeNumber,
        par: h.par,
        stroke_index: h.strokeIndex,
        yardage_yds: h.yardageYds,
      }));
    if (holeRows.length > 0) {
      await svc.from('course_tee_holes').insert(holeRows);
    }
  }

  await svc.from('course_provider_cache').upsert(
    {
      provider: 'golfcourseapi',
      external_course_id: externalId,
      payload: course.raw,
      fetched_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    },
    { onConflict: 'provider,external_course_id' },
  );

  const { data: selected } = await svc
    .from('courses')
    .select('id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1')
    .eq('id', courseId)
    .maybeSingle();
  return selected as Record<string, unknown> | null;
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
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const golfCourseApiKey = Deno.env.get('GOLFCOURSEAPI_KEY') ?? '';
  const golfCourseApiBase = Deno.env.get('GOLFCOURSEAPI_BASE_URL') ?? 'https://api.golfcourseapi.com';
  const authHeader = req.headers.get('Authorization') ?? '';
  const apikeyHeader = req.headers.get('apikey') ?? '';

  if (!serviceKey) {
    return jsonResponse({ error: 'Missing SUPABASE_SERVICE_ROLE_KEY' }, 500);
  }
  const svcClient = createClient(supabaseUrl, serviceKey);
  const authBearer = authHeader.replace(/^Bearer\s+/i, '').trim();
  const apikeyTrimmed = apikeyHeader.trim();
  const authRole = jwtRole(authBearer);
  const apikeyRole = jwtRole(apikeyTrimmed);
  const isServiceRoleInvocation =
    authBearer === serviceKey ||
    apikeyTrimmed === serviceKey ||
    authRole === 'service_role' ||
    apikeyRole === 'service_role';

  let actorUserId: string | null = null;
  let userClient: ReturnType<typeof createClient> | null = null;
  if (!isServiceRoleInvocation) {
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401);
    userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }
    actorUserId = user.id;
  }
  const readClient = isServiceRoleInvocation ? svcClient : (userClient as ReturnType<typeof createClient>);

  let body: { query?: string; includeRemote?: boolean; limit?: number; countryHint?: string; strictCountry?: boolean };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON' }, 400);
  }

  const raw = (body.query ?? '').trim().slice(0, 120);
  const limit = Math.min(Math.max(body.limit ?? 25, 1), 50);
  // Dashboard/admin testing: default remote on for service-role invocations.
  const includeRemote = body.includeRemote == null ? isServiceRoleInvocation : body.includeRemote === true;
  const countryHint = firstStr(body.countryHint)?.toUpperCase() ?? null;
  const strictCountry = body.strictCountry === true;

  let dbQuery = readClient
    .from('courses')
    .select(
      'id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1',
    )
    .order('name')
    .limit(limit);

  if (raw.length > 0) {
    const esc = sanitizeIlike(raw);
    const pat = `%${esc}%`;
    dbQuery = dbQuery.or(`name.ilike.${pat},subtitle.ilike.${pat},locality.ilike.${pat}`);
  }

  const { data: dbCourses, error: dbErr } = await dbQuery;
  if (dbErr) {
    return jsonResponse({ error: dbErr.message }, 500);
  }

  const rows = [...(dbCourses ?? [])];
  let remoteCount = 0;
  let providerSyncedCount = 0;
  let providerQueriesTried: string[] = [];
  let providerCandidates = 0;

  if (includeRemote && raw.length >= 3 && serviceKey && golfCourseApiKey) {
    const svc = svcClient;
    try {
      const providerSearch = await fetchGcaSearchRows(golfCourseApiBase, golfCourseApiKey, raw);
      providerQueriesTried = providerSearch.tried;
      const searchRows = providerSearch.rows;
      providerCandidates = searchRows.length;
      const cap = Math.min(searchRows.length, 8);
      const normalizedCandidates: NormalizedCourse[] = [];
      for (let i = 0; i < cap; i++) {
        const sr = searchRows[i];
        const providerId = firstStr(sr.id);
        if (!providerId) continue;
        const detail = await fetchGcaCourseDetail(golfCourseApiBase, golfCourseApiKey, providerId);
        if (!detail) continue;
        const normalized = normalizeFromGca(sr, detail);
        if (!normalized) continue;
        normalizedCandidates.push(normalized);
      }

      const ranked = normalizedCandidates
        .map((c) => ({ c, score: scoreForCountryHint(c, countryHint) }))
        .filter((x) => !strictCountry || countryHint == null || x.score > 0)
        .sort((a, b) => b.score - a.score)
        .map((x) => x.c)
        .slice(0, 4);

      for (const normalized of ranked) {
        const selected = await upsertNormalizedCourse(svc, normalized);
        if (selected && !rows.some((r) => (r as { id: string }).id === (selected as { id: string }).id)) {
          rows.push(selected);
          providerSyncedCount++;
          remoteCount++;
        }
      }
    } catch (e) {
      if (userClient != null && actorUserId != null) {
        await userClient.from('course_data_telemetry').insert({
          user_id: actorUserId,
          kind: 'provider_error',
          payload: { provider: 'golfcourseapi', stage: 'search_sync', message: String(e) },
        });
      }
    }
  }

  if (includeRemote && raw.length >= 3 && serviceKey && rows.length < 12) {
    const svc = svcClient;
    const nomUrl = new URL('https://nominatim.openstreetmap.org/search');
    nomUrl.searchParams.set('format', 'json');
    nomUrl.searchParams.set('addressdetails', '1');
    nomUrl.searchParams.set('limit', '12');
    nomUrl.searchParams.set('q', `${raw} golf`);

    try {
      const res = await fetch(nomUrl.toString(), {
        headers: {
          'User-Agent': 'GolfBits/1.0 (https://github.com; course search)',
        },
      });
      if (res.ok) {
        const items = (await res.json()) as NomItem[];
        for (const it of items) {
          const lat = parseFloat(it.lat);
          const lon = parseFloat(it.lon);
          if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
          const osmType = it.osm_type ?? 'unknown';
          const osmId = it.osm_id ?? it.place_id;
          if (osmId == null) continue;
          const extKey = `${osmType}/${osmId}`;

          const { data: dup } = await svc
            .from('courses')
            .select('id')
            .eq('source', 'osm')
            .contains('external_ids', { osm: extKey })
            .maybeSingle();

          let courseId = dup?.id as string | undefined;
          if (!courseId) {
            const name = (it.display_name?.split(',')?.[0]?.trim() ?? raw).slice(0, 200);
            const subtitle = [it.address?.suburb, it.address?.state].filter(Boolean).join(', ').slice(0, 200) ||
              null;
            const street = [it.address?.house_number, it.address?.road].filter(Boolean).join(' ').slice(0, 200) ||
              null;
            const locality = it.address?.city || it.address?.town || it.address?.village || it.address?.suburb ||
              null;
            const region = it.address?.state || null;
            const postal = it.address?.postcode || null;
            const cc = it.address?.country_code?.toUpperCase() || null;

            const { data: inserted, error: insErr } = await svc
              .from('courses')
              .insert({
                name,
                subtitle,
                latitude: lat,
                longitude: lon,
                street_line1: street,
                locality,
                region,
                postal_code: postal,
                country_code: cc,
                coverage_level: 'geo_only',
                source: 'osm',
                owner_user_id: null,
                visibility: 'public',
                external_ids: { osm: extKey, place_id: it.place_id },
              })
              .select(
                'id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1',
              )
              .single();

            if (!insErr && inserted) {
              courseId = inserted.id as string;
              rows.push(inserted as Record<string, unknown>);
              remoteCount++;
            }
          } else {
            const { data: existing } = await readClient
              .from('courses')
              .select(
                'id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1',
              )
              .eq('id', courseId)
              .maybeSingle();
            if (existing && !rows.some((r) => (r as { id: string }).id === courseId)) {
              rows.push(existing as Record<string, unknown>);
            }
          }
        }
      }
    } catch {
      if (userClient != null && actorUserId != null) {
        await userClient.from('course_data_telemetry').insert({
          user_id: actorUserId,
          kind: 'provider_error',
          payload: { provider: 'nominatim', stage: 'search' },
        });
      }
    }
  }

  const localCount = dbCourses?.length ?? 0;
  if (userClient != null && actorUserId != null) {
    await userClient.from('course_data_telemetry').insert({
      user_id: actorUserId,
      kind: 'search',
      payload: {
        query: raw,
        localCount,
        remoteCount,
        includeRemote,
        countryHint,
        strictCountry,
        providerSyncedCount,
        providerCandidates,
        providerQueriesTried,
        resultCount: rows.length,
      },
    });
  }

  const courses = rows.slice(0, limit).map((r) => toCourseRow(r as Record<string, unknown>));

  return jsonResponse({
    courses,
    invokedAs: isServiceRoleInvocation ? 'service_role' : 'user',
    diagnostics: {
      includeRemote,
      localCount,
      remoteCount,
      providerSyncedCount,
      providerCandidates,
      providerQueriesTried,
      countryHint,
      strictCountry,
    },
    meta: {
      coverageLevels: ['geo_only', 'partial_scorecard', 'full_scorecard', 'manual'],
    },
  });
});
