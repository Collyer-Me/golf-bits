# Golf Bits (Flutter)

Cross-platform app using **Flutter**, **Material 3**, and **Supabase** (`supabase_flutter`).

**Contributors & AI:** read **[AGENTS.md](AGENTS.md)** for design-system rules. Cursor loads **[`.cursor/rules/golf-bits-flutter-ui.mdc`](../.cursor/rules/golf-bits-flutter-ui.mdc)** when editing `lib/**/*.dart`.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel), Dart 3.4+
- Xcode (macOS) / Android Studio or SDK for device builds

## Working without Flutter installed locally

If admin policy blocks installing the SDK on this PC, you can still **author screens** as normal Dart under [`lib/screens/`](lib/screens/): `MaterialApp`, `Scaffold`, `ListView`, `NavigationBar`, etc., using the [Flutter widget catalog](https://docs.flutter.dev/ui/widgets) and [Material 3](https://m3.material.io/) docs.

**What you do not get** until Flutter runs somewhere: `flutter analyze`, hot reload, emulators, or `flutter test`. Treat it like writing ahead of the toolchain.

**Ways to validate without a local install:**

1. **GitHub Codespaces** or **Gitpod** — use a dev container image that includes Flutter; open this repo, run `flutter pub get` and `flutter run -d web-server` in the cloud.
2. **Another machine** (personal laptop, home PC) with Flutter — pull the branch and fix compile errors.
3. **DartPad** ([dartpad.dev](https://dartpad.dev)) — good for **small** Material snippets only; not your full `pubspec` / `supabase_flutter` app.
4. **Figma** (or similar) — layout and flows without Dart, then translate into widgets later.

## Preview in the browser (no local Flutter)

This repo includes [`.github/workflows/flutter-web-gh-pages.yml`](../.github/workflows/flutter-web-gh-pages.yml). On every push to **`main`**, GitHub Actions builds **Flutter Web** and deploys it to **GitHub Pages**.

### One-time GitHub setup

1. Push this repository to GitHub (if it is not already remote-hosted).
2. In the repo on GitHub: **Settings → Pages**.
3. Under **Build and deployment**, set **Source** to **GitHub Actions** (not “Deploy from a branch”).
4. Merge or push to **`main`** so the workflow runs (or open **Actions → Flutter Web → GitHub Pages → Run workflow** manually).

When the workflow succeeds, open **Settings → Pages** again (or the job summary): the **site URL** for this repo is usually:

`https://collyer-me.github.io/golf-bits/`

The workflow uses `--base-href "/golf-bits/"` (from the GitHub repository name) so assets load correctly for a **project site**.

**Notes:**

- Private repos need a GitHub plan that includes Pages for private sites, or use a **public** repo for a free preview.
- First load after deploy can take a minute for DNS/cache.
- This is a **web** build (Chrome/Safari); it is not a substitute for testing **iOS/Android** shells, but it is ideal for sharing UI progress.

### Supabase auth on Pages

1. In GitHub: **Settings → Secrets and variables → Actions** (same tab works for public repos). Add:
   - **`SUPABASE_URL`** — Project URL from Supabase **Settings → API**.
   - **`SUPABASE_ANON_KEY`** — **anon public** key (never the `service_role` key).
2. Push to **`main`** (or re-run the workflow). The build passes these as `--dart-define` values baked into the web bundle.
3. In the **Supabase dashboard** (Authentication → URL configuration):
   - **Site URL**: your Pages URL, e.g. `https://<user>.github.io/<repo>/` (trailing slash is fine).
   - **Redirect URLs**: add the same URL, plus `http://localhost:*` if you run Flutter web locally with `--dart-define`.
4. **Authentication → Providers**: ensure **Email** is enabled (only email auth is wired in the app). For **Continue as guest**, enable **Anonymous** sign-ins (optional; if disabled, the app still opens home and shows a short message).
5. **Password recovery** uses `detectSessionInUri` on web; after the user follows the email link, they get a **Set new password** screen, then the shell. Ensure redirect URLs still match your Pages URL.

### Database (profiles + round history)

SQL lives in [`supabase/migrations/`](../supabase/migrations/). Run the latest file in the Supabase **SQL Editor** (or use the Supabase CLI) so `public.profiles`, `public.rounds`, triggers, and RLS exist. Without this, **History** shows an error/retry state when the app is configured against your project.

## First-time setup

From this directory (`golf_bits`):

1. **Generate platform projects** (required once; adds `android/`, `ios/`, etc.):

   ```bash
   flutter create . --project-name golf_bits --org com.golfbits --platforms=ios,android,web
   ```

   If the tool warns about existing files, prefer running `flutter create` in an empty folder and moving `lib/` + `pubspec.yaml`, or merge carefully.

2. **Fetch packages**

   ```bash
   flutter pub get
   ```

3. **Run**

   ```bash
   flutter run
   ```

4. **Supabase** — `main.dart` calls `Supabase.initialize()` when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set at compile time (see `lib/config/supabase_env.dart`). Local example:

   ```bash
   flutter run -d chrome \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your_anon_key
   ```

## Tests

```bash
flutter test
```

## Stack

- UI: Flutter **Material 3** (`ThemeData`, `ColorScheme.fromSeed`, standard `Material` widgets)
- Typography: **Lexend** via `google_fonts`
- Design tokens: `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart`
- **Style guide / component gallery**: run the app → **Style guide & components** (preview for web via GitHub Pages too)
- Backend: **Supabase** (schema already applied in your Supabase project; regenerate or maintain Dart models as you prefer)

## Design system & consistency

Single style guide for humans and automation. **Do not scatter magic numbers or hex in screens.**

### Where things live

| Concern | Source of truth |
|--------|------------------|
| All **hex colours** (brand + dark surface ramp) | [`lib/theme/app_colors.dart`](lib/theme/app_colors.dart) |
| **`ThemeData`**, spacing scale, radii, opacities, icon sizes, letter-spacing, line heights, `inputDecorationTheme`, `searchBarTheme`, buttons, chips | [`lib/theme/app_theme.dart`](lib/theme/app_theme.dart) — **`AppTheme`** |
| **Runtime semantic colours** in UI | `Theme.of(context).colorScheme` |
| **Exception:** `AppColors.accentLime` | Only where `ColorScheme` has no matching role (see component gallery swatch) |

### Spacing (`AppTheme`)

Use **`space1` … `space8`**, **`spaceHalf`**, **`space25`**, **`pageHorizontal`**, **`screenPadding`**, **`buttonPadV`**, **`cardInnerPadding`** instead of raw `8`, `16`, `24`, etc. See `AppTheme` for the numeric map (4dp-style grid).

### Radii

- **`stadiumRadius`** — pills / stadium buttons / chips  
- **`cardRadius`** — `Card`, `OutlinedSurfaceCard`  
- **`fieldRadius`** — text fields (also set globally via `inputDecorationTheme`)  
- **`radiusSm`**, **`radiusMd`** — small caps, thumbnails, progress bar clip

### Forms

`AppTheme.dark()` sets **`inputDecorationTheme`**. In screens, use:

```dart
InputDecoration(
  hintText: '…',
  prefixIcon: Icon(Icons.…),
  suffixIcon: iconButton, // not `suffix` for trailing icons
)
```

Do not repeat `filled: true`, `fillColor`, and border `OutlineInputBorder` per file unless you are intentionally overriding a single field.

### Custom widgets policy

Prefer **Material** primitives themed in `AppTheme`. The only extra widget shipped without a separate decision is **`OutlinedSurfaceCard`** (`lib/widgets/outlined_surface_card.dart`). **Add new shared widgets only after agreement** — then list them here and mirror usage in the component gallery when it makes sense.

### Keeping docs in sync

When you add **new token categories** (e.g. animation durations) or **approved custom widgets**, update:

1. This README (table or short subsection)  
2. [`AGENTS.md`](AGENTS.md)  
3. [`.cursor/rules/golf-bits-flutter-ui.mdc`](../.cursor/rules/golf-bits-flutter-ui.mdc) if the rule should enforce it  

---

### Main flows (for orientation)

Welcome / auth → **Home** (bottom nav: **Home · History · People · Profile**) → **Start new round** (four steps + sheets) → **Hole scoring** (hole nav, player cards, event bottom sheet) → **⋯ End round** → **Round summary** (winner, standings, retired) → tap a player → **Player breakdown** (timeline; demo data for **Alex**). **History** lists past rounds (demo data); tap a card → **History detail** (winner hero, standings, left early). Empty history shows **Start a Round**; the inbox icon on History toggles empty vs populated (demo). From the Home tab you can also **Preview in-round UI** without running setup.
