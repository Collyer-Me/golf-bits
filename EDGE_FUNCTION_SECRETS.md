# Supabase Edge Functions — deploy & secrets

Manual deploy from repo root (after `npm install`):

```bash
npx supabase functions deploy search-courses
npx supabase functions deploy get-course-detail
npx supabase functions deploy sync-course-by-name
npx supabase functions deploy send-round-invite
```

Apply database migrations before or with function deploys:

```bash
npx supabase db push
```

## Function secrets (Dashboard → Edge Functions → Secrets, or CLI)

| Secret | Functions | Required |
|--------|-----------|----------|
| `SUPABASE_URL` | all (auto in hosted) | yes |
| `SUPABASE_ANON_KEY` | all (auto in hosted) | yes |
| `SUPABASE_SERVICE_ROLE_KEY` | all (auto in hosted) | yes |
| `RESEND_API_KEY` | `send-round-invite` | yes for email |
| `INVITE_FROM_EMAIL` | `send-round-invite` | yes for email (e.g. `Bits <noreply@yourdomain.com>`) |
| `APP_BASE_URL` | `send-round-invite` | **yes** — production Pages URL, no trailing slash (e.g. `https://your-org.github.io/golf-bits`) |

`send-round-invite` fails at runtime if `APP_BASE_URL` is unset or points at `localhost`.

## Auth dashboard checks (hosted project)

Verify once before beta:

1. **Email confirmation** — Authentication → Providers → Email: require confirmed email for signup if using email invites.
2. **Redirect URLs** — Authentication → URL configuration: allow-list only your GitHub Pages origin (and local dev if needed).
3. **Anonymous sign-ins** — intentionally enabled for guest rounds (`enable_anonymous_sign_ins` in `supabase/config.toml`).

## Backup & restore (P0 ops)

1. Confirm your Supabase plan includes automated daily backups or enable **Point-in-Time Recovery (PITR)** for production.
2. Before risky `db push`, take a manual snapshot: `npx supabase db dump -f backup-$(date +%Y%m%d).sql` (requires linked project).
3. **Restore runbook (high level):** open Dashboard → Database → Backups → restore to a new project or use PITR; re-link CLI with `npx supabase link`; redeploy Edge Functions; verify `APP_BASE_URL` and Resend secrets on the restored project.

Consider a second free Supabase project as staging for migration review before pushing to the beta database.
