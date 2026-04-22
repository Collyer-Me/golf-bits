# Bits — agent / contributor notes

## Supabase (database, migrations, Edge Functions)

**Use the Supabase CLI from this repository root** for ongoing backend work. The Dashboard is fine for browsing data, auth settings, logs, and one-off inspection — but **schema and migration changes should go through the CLI and tracked files**, not ad-hoc SQL pasted in the Dashboard.

### Why

- Migrations under `supabase/migrations/` stay in git, reviewable, and reproducible.
- Local and remote environments stay aligned with `supabase link`, `supabase start`, and `supabase db push` (or your documented CI path).

### Setup (repo root)

1. **`npm install`** — installs the `supabase` package (devDependency); no global CLI required.
2. Run commands with **`npx supabase …`** or **`npm run supabase -- …`** (the `--` separates npm args from CLI args).

### Commands you will use often

| Goal | Command (from repo root) |
|------|---------------------------|
| Local stack (Docker) | `npx supabase start` |
| Link CLI to hosted project | `npx supabase link` |
| New migration file | `npx supabase migration new <descriptive_name>` |
| Apply migrations to linked remote DB | `npx supabase db push` |
| Deploy an Edge Function | `npx supabase functions deploy <function-name>` |

Official reference: [Supabase CLI](https://supabase.com/docs/guides/cli).

### Flutter app

UI and design-system rules for the mobile app live in [`golf_bits/AGENTS.md`](golf_bits/AGENTS.md).
