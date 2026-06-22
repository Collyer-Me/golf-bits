import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { filterProviderTeesForStorage } from './tee-label-normalize.ts';

export type GcaSearchRow = Record<string, unknown>;
export type GcaDetail = Record<string, unknown>;

export type TeeHole = {
  holeNumber: number;
  par: number;
  strokeIndex: number | null;
  yardageYds: number | null;
};

export type TeePayload = {
  label: string;
  colorHint: string | null;
  courseRating: number | null;
  slopeRating: number | null;
  ratings: Record<string, unknown>;
  holes: TeeHole[];
};

export type NormalizedCourse = {
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

export function asNum(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

export function asObj(v: unknown): Record<string, unknown> | null {
  if (v && typeof v === 'object' && !Array.isArray(v)) return v as Record<string, unknown>;
  return null;
}

export function asArr(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

export function asStr(v: unknown): string | null {
  if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t.length === 0 ? null : t;
}

export function firstStr(...vals: unknown[]): string | null {
  for (const v of vals) {
    const s = asStr(v);
    if (s) return s;
  }
  return null;
}

export function normalizeCountryCode(countryCode: string | null, countryName: string | null): string | null {
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

function teeTotalYds(holes: TeeHole[]): number {
  let s = 0;
  for (const h of holes) {
    if (h.yardageYds != null) s += h.yardageYds;
  }
  return s;
}

function teeHas18Distinct(holes: TeeHole[]): boolean {
  const nums = new Set<number>();
  for (const h of holes) nums.add(h.holeNumber);
  return nums.size >= 18;
}

export function teeDedupeKey(label: string, colorHint: string | null): string {
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

function finalizeTeePayloads(tees: TeePayload[]): TeePayload[] {
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

export function normalizeTees(detail: GcaDetail): TeePayload[] {
  const teesObj = asObj(detail.tees);
  const teesFromSpecObj = teesObj ? [...asArr(teesObj.female), ...asArr(teesObj.male)] : [];
  const topLevel = asArr(detail.tees ?? detail.tee_boxes ?? detail.teeBoxes);
  const fromGroups: unknown[] = [];
  for (const groupKey of ['male_tees', 'female_tees', 'men_tees', 'women_tees']) {
    const g = asArr(detail[groupKey]);
    fromGroups.push(...g);
  }
  const source = topLevel.length > 0 ? topLevel : (teesFromSpecObj.length > 0 ? teesFromSpecObj : fromGroups);
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
  return filterProviderTeesForStorage(finalizeTeePayloads(tees.filter((t) => t.holes.length > 0)));
}

export function coverageFromTees(tees: TeePayload[]): string {
  if (tees.length === 0) return 'geo_only';
  const totalHoles = tees.reduce((sum, t) => sum + t.holes.length, 0);
  const hasMostlyFullTees = tees.some((t) => t.holes.length >= 18);
  if (hasMostlyFullTees && totalHoles >= tees.length * 12) return 'full_scorecard';
  return 'partial_scorecard';
}

export async function gcaFetchJson(url: string, apiKey: string): Promise<unknown> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    Authorization: `Key ${apiKey}`,
  };
  const res = await fetch(url, { headers });
  if (!res.ok) return null;
  return await res.json();
}

/** Single canonical base (trim trailing slashes and redundant `/v1` / `/api` suffixes). */
export function normalizeGcaBaseUrl(baseUrl: string): string {
  return baseUrl.trim().replace(/\/+$/, '').replace(/\/v1\/?$/, '').replace(/\/api\/?$/, '');
}

/** One search query + two URL shapes (avoids the old base × path × variant matrix). */
export async function fetchGcaSearchRowsSimple(
  baseUrl: string,
  apiKey: string,
  query: string,
): Promise<{ rows: GcaSearchRow[]; tried: string[] }> {
  const base = normalizeGcaBaseUrl(baseUrl);
  const q = query.trim();
  const tried = [q];
  const byId = new Map<string, GcaSearchRow>();
  const urls = [
    `${base}/v1/search?search_query=${encodeURIComponent(q)}`,
    `${base}/search?search_query=${encodeURIComponent(q)}`,
  ];
  for (const url of urls) {
    const json = await gcaFetchJson(url, apiKey);
    if (!json) continue;
    const arr = asArr((json as Record<string, unknown>).courses ?? (json as Record<string, unknown>).data ?? json);
    for (const r of arr) {
      const row = asObj(r);
      if (!row) continue;
      const id = firstStr(row.id);
      if (!id) continue;
      if (!byId.has(id)) byId.set(id, row);
    }
    if (byId.size > 0) break;
  }
  return { rows: [...byId.values()], tried };
}

/** Detail fetch: `/v1/courses/:id` then `/courses/:id` on normalized base. */
export async function fetchGcaCourseDetailSimple(
  baseUrl: string,
  apiKey: string,
  id: string,
): Promise<GcaDetail | null> {
  const base = normalizeGcaBaseUrl(baseUrl);
  const urls = [
    `${base}/v1/courses/${encodeURIComponent(id)}`,
    `${base}/courses/${encodeURIComponent(id)}`,
  ];
  for (const url of urls) {
    const json = await gcaFetchJson(url, apiKey);
    if (!json) continue;
    const obj = asObj((json as Record<string, unknown>).course ?? (json as Record<string, unknown>).data ?? json);
    if (obj) return obj;
  }
  return null;
}

/** Hydrate path when only `external_ids.golfcourseapi` is known (no search row). */
export function minimalSearchRowFromGcaId(providerId: string): GcaSearchRow {
  return { id: providerId };
}

export function normalizeFromGca(searchRow: GcaSearchRow, detail: GcaDetail): NormalizedCourse | null {
  const externalCourseId = firstStr(searchRow.id, detail.id);
  if (!externalCourseId) return null;
  const courseName = firstStr(detail.course_name, detail.name, searchRow.course_name, searchRow.name);
  const clubName = firstStr(detail.club_name, searchRow.club_name);
  const locationObj = asObj(detail.location) ?? asObj(searchRow.location) ?? {};
  const locality = firstStr(locationObj.city, detail.city);
  const region = firstStr(locationObj.state, detail.state);
  const countryName = firstStr(locationObj.country, detail.country);
  const countryCode = normalizeCountryCode(firstStr(locationObj.country_code), countryName);
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

export function scoreForCountryHint(c: NormalizedCourse, countryHint: string | null): number {
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
  return ['golf', 'club', 'country', 'course', 'resort', 'links', 'gc', 'the', 'and'].includes(token);
}

function matchTokens(v: string): string[] {
  return normalizeMatchText(v).split(' ').filter((t) => t.length >= 3 && !isNoiseToken(t));
}

/** Default floor for accepting a provider candidate vs user-style names (Google/marketing strings). */
export const DEFAULT_MIN_NAME_MATCH = 0.52;

export function nameMatchScore(query: string, candidateName: string): number {
  const qNorm = normalizeMatchText(query);
  const cNorm = normalizeMatchText(candidateName);
  if (!qNorm || !cNorm) return 0;
  if (cNorm === qNorm) return 1;
  if (cNorm.includes(qNorm)) return 0.95;
  // Shorter canonical provider title contained in longer user query ("… Public Golf Course").
  if (qNorm.includes(cNorm) && cNorm.length >= 10) return 0.93;

  const qTokens = [...new Set(matchTokens(query))];
  const cTokens = new Set(matchTokens(candidateName));
  if (qTokens.length === 0) return 0;

  const significant = (raw: string) =>
    normalizeMatchText(raw).split(' ').filter((t) => t.length >= 2 && !['the', 'and'].includes(t));
  const qSig = significant(query);
  const cSig = significant(candidateName);
  const qFirst = qSig[0];
  const cFirst = cSig[0];

  // Avoid nuking good matches when marketing wording differs ("West …" vs "Western …").
  if (qFirst && cFirst && qFirst !== cFirst) {
    const stemOverlap =
      cFirst.startsWith(qFirst) ||
      qFirst.startsWith(cFirst) ||
      (qFirst.length >= 4 && cFirst.includes(qFirst)) ||
      (cFirst.length >= 4 && qFirst.includes(cFirst)) ||
      cNorm.includes(qFirst) ||
      qNorm.includes(cFirst);
    if (!stemOverlap) {
      const shared = qTokens.filter((t) => cTokens.has(t)).length;
      if (shared === 0) return 0.42;
    }
  }

  const hit = qTokens.filter((t) => cTokens.has(t)).length;
  return hit / qTokens.length;
}

export function coverageRank(level: string | null | undefined): number {
  if (level === 'full_scorecard') return 4;
  if (level === 'partial_scorecard') return 3;
  if (level === 'manual') return 2;
  if (level === 'geo_only') return 1;
  return 0;
}

export function sortCoursesByCoverageThenName(rows: Record<string, unknown>[]): void {
  rows.sort((a, b) => {
    const ca = coverageRank(firstStr(a.coverage_level));
    const cb = coverageRank(firstStr(b.coverage_level));
    if (cb !== ca) return cb - ca;
    return String(a.name ?? '').localeCompare(String(b.name ?? ''));
  });
}

export function dedupeByNameAndLocality(rows: Record<string, unknown>[]): Record<string, unknown>[] {
  const byKey = new Map<string, Record<string, unknown>>();
  for (const row of rows) {
    const name = normalizeMatchText(firstStr(row.name) ?? '');
    const locality = normalizeMatchText(firstStr(row.locality, row.region) ?? '');
    const key = `${name}|${locality}`;
    const prev = byKey.get(key);
    if (!prev) {
      byKey.set(key, row);
      continue;
    }
    const prevRank = coverageRank(firstStr(prev.coverage_level));
    const nextRank = coverageRank(firstStr(row.coverage_level));
    if (nextRank > prevRank) byKey.set(key, row);
  }
  return [...byKey.values()];
}

/** Parallel detail fetches with max concurrency (small batches to respect provider limits). */
export async function fetchGcaDetailsBatched(
  baseUrl: string,
  apiKey: string,
  ids: string[],
  concurrency: number,
): Promise<(GcaDetail | null)[]> {
  const out: (GcaDetail | null)[] = new Array(ids.length).fill(null);
  let next = 0;
  async function worker(): Promise<void> {
    while (true) {
      const i = next++;
      if (i >= ids.length) break;
      out[i] = await fetchGcaCourseDetailSimple(baseUrl, apiKey, ids[i]);
    }
  }
  const n = Math.min(Math.max(concurrency, 1), ids.length || 1);
  await Promise.all(Array.from({ length: n }, () => worker()));
  return out;
}

export function externalIdsGcaCourseId(externalIds: unknown): string | null {
  const o = asObj(externalIds);
  if (!o) return null;
  const v = o.golfcourseapi;
  if (typeof v === 'string' && v.trim().length > 0) return v.trim();
  if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  return null;
}

export type UpsertNormalizedCourseOpts = {
  /** Update this catalog row by id (detail hydrate); merges `external_ids` and keeps stable UUID. */
  pinnedCourseId?: string;
};

/**
 * Upsert provider course + merge tees/holes by stable label/color key (no blind delete of unrelated tees).
 */
export async function upsertNormalizedCourse(
  svc: ReturnType<typeof createClient>,
  course: NormalizedCourse,
  opts?: UpsertNormalizedCourseOpts,
): Promise<Record<string, unknown> | null> {
  const externalId = course.externalCourseId;
  const coverageLevel = coverageFromTees(course.tees);

  let courseId: string | undefined;

  if (opts?.pinnedCourseId) {
    const { data: pinRow, error: pinErr } = await svc
      .from('courses')
      .select('id,external_ids')
      .eq('id', opts.pinnedCourseId)
      .maybeSingle();
    if (pinErr || !pinRow?.id) return null;
    courseId = pinRow.id as string;
    const prevExt = asObj(pinRow.external_ids) ?? {};
    const mergedExt = { ...prevExt, golfcourseapi: externalId };
    const rowPinned = {
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
      external_ids: mergedExt,
    };
    await svc.from('courses').update(rowPinned).eq('id', courseId);
  } else {
    const { data: existing } = await svc
      .from('courses')
      .select('id')
      .eq('source', 'provider')
      .contains('external_ids', { golfcourseapi: externalId })
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
      coverage_level: coverageLevel,
      source: 'provider',
      owner_user_id: null,
      visibility: 'public',
      external_ids: { golfcourseapi: externalId },
    };

    courseId = existing?.id as string | undefined;
    if (courseId) {
      await svc.from('courses').update(row).eq('id', courseId);
    } else {
      const { data: inserted, error: insErr } = await svc.from('courses').insert(row).select('id').single();
      if (insErr || !inserted) return null;
      courseId = inserted.id as string;
    }
  }

  const { data: existingTees } = await svc
    .from('course_tees')
    .select('id,label,color_hint')
    .eq('course_id', courseId);

  const existingList = existingTees ?? [];
  const usedExistingIds = new Set<string>();

  for (let i = 0; i < course.tees.length; i++) {
    const t = course.tees[i];
    const k = teeDedupeKey(t.label, t.colorHint);
    const match = existingList.find((et) =>
      teeDedupeKey(String(et.label ?? ''), et.color_hint as string | null) === k && !usedExistingIds.has(et.id as string)
    );

    let teeId: string;
    if (match?.id) {
      teeId = match.id as string;
      usedExistingIds.add(teeId);
      const { error: upErr } = await svc
        .from('course_tees')
        .update({
          sort_order: i,
          label: t.label,
          color_hint: t.colorHint,
          course_rating: t.courseRating,
          slope_rating: t.slopeRating,
          ratings_json: t.ratings,
        })
        .eq('id', teeId);
      if (upErr) continue;
    } else {
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
      teeId = teeRow.id as string;
      usedExistingIds.add(teeId);
    }

    await svc.from('course_tee_holes').delete().eq('course_tee_id', teeId);
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

  for (const et of existingList) {
    const id = et.id as string;
    if (!usedExistingIds.has(id)) {
      await svc.from('course_tee_holes').delete().eq('course_tee_id', id);
      await svc.from('course_tees').delete().eq('id', id);
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
