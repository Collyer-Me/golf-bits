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

type CourseHole = {
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
  holes: CourseHole[];
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

function asObj(v: unknown): Record<string, unknown> | null {
  if (v && typeof v === 'object' && !Array.isArray(v)) return v as Record<string, unknown>;
  return null;
}

function asArr(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

function asNum(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return null;
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

function normalizeCountryCode(countryCode: string | null, countryName: string | null): string | null {
  if (countryCode && countryCode.length >= 2) return countryCode.slice(0, 2).toUpperCase();
  if (!countryName) return null;
  return countryNameToIso2[countryName.trim().toLowerCase()] ?? null;
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

function normalizeHoles(rawHoles: unknown[]): CourseHole[] {
  const out: CourseHole[] = [];
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
    out.push({
      holeNumber: Math.trunc(holeNumber),
      par: Math.trunc(par),
      strokeIndex: strokeRaw == null ? null : Math.trunc(strokeRaw),
      yardageYds: yardageYds == null ? null : Math.trunc(yardageYds),
    });
  }
  out.sort((a, b) => a.holeNumber - b.holeNumber);
  return out;
}

function teeTotalYds(holes: CourseHole[]): number {
  let s = 0;
  for (const h of holes) {
    if (h.yardageYds != null) s += h.yardageYds;
  }
  return s;
}

function teeHas18Distinct(holes: CourseHole[]): boolean {
  const nums = new Set<number>();
  for (const h of holes) nums.add(h.holeNumber);
  return nums.size >= 18;
}

function teeDedupeKey(label: string, colorHint: string | null): string {
  const ln = label.trim().toLowerCase().replace(/\s+/g, ' ');
  const ch = (colorHint ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  return `${ln}|${ch}`;
}

function betterDuplicateTees(a: TeePayload, b: TeePayload): TeePayload {
  const a18 = teeHas18Distinct(a.holes);
  const b18 = teeHas18Distinct(b.holes);
  if (a18 !== b18) return a18 ? a : b;
  const ay = teeTotalYds(a.holes);
  const by = teeTotalYds(b.holes);
  if (ay !== by) return ay > by ? a : b;
  if (a.holes.length !== b.holes.length) return a.holes.length > b.holes.length ? a : b;
  return a;
}

/** Drop empty tees, dedupe by label/color, sort: full 18 first, then yardage (matches golf_bits prepareTeesForDisplay). */
function finalizeTeePayloadsSync(tees: TeePayload[]): TeePayload[] {
  const nonempty = tees.filter((t) => t.holes.length > 0);
  if (nonempty.length === 0) return [];
  const byKey = new Map<string, TeePayload>();
  for (const t of nonempty) {
    const k = teeDedupeKey(t.label, t.colorHint);
    const prev = byKey.get(k);
    byKey.set(k, prev == null ? t : betterDuplicateTees(prev, t));
  }
  const arr = [...byKey.values()];
  arr.sort((a, b) => {
    const da = teeHas18Distinct(a.holes) ? 1 : 0;
    const db = teeHas18Distinct(b.holes) ? 1 : 0;
    if (da !== db) return db - da;
    const yt = teeTotalYds(b.holes) - teeTotalYds(a.holes);
    if (yt !== 0) return yt;
    return a.label.localeCompare(b.label);
  });
  return arr;
}

function normalizeTees(detail: Record<string, unknown>): TeePayload[] {
  const teesObj = asObj(detail.tees);
  const teesFromSpecObj = teesObj
    ? [...asArr(teesObj.female), ...asArr(teesObj.male)]
    : [];
  const topLevel = asArr(detail.tees ?? detail.tee_boxes ?? detail.teeBoxes);
  const grouped = ['male_tees', 'female_tees', 'men_tees', 'women_tees'].flatMap((k) => asArr(detail[k]));
  const source = topLevel.length > 0
    ? topLevel
    : (teesFromSpecObj.length > 0 ? teesFromSpecObj : grouped);
  const tees: TeePayload[] = [];
  for (const tr of source) {
    const tee = asObj(tr);
    if (!tee) continue;
    const holes = normalizeHoles(asArr(tee.holes ?? tee.hole_data ?? tee.holeData));
    if (holes.length === 0) continue;
    tees.push({
      label: firstStr(tee.tee_name, tee.name, tee.color, tee.label, tee.title) ?? 'TEE',
      colorHint: firstStr(tee.color, tee.tee_color),
      courseRating: asNum(tee.course_rating ?? tee.rating),
      slopeRating: asNum(tee.slope_rating ?? tee.slope),
      holes,
    });
  }
  return finalizeTeePayloadsSync(tees);
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
): Promise<{ rows: Record<string, unknown>[]; tried: string[] }> {
  const bases = [baseUrl, baseUrl.replace(/\/v1\/?$/, ''), baseUrl.replace(/\/api\/?$/, '')]
    .map((x) => x.replace(/\/$/, ''));
  const paths = [
    (b: string, q: string) => `${b}/v1/search?search_query=${encodeURIComponent(q)}`,
    (b: string, q: string) => `${b}/search?search_query=${encodeURIComponent(q)}`,
  ];
  const tried: string[] = [];
  const byId = new Map<string, Record<string, unknown>>();
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

async function fetchGcaCourseDetail(baseUrl: string, apiKey: string, id: string): Promise<Record<string, unknown> | null> {
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

function normalizeFromGca(searchRow: Record<string, unknown>, detail: Record<string, unknown>): NormalizedCourse | null {
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
    tees: normalizeTees(detail),
    raw: detail,
  };
}

function scoreForCountryHint(
  c: NormalizedCourse,
  countryHint: string | null,
): number {
  if (!countryHint) return 0;
  const hint = countryHint.toUpperCase();
  if ((c.countryCode ?? '').toUpperCase() == hint) return 3;
  const region = (c.region ?? '').toUpperCase();
  if (hint == 'AU' && ['VIC', 'NSW', 'QLD', 'SA', 'WA', 'TAS', 'NT', 'ACT'].includes(region)) {
    return 2;
  }
  return 0;
}

function normalizeMatchText(v: string): string {
  return v.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
}

function isNoiseToken(token: string): boolean {
  return [
    'golf',
    'club',
    'country',
    'course',
    'resort',
    'links',
    'gc',
    'the',
    'and',
  ].includes(token);
}

function matchTokens(v: string): string[] {
  return normalizeMatchText(v)
    .split(' ')
    .filter((t) => t.length >= 3 && !isNoiseToken(t));
}

function nameMatchScore(query: string, candidateName: string): number {
  const qNorm = normalizeMatchText(query);
  const cNorm = normalizeMatchText(candidateName);
  if (!qNorm || !cNorm) return 0;
  if (cNorm === qNorm) return 1;
  if (cNorm.includes(qNorm)) return 0.95;
  const qTokens = [...new Set(matchTokens(query))];
  const cTokens = new Set(matchTokens(candidateName));
  if (qTokens.length === 0) return 0;
  const qFirst = normalizeMatchText(query).split(' ').find((t) => t.length >= 2 && !['the', 'and'].includes(t));
  const cFirst = normalizeMatchText(candidateName).split(' ').find((t) => t.length >= 2 && !['the', 'and'].includes(t));
  if (qFirst && cFirst && qFirst !== cFirst) return 0.45;
  const hit = qTokens.filter((t) => cTokens.has(t)).length;
  return hit / qTokens.length;
}

async function upsertNormalizedCourse(
  svc: ReturnType<typeof createClient>,
  course: NormalizedCourse,
): Promise<Record<string, unknown> | null> {
  const { data: existing } = await svc
    .from('courses')
    .select('id')
    .eq('source', 'provider')
    .contains('external_ids', { golfcourseapi: course.externalCourseId })
    .maybeSingle();

  const row = {
    name: course.name,
    subtitle: course.subtitle,
    latitude: course.latitude,
    longitude: course.longitude,
    locality: course.locality,
    region: course.region,
    postal_code: course.postalCode,
    country_code: course.countryCode,
    coverage_level: coverageFromTees(course.tees),
    source: 'provider',
    owner_user_id: null,
    visibility: 'public',
    external_ids: { golfcourseapi: course.externalCourseId },
  };

  let courseId = existing?.id as string | undefined;
  if (courseId) {
    await svc.from('courses').update(row).eq('id', courseId);
  } else {
    const { data: inserted, error: insErr } = await svc.from('courses').insert(row).select('id').single();
    if (insErr || !inserted) return null;
    courseId = inserted.id as string;
  }

  await svc.from('course_tees').delete().eq('course_id', courseId);
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
        ratings_json: {},
      })
      .select('id')
      .single();
    if (teeErr || !teeRow) continue;
    const teeId = teeRow.id as string;
    const holeRows = t.holes
      .filter((h) => h.holeNumber >= 1 && h.holeNumber <= 18 && h.par >= 3 && h.par <= 6)
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
      external_course_id: course.externalCourseId,
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
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const golfCourseApiKey = Deno.env.get('GOLFCOURSEAPI_KEY') ?? '';
  const golfCourseApiBase = Deno.env.get('GOLFCOURSEAPI_BASE_URL') ?? 'https://api.golfcourseapi.com';
  const authHeader = req.headers.get('Authorization') ?? '';
  const apikeyHeader = req.headers.get('apikey') ?? '';
  if (!serviceKey) return jsonResponse({ error: 'Missing SUPABASE_SERVICE_ROLE_KEY' }, 500);
  if (!golfCourseApiKey) return jsonResponse({ error: 'Missing GOLFCOURSEAPI_KEY' }, 500);

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
    if (userErr || !user) return jsonResponse({ error: 'Unauthorized' }, 401);
    actorUserId = user.id;
  }

  let body: { query?: string; maxResults?: number; countryHint?: string; strictCountry?: boolean };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON' }, 400);
  }
  const query = (body.query ?? '').trim();
  if (query.length < 2) return jsonResponse({ error: 'query must be at least 2 chars' }, 400);
  const maxResults = Math.min(Math.max(body.maxResults ?? 3, 1), 10);
  const countryHint = firstStr(body.countryHint)?.toUpperCase() ?? null;
  const strictCountry = body.strictCountry === true;

  const svc = createClient(supabaseUrl, serviceKey);
  const providerSearch = await fetchGcaSearchRows(golfCourseApiBase, golfCourseApiKey, query);
  const searchRows = providerSearch.rows;
  const normalizedCandidates: NormalizedCourse[] = [];
  let rejectedByNameMatch = 0;

  for (const sr of searchRows.slice(0, maxResults)) {
    const providerId = firstStr(sr.id);
    if (!providerId) continue;
    const detail = await fetchGcaCourseDetail(golfCourseApiBase, golfCourseApiKey, providerId);
    if (!detail) continue;
    const normalized = normalizeFromGca(sr, detail);
    if (!normalized) continue;
    const matchScore = nameMatchScore(query, normalized.name);
    if (matchScore < 0.6) {
      rejectedByNameMatch++;
      continue;
    }
    normalizedCandidates.push(normalized);
  }

  const ranked = normalizedCandidates
    .map((c) => {
      const countryScore = scoreForCountryHint(c, countryHint);
      const matchScore = nameMatchScore(query, c.name);
      return {
        c,
        countryScore,
        score: (countryScore * 10) + Math.round(matchScore * 10),
      };
    })
    .filter((x) => !strictCountry || countryHint == null || x.countryScore > 0)
    .sort((a, b) => b.score - a.score)
    .map((x) => x.c)
    .slice(0, maxResults);

  const out: Record<string, unknown>[] = [];
  for (const c of ranked) {
    const upserted = await upsertNormalizedCourse(svc, c);
    if (upserted) out.push(upserted);
  }

  if (userClient != null && actorUserId != null) {
    await userClient.from('course_data_telemetry').insert({
      user_id: actorUserId,
      kind: 'provider_sync',
      payload: { provider: 'golfcourseapi', query, syncedCount: out.length },
    });
  }

  return jsonResponse({
    synced: out,
    count: out.length,
    countryHint,
    strictCountry,
    invokedAs: isServiceRoleInvocation ? 'service_role' : 'user',
    diagnostics: {
      providerCandidates: searchRows.length,
      rejectedByNameMatch,
      providerQueriesTried: providerSearch.tried,
    },
  });
});
