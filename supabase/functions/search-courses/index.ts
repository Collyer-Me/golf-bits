import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import {
  DEFAULT_MIN_NAME_MATCH,
  dedupeByNameAndLocality,
  fetchGcaDetailsBatched,
  fetchGcaSearchRowsSimple,
  firstStr,
  type NormalizedCourse,
  nameMatchScore,
  normalizeFromGca,
  scoreForCountryHint,
  sortCoursesByCoverageThenName,
  upsertNormalizedCourse,
} from '../_shared/gca-course-sync.ts';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SEARCH_BUDGET_MS = 11_000;

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const deadline = Date.now() + SEARCH_BUDGET_MS;
  const hasBudget = () => Date.now() < deadline;

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

  let body: {
    query?: string;
    includeRemote?: boolean;
    limit?: number;
    countryHint?: string;
    strictCountry?: boolean;
    allowOsmFallback?: boolean;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON' }, 400);
  }

  const raw = (body.query ?? '').trim().slice(0, 120);
  const limit = Math.min(Math.max(body.limit ?? 25, 1), 50);
  const includeRemote = body.includeRemote == null ? isServiceRoleInvocation : body.includeRemote === true;
  const countryHint = firstStr(body.countryHint)?.toUpperCase() ?? null;
  const strictCountry = body.strictCountry === true;

  const dbFetchLimit = raw.length > 0 ? Math.min(120, Math.max(limit * 5, limit)) : limit;

  let dbQuery = readClient
    .from('courses')
    .select(
      'id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1',
    )
    .order('name')
    .limit(dbFetchLimit);

  if (raw.length > 0) {
    const esc = sanitizeIlike(raw);
    const pat = `%${esc}%`;
    dbQuery = dbQuery.or(`name.ilike.${pat},subtitle.ilike.${pat},locality.ilike.${pat}`);
  }

  const { data: dbCourses, error: dbErr } = await dbQuery;
  if (dbErr) {
    return jsonResponse({ error: dbErr.message }, 500);
  }

  const rows = [...(dbCourses ?? [])] as Record<string, unknown>[];
  sortCoursesByCoverageThenName(rows);

  let remoteCount = 0;
  let providerSyncedCount = 0;
  let providerQueriesTried: string[] = [];
  let providerCandidates = 0;
  let rejectedByNameMatch = 0;
  let timedOut = false;

  const localCount = dbCourses?.length ?? 0;

  if (includeRemote && raw.length >= 2 && golfCourseApiKey && hasBudget()) {
    const svc = svcClient;
    try {
      const providerSearch = await fetchGcaSearchRowsSimple(golfCourseApiBase, golfCourseApiKey, raw);
      providerQueriesTried = providerSearch.tried;
      const searchRows = providerSearch.rows;
      providerCandidates = searchRows.length;

      const cap = Math.min(searchRows.length, 10);
      const pairs: { sr: Record<string, unknown>; id: string }[] = [];
      for (let i = 0; i < cap; i++) {
        const sr = searchRows[i];
        const pid = firstStr(sr.id);
        if (pid) pairs.push({ sr, id: pid });
      }
      const ids = pairs.map((p) => p.id);

      const details = hasBudget()
        ? await fetchGcaDetailsBatched(golfCourseApiBase, golfCourseApiKey, ids, 3)
        : [];

      const rankedPool: { n: NormalizedCourse; score: number }[] = [];

      for (let i = 0; i < pairs.length; i++) {
        const sr = pairs[i].sr;
        const detail = details[i];
        if (!detail) continue;
        const normalized = normalizeFromGca(sr, detail);
        if (!normalized) continue;
        const matchScore = nameMatchScore(raw, normalized.name);
        if (matchScore < DEFAULT_MIN_NAME_MATCH) {
          rejectedByNameMatch++;
          continue;
        }
        const countryScore = scoreForCountryHint(normalized, countryHint);
        if (strictCountry && countryHint != null && countryScore <= 0) continue;
        rankedPool.push({
          n: normalized,
          score: countryScore * 10 + Math.round(matchScore * 10),
        });
      }

      rankedPool.sort((a, b) => b.score - a.score);
      const maxUpserts = 3;
      const toUpsert = rankedPool.slice(0, maxUpserts).map((x) => x.n);

      for (const normalized of toUpsert) {
        if (!hasBudget()) {
          timedOut = true;
          break;
        }
        const selected = await upsertNormalizedCourse(svc, normalized);
        if (selected && !rows.some((r) => (r as { id: string }).id === (selected as { id: string }).id)) {
          rows.push(selected as Record<string, unknown>);
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

  if (!hasBudget()) timedOut = true;

  // OSM/Nominatim fallback disabled for user search — it created geo_only noise (UK mini-golf, etc.).
  // Re-enable only for explicit service-role tooling via `allowOsmFallback: true`.
  const allowOsmFallback = body.allowOsmFallback === true && isServiceRoleInvocation;

  if (allowOsmFallback && includeRemote && raw.length >= 2 && serviceKey && rows.length < 8 && hasBudget()) {
    const svc = svcClient;
    const nomUrl = new URL('https://nominatim.openstreetmap.org/search');
    nomUrl.searchParams.set('format', 'json');
    nomUrl.searchParams.set('addressdetails', '1');
    nomUrl.searchParams.set('limit', '10');
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
          if (!hasBudget()) {
            timedOut = true;
            break;
          }
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

  let dedupedRows = dedupeByNameAndLocality(rows);
  sortCoursesByCoverageThenName(dedupedRows);

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
        rejectedByNameMatch,
        providerQueriesTried,
        resultCount: dedupedRows.length,
        timedOut,
        budgetMs: SEARCH_BUDGET_MS,
      },
    });
  }

  const courses = dedupedRows.slice(0, limit).map((r) => toCourseRow(r));

  return jsonResponse({
    courses,
    invokedAs: isServiceRoleInvocation ? 'service_role' : 'user',
    diagnostics: {
      includeRemote,
      localCount,
      remoteCount,
      providerSyncedCount,
      providerCandidates,
      rejectedByNameMatch,
      providerQueriesTried,
      countryHint,
      strictCountry,
      timedOut,
      budgetMs: SEARCH_BUDGET_MS,
    },
    meta: {
      coverageLevels: ['geo_only', 'partial_scorecard', 'full_scorecard', 'manual'],
    },
  });
});
