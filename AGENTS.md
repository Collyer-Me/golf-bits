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

## Delivery workflow (GitHub + Supabase) — **ask first**

After **significant** work is done (for example: a user-facing feature slice, schema or migration changes, Edge Function behavior, or integration work you would normally hand off for testing), **do not** automatically commit, push, or run Supabase deploy commands.

1. **Summarize** what changed and what would be published.
2. **Ask explicitly** whether the user wants:
   - **GitHub:** commit + push (so CI / web deploy can run), and/or  
   - **Supabase:** only when backend files in-repo actually changed (see below).
3. **Only after the user says yes** (or chooses one path), run the commands from **repo root** and report success or the exact error.

**When to invoke Supabase CLI** (otherwise **omit** migration push / deploy from the ask — e.g. Flutter-only or docs-only sessions need **GitHub** only):

| Change | Include in “push to Supabase?” |
|--------|--------------------------------|
| **`supabase/migrations/`** (or new migration touching schema) | Yes — **`npx supabase db push`** after user confirms |
| **`supabase/functions/<name>/`** Edge Function source | Yes — **`npx supabase functions deploy <name>`** after user confirms (not the same as the database, but still hosted Supabase) |
| **`golf_bits/`**, other app/repo files with **no** migration or Edge Function edits | **No** Supabase CLI; **GitHub** only |

**Typical commands** (adjust branch and file scope as appropriate):

| Goal | Command |
|------|---------|
| Push app or repo changes | `git add …`, `git commit -m "…"`, `git push origin <branch>` |
| Apply migrations to linked remote (**database** changes only) | `npx supabase db push` |
| Deploy one Edge Function (function code changed) | `npx supabase functions deploy <function-name>` |

Use `npm run supabase -- …` if you prefer the npm script wrapper.

Small-only edits (typos, comments, formatting) do not require this prompt unless the user asked for a push.

## Platform focus (current phase)

- Current delivery target is **web-first**.
- Implement and verify features primarily for web behavior right now.
- Mobile-specific optimization/pass can be done in a later phase.

### Flutter app

UI and design-system rules for the mobile app live in [`golf_bits/AGENTS.md`](golf_bits/AGENTS.md).
