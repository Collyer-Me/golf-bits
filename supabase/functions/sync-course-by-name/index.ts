import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import {
  DEFAULT_MIN_NAME_MATCH,
  fetchGcaCourseDetailSimple,
  fetchGcaSearchRowsSimple,
  firstStr,
  type NormalizedCourse,
  nameMatchScore,
  normalizeFromGca,
  scoreForCountryHint,
  upsertNormalizedCourse,
} from '../_shared/gca-course-sync.ts';

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

  let body: {
    query?: string;
    /** Max courses to upsert (legacy name). */
    maxResults?: number;
    maxUpserts?: number;
    /** How many provider search hits to fetch detail for (wider net for common/marketing names). */
    maxSearchCandidates?: number;
    minNameMatch?: number;
    countryHint?: string;
    strictCountry?: boolean;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON' }, 400);
  }
  const query = (body.query ?? '').trim();
  if (query.length < 2) return jsonResponse({ error: 'query must be at least 2 chars' }, 400);
  const maxUpserts = Math.min(Math.max(body.maxUpserts ?? body.maxResults ?? 5, 1), 10);
  const maxSearchCandidates = Math.min(Math.max(body.maxSearchCandidates ?? 18, 1), 25);
  const minNameMatch = Math.min(Math.max(body.minNameMatch ?? DEFAULT_MIN_NAME_MATCH, 0.35), 0.95);
  const countryHint = firstStr(body.countryHint)?.toUpperCase() ?? null;
  const strictCountry = body.strictCountry === true;

  const svc = createClient(supabaseUrl, serviceKey);
  const providerSearch = await fetchGcaSearchRowsSimple(golfCourseApiBase, golfCourseApiKey, query);
  const searchRows = providerSearch.rows;
  const normalizedCandidates: NormalizedCourse[] = [];
  let rejectedByNameMatch = 0;
  let detailFetchMiss = 0;
  let normalizeMiss = 0;

  for (const sr of searchRows.slice(0, maxSearchCandidates)) {
    const providerId = firstStr(sr.id);
    if (!providerId) continue;
    const detail = await fetchGcaCourseDetailSimple(golfCourseApiBase, golfCourseApiKey, providerId);
    if (!detail) {
      detailFetchMiss++;
      continue;
    }
    const normalized = normalizeFromGca(sr, detail);
    if (!normalized) {
      normalizeMiss++;
      continue;
    }
    const matchScore = nameMatchScore(query, normalized.name);
    if (matchScore < minNameMatch) {
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
    .slice(0, maxUpserts);

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

  const searchPreview = searchRows.slice(0, 10).map((sr) => ({
    id: firstStr(sr.id),
    label: firstStr(sr.name, sr.course_name, sr.club_name, sr.title),
  }));

  return jsonResponse({
    synced: out,
    count: out.length,
    countryHint,
    strictCountry,
    invokedAs: isServiceRoleInvocation ? 'service_role' : 'user',
    diagnostics: {
      providerCandidates: searchRows.length,
      maxSearchCandidates,
      maxUpserts,
      minNameMatch,
      rejectedByNameMatch,
      detailFetchMiss,
      normalizeMiss,
      providerQueriesTried: providerSearch.tried,
      searchPreview,
    },
  });
});
