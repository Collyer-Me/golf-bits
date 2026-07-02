import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MAX_INVITES_PER_REQUEST = 10;
const MAX_INVITES_PER_DAY = 50;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function escapeHtml(input: string): string {
  return input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function normalizeEmail(input: unknown): string | null {
  if (typeof input !== 'string') return null;
  const value = input.trim().toLowerCase();
  if (!value.includes('@') || value.length < 5) return null;
  return value;
}

type InviteInput = {
  email: string;
  displayName?: string;
};

type RequestBody = {
  roundId?: string;
  courseName?: string;
  invites?: InviteInput[];
};

async function sendInviteEmail(params: {
  resendApiKey: string;
  from: string;
  to: string;
  subject: string;
  html: string;
}) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${params.resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: params.from,
      to: [params.to],
      subject: params.subject,
      html: params.html,
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Resend failed: ${res.status} ${errText}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const authHeader = req.headers.get('Authorization') ?? '';
  const appBaseUrlRaw = Deno.env.get('APP_BASE_URL') ?? '';
  const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? '';
  const inviteFromEmail = Deno.env.get('INVITE_FROM_EMAIL') ?? 'Bits <noreply@bits.local>';

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return jsonResponse({ error: 'Supabase env vars missing' }, 500);
  }
  if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401);

  if (!appBaseUrlRaw.trim() || appBaseUrlRaw.includes('localhost')) {
    return jsonResponse(
      { error: 'APP_BASE_URL must be set to the production app URL (not localhost)' },
      500,
    );
  }
  const appBaseUrl = appBaseUrlRaw.replace(/\/$/, '');

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const svc = createClient(supabaseUrl, serviceKey);

  const {
    data: { user },
    error: userErr,
  } = await userClient.auth.getUser();
  if (userErr || !user) return jsonResponse({ error: 'Unauthorized' }, 401);

  if (user.is_anonymous) {
    return jsonResponse({ error: 'Anonymous accounts cannot send round invites' }, 403);
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON' }, 400);
  }

  const roundId = body.roundId?.trim();
  if (!roundId) return jsonResponse({ error: 'roundId required' }, 400);

  const invitesRaw = Array.isArray(body.invites) ? body.invites : [];
  const deduped = new Map<string, string | undefined>();
  for (const i of invitesRaw) {
    const email = normalizeEmail(i.email);
    if (!email) continue;
    deduped.set(email, i.displayName?.trim() || undefined);
  }
  const invites = [...deduped.entries()].map(([email, displayName]) => ({ email, displayName }));
  if (invites.length === 0) {
    return jsonResponse({ sent: 0, skipped: 0, invites: [] });
  }
  if (invites.length > MAX_INVITES_PER_REQUEST) {
    return jsonResponse({ error: `At most ${MAX_INVITES_PER_REQUEST} invites per request` }, 400);
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count: sentToday, error: countErr } = await svc
    .from('round_invites')
    .select('id', { count: 'exact', head: true })
    .eq('invited_by_user_id', user.id)
    .gte('created_at', since);
  if (countErr) return jsonResponse({ error: countErr.message }, 500);
  if ((sentToday ?? 0) + invites.length > MAX_INVITES_PER_DAY) {
    return jsonResponse({ error: 'Daily invite limit reached' }, 429);
  }

  const { data: round, error: roundErr } = await userClient
    .from('rounds')
    .select('id,course_name,created_by')
    .eq('id', roundId)
    .eq('created_by', user.id)
    .maybeSingle();
  if (roundErr) return jsonResponse({ error: roundErr.message }, 500);
  if (!round) return jsonResponse({ error: 'Round not found' }, 404);

  const courseName = escapeHtml(
    ((round.course_name as string | null)?.trim() || 'your round').trim(),
  );

  const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();

  const results: Array<{ email: string; inviteUrl: string; status: string; error?: string }> = [];
  for (const inv of invites) {
    const token = crypto.randomUUID().replaceAll('-', '') + crypto.randomUUID().replaceAll('-', '');
    const inviteUrl =
      `${appBaseUrl}/?type=signup&invite_token=${encodeURIComponent(token)}&invite_email=${encodeURIComponent(inv.email)}`;

    const { data: upserted, error: upsertErr } = await svc
      .from('round_invites')
      .upsert(
        {
          round_id: roundId,
          invited_email: inv.email,
          invited_name: inv.displayName ?? null,
          invited_by_user_id: user.id,
          token,
          status: resendApiKey ? 'sent' : 'pending',
          invite_url: inviteUrl,
          sent_at: resendApiKey ? new Date().toISOString() : null,
          expires_at: expiresAt,
        },
        { onConflict: 'round_id,invited_email' },
      )
      .select('id')
      .single();

    if (upsertErr || !upserted) {
      results.push({ email: inv.email, inviteUrl, status: 'failed', error: upsertErr?.message ?? 'upsert_failed' });
      continue;
    }

    if (!resendApiKey) {
      results.push({ email: inv.email, inviteUrl, status: 'pending_email_provider' });
      continue;
    }

    try {
      const subject = `You're invited to a Bits round`;
      const html =
        `<p>You were added to a Bits round for <b>${courseName}</b>.</p>` +
        `<p>Create your account (or log in) to link your player identity:</p>` +
        `<p><a href="${inviteUrl}">Accept invite</a></p>`;
      await sendInviteEmail({
        resendApiKey,
        from: inviteFromEmail,
        to: inv.email,
        subject,
        html,
      });
      results.push({ email: inv.email, inviteUrl, status: 'sent' });
    } catch (e) {
      await svc.from('round_invites').update({ status: 'failed' }).eq('id', upserted.id);
      results.push({ email: inv.email, inviteUrl, status: 'failed', error: String(e) });
    }
  }

  return jsonResponse({
    sent: results.filter((r) => r.status === 'sent').length,
    skipped: results.filter((r) => r.status !== 'sent').length,
    invites: results,
  });
});
