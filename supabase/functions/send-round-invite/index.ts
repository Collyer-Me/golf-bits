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
  const appBaseUrl = (Deno.env.get('APP_BASE_URL') ?? 'http://localhost:3000').replace(/\/$/, '');
  const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? '';
  const inviteFromEmail = Deno.env.get('INVITE_FROM_EMAIL') ?? 'Bits <noreply@bits.local>';

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return jsonResponse({ error: 'Supabase env vars missing' }, 500);
  }
  if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const svc = createClient(supabaseUrl, serviceKey);

  const {
    data: { user },
    error: userErr,
  } = await userClient.auth.getUser();
  if (userErr || !user) return jsonResponse({ error: 'Unauthorized' }, 401);

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

  const { data: round, error: roundErr } = await userClient
    .from('rounds')
    .select('id,course_name,created_by')
    .eq('id', roundId)
    .eq('created_by', user.id)
    .maybeSingle();
  if (roundErr) return jsonResponse({ error: roundErr.message }, 500);
  if (!round) return jsonResponse({ error: 'Round not found' }, 404);

  const courseName = (body.courseName?.trim() || (round.course_name as string | null) || 'your round').trim();

  const results: Array<{ email: string; inviteUrl: string; status: string; error?: string }> = [];
  for (const inv of invites) {
    const token = crypto.randomUUID().replaceAll('-', '') + crypto.randomUUID().replaceAll('-', '');
    const inviteUrl =
      `${appBaseUrl}/?type=signup&invite_token=${encodeURIComponent(token)}&invite_email=${encodeURIComponent(inv.email)}`;

    const { data: inserted, error: insErr } = await svc
      .from('round_invites')
      .insert({
        round_id: roundId,
        invited_email: inv.email,
        invited_name: inv.displayName ?? null,
        invited_by_user_id: user.id,
        token,
        status: resendApiKey ? 'sent' : 'pending',
        invite_url: inviteUrl,
        sent_at: resendApiKey ? new Date().toISOString() : null,
      })
      .select('id')
      .single();

    if (insErr || !inserted) {
      results.push({ email: inv.email, inviteUrl, status: 'failed', error: insErr?.message ?? 'insert_failed' });
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
      await svc.from('round_invites').update({ status: 'failed' }).eq('id', inserted.id);
      results.push({ email: inv.email, inviteUrl, status: 'failed', error: String(e) });
    }
  }

  return jsonResponse({
    sent: results.filter((r) => r.status === 'sent').length,
    skipped: results.filter((r) => r.status !== 'sent').length,
    invites: results,
  });
});
