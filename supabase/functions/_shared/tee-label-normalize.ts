// Repeatable provider tee_name rules — keep in sync with golf_bits/lib/models/tee_label_normalize.dart

export type ParsedTeeMetadata = {
  rawLabel: string;
  color: string | null;
  gender: 'men' | 'women' | null;
  isHistorical: boolean;
  isTemporary: boolean;
  isNineHoleHint: boolean;
  familyKey: string;
};

const KNOWN_COLOR_TOKENS = [
  'terra-cotta',
  'terra cotta',
  'championship',
  'burgundy',
  'maroon',
  'purple',
  'silver',
  'golden',
  'yellow',
  'orange',
  'bronze',
  'cream',
  'shark',
  'ozzie',
  'aussie',
  'royal',
  'combo',
  'lion',
  'black',
  'blue',
  'white',
  'green',
  'gold',
  'red',
] as const;

const HISTORICAL_TOKEN = /\b(?:NOV|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|DEC)\d{2}\b/i;
const YEAR_SUFFIX = /\b(19|20)\d{2}\b/;
const NINE_HOLE_HINT = /\b(?:SP\s*)?9\s*holes?\b/i;
const NUMERIC_COURSE_CODE = /^\d{4,6}$/;
const RATING_SYSTEM = /^(USGA|GA|MGA|AGU)$/i;

function titleCaseSingle(s: string): string {
  if (!s) return s;
  return s[0].toUpperCase() + s.slice(1).toLowerCase();
}

function titleCaseToken(token: string): string {
  if (token.includes('-')) return token.split('-').map(titleCaseSingle).join('-');
  if (token.includes(' ')) return token.split(' ').map(titleCaseSingle).join(' ');
  return titleCaseSingle(token);
}

function matchColorToken(text: string): string | null {
  const lower = text.toLowerCase();
  for (const token of KNOWN_COLOR_TOKENS) {
    if (lower.includes(token)) return titleCaseToken(token);
  }
  if (lower.includes('/')) {
    const names: string[] = [];
    for (const seg of lower.split('/')) {
      const s = seg.trim();
      for (const token of KNOWN_COLOR_TOKENS) {
        if (s.includes(token)) {
          names.push(titleCaseToken(token));
          break;
        }
      }
    }
    if (names.length > 0) return names.join('/');
  }
  return null;
}

export function parseProviderTeeLabel(rawLabel: string): ParsedTeeMetadata {
  const raw = rawLabel.trim();
  if (!raw) {
    return {
      rawLabel: raw,
      color: null,
      gender: null,
      isHistorical: false,
      isTemporary: false,
      isNineHoleHint: false,
      familyKey: '|',
    };
  }

  const lower = raw.toLowerCase();
  const isHistorical = HISTORICAL_TOKEN.test(raw) || (YEAR_SUFFIX.test(raw) && raw.includes(','));
  const isTemporary = lower.includes('temp');
  const isNineHoleHint = NINE_HOLE_HINT.test(raw);

  let color: string | null = null;
  let gender: 'men' | 'women' | null = null;

  if (!raw.includes(',')) {
    color = matchColorToken(raw) ?? titleCaseSingle(raw);
  } else {
    const parts = raw.split(',').map((p) => p.trim()).filter(Boolean);
    for (const part of parts) {
      const pl = part.toLowerCase();
      if (NUMERIC_COURSE_CODE.test(part) || RATING_SYSTEM.test(part)) continue;
      if (pl === 'men' || pl === 'man' || pl === 'male' || pl === 'mens') {
        gender = 'men';
        continue;
      }
      if (pl === 'women' || pl === 'woman' || pl === 'female' || pl === 'ladies' || pl === 'womens') {
        gender = 'women';
        continue;
      }
      const matched = matchColorToken(part);
      if (matched) color ??= matched;
    }
    color ??= matchColorToken(raw);
  }

  const familyKey = `${(color ?? raw.toLowerCase())}|${gender ?? ''}`;
  return { rawLabel: raw, color, gender, isHistorical, isTemporary, isNineHoleHint, familyKey };
}

export function teeDisplayLabel(meta: ParsedTeeMetadata, showGenderSuffix: boolean): string {
  const base = meta.color ?? titleCaseSingle(meta.rawLabel.split(',')[0]?.trim() ?? meta.rawLabel);
  if (showGenderSuffix && meta.gender) {
    return `${base} (${meta.gender === 'women' ? 'Women' : 'Men'})`;
  }
  return base;
}

export function teeColorHintFromMetadata(meta: ParsedTeeMetadata, existingHint: string | null): string | null {
  if (meta.color) return meta.color;
  const h = existingHint?.trim();
  return h && h.length > 0 ? h : null;
}

function teeHas18Distinct(holeNumbers: number[]): boolean {
  return new Set(holeNumbers).size >= 18;
}

export type TeeLike = {
  label: string;
  colorHint: string | null;
  holes: { holeNumber: number }[];
  yardageTotal: number;
};

export function preferTeeCandidate(
  incumbent: TeeLike,
  incumbentMeta: ParsedTeeMetadata,
  candidate: TeeLike,
  candidateMeta: ParsedTeeMetadata,
): boolean {
  const i18 = teeHas18Distinct(incumbent.holes.map((h) => h.holeNumber));
  const c18 = teeHas18Distinct(candidate.holes.map((h) => h.holeNumber));
  if (i18 !== c18) return c18;
  if (incumbentMeta.isHistorical !== candidateMeta.isHistorical) return !candidateMeta.isHistorical;
  if (incumbentMeta.isTemporary !== candidateMeta.isTemporary) return !candidateMeta.isTemporary;
  if (incumbentMeta.isNineHoleHint !== candidateMeta.isNineHoleHint) return !candidateMeta.isNineHoleHint;
  if (incumbent.yardageTotal !== candidate.yardageTotal) return candidate.yardageTotal > incumbent.yardageTotal;
  if (incumbent.holes.length !== candidate.holes.length) return candidate.holes.length > incumbent.holes.length;
  return candidateMeta.rawLabel.length < incumbentMeta.rawLabel.length;
}

/** Collapse provider tee list before DB upsert (same rules as Flutter prepareTeesForDisplay). */
export function filterProviderTeesForStorage<
  T extends { label: string; colorHint: string | null; holes: { holeNumber: number; yardageYds: number | null }[] },
>(tees: T[]): T[] {
  const nonempty = tees.filter((t) => t.holes.length > 0);
  if (nonempty.length === 0) return [];

  const metas = nonempty.map((t) => parseProviderTeeLabel(t.label));
  const byFamily = new Map<string, { tee: T; meta: ParsedTeeMetadata }>();

  for (let i = 0; i < nonempty.length; i++) {
    const tee = nonempty[i];
    const meta = metas[i];
    const yardageTotal = tee.holes.reduce((s, h) => s + (h.yardageYds ?? 0), 0);
    const prev = byFamily.get(meta.familyKey);
    if (!prev) {
      byFamily.set(meta.familyKey, { tee, meta });
      continue;
    }
    const prevY = prev.tee.holes.reduce((s, h) => s + (h.yardageYds ?? 0), 0);
    if (
      preferTeeCandidate(
        { label: prev.tee.label, colorHint: prev.tee.colorHint, holes: prev.tee.holes, yardageTotal: prevY },
        prev.meta,
        { label: tee.label, colorHint: tee.colorHint, holes: tee.holes, yardageTotal },
        meta,
      )
    ) {
      byFamily.set(meta.familyKey, { tee, meta });
    }
  }

  const genders = new Set(
    [...byFamily.values()].map((x) => x.meta.gender).filter((g): g is 'men' | 'women' => g != null),
  );
  const showGender = genders.size > 1;

  return [...byFamily.values()].map(({ tee, meta }) => ({
    ...tee,
    label: teeDisplayLabel(meta, showGender),
    colorHint: teeColorHintFromMetadata(meta, tee.colorHint),
  }));
}
