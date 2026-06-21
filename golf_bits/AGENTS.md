# Bits Dots Junk (golf_bits) — agent / contributor notes

Flutter app under this folder. Use this file plus [`README.md`](README.md) to stay aligned with the design system.

**Supabase (DB, migrations, Edge Functions):** use the CLI from the repo root — see **[`../AGENTS.md`](../AGENTS.md)** (project-wide); do not rely on the Dashboard SQL editor as the main way to change schema.

**Delivery flow:** after significant updates, agents should **ask** whether to push to GitHub; Supabase **`db push`** only if migrations changed, **`functions deploy`** only if Edge Function code changed. Details: **[`../AGENTS.md`](../AGENTS.md)** (*Delivery workflow*).

**Current target:** web-first delivery for now; mobile-specific polish/validation is a later phase.

## Anonymous (guest) users

- Guest rounds must keep the same `auth.uid` when the player adds credentials. Flow: **`auth.updateUser(...)`** (“upgrade guest”), not **`signUp()`** while signed in as a guest (that orphans cloud rounds tied to the old anonymous id).
- In **Supabase Dashboard → Authentication**, ensure settings allow linking anonymous identities to email/password (or your chosen upgrade path per Supabase docs) so **`updateUser` / linking** behaves as intended for anonymous users.

## Design system (non-negotiable)

1. **Colours**
   - **All hex literals** live in [`lib/theme/app_colors.dart`](lib/theme/app_colors.dart) — the Bits Dots Junk palette (Ink / Parchment / Fairway / Pine + Bits/Junk/Sand semantics) with **both** the dark ("on course") and light ("in the clubhouse") surface ramps.
   - **Screens and widgets** use `Theme.of(context).colorScheme`; for the Bits/Junk/Sand semantics use the per-brightness helpers `AppTheme.bits(context)` / `AppTheme.junk(context)` / `AppTheme.sand(context)`.
   - Do not add `Color(0xFF…)`, `Colors.*` for product UI, or one-off `withOpacity` / `withValues` without a named token in [`lib/theme/app_theme.dart`](lib/theme/app_theme.dart).

2. **Layout, spacing, radii, type rhythm**
   - Use **`AppTheme`** constants for `SizedBox`, `EdgeInsets`, corner radii (`fieldRadius`, `radiusSm`, `radiusMd`, `cardRadius`, `stadiumRadius`), letter-spacing (`letterWordmark`, `letterStepCaps`, …), opacities (`opacityPrimaryBorder`, …), icon sizes (`iconDense`, `iconHero`, …), and line heights (`bodyLineHeightRelaxed`, `bodyLineHeightTight`).
   - Prefer **`AppTheme.screenPadding`** / **`AppTheme.pageHorizontal`** for page edges and sheets.

3. **Forms**
   - Global field chrome is defined in **`AppTheme` → `inputDecorationTheme`** (shared by `dark()` + `light()`). Pass only what differs: `hintText`, `labelText`, `prefixIcon` / **`suffixIcon`** (not `suffix` for icon buttons), validators.
   - Do not duplicate filled/outline border `InputDecoration` blocks in screens.

4. **Components**
   - Prefer Material 3: `Card`, `FilledButton`, `SearchBar`, `Chip`, `TabBar`, `SegmentedButton`, etc., as themed in `AppTheme`.
   - Approved shared widgets: **`OutlinedSurfaceCard`**, **`BrandAppBar`** (the one header on every screen), **`BrandWordmark`** / **`BrandMark`** (code-drawn logo), and **`TallyMarks`** (the signature tally motif). Add further shared widgets only after explicit agreement (document here when you do).

5. **Typography**
   - Three families via `google_fonts`, composed in `AppTheme`: **Bricolage Grotesque** (display + headline), **Hanken Grotesk** (titles, body, labels, buttons), **DM Mono** (the `labelSmall` all-caps "ledger" labels). Use `Theme.of(context).textTheme` roles; for score numerals use `AppTheme.score(context, …)` and for caps labels `AppTheme.monoLabel(context)`. Avoid raw `fontSize:` unless mirroring a token.

6. **Header**
   - Every screen uses **`BrandAppBar`** (centered wordmark, automatic back, optional `actions` / custom `leading`). Never put a screen title in the app bar — put it in the body.

7. **Themes**
   - Dark + light are built as a mirrored pair from one token set; `main.dart` wires `theme` (light) + `darkTheme` (dark) + `themeMode` via `ThemeController` (System/Light/Dark toggle in Profile, default System). **Every screen must read correctly in both themes** — drive everything from `colorScheme` / `textTheme`.

8. **Preview**
   - **Style guide & components** in the app mirrors tokens and patterns; keep it updated when you add new categories of UI.

## Key files

| Area | File |
|------|------|
| Brand + surface hex | `lib/theme/app_colors.dart` |
| `ThemeData`, spacing, input/search themes | `lib/theme/app_theme.dart` |
| Living UI reference | `lib/screens/component_gallery_screen.dart` |
| Accent card | `lib/widgets/outlined_surface_card.dart` |
| One header (all screens) | `lib/widgets/brand_app_bar.dart` |
| Logo mark + wordmark | `lib/widgets/brand_wordmark.dart` |
| Tally motif | `lib/widgets/tally_marks.dart` |
| In-round hole + event sheet | `lib/screens/hole_scoring_screen.dart` |
| End-of-round summary | `lib/screens/round_summary_screen.dart` |
| Player timeline | `lib/screens/player_breakdown_screen.dart` |
| History list + empty | `lib/screens/history_screen.dart` |
| History round detail | `lib/screens/history_detail_screen.dart` |
| Past-round DTOs (demo) | `lib/models/history_round.dart` |

## Cursor

Repo-level rule: [`.cursor/rules/golf-bits-flutter-ui.mdc`](../.cursor/rules/golf-bits-flutter-ui.mdc) (applies when editing `golf_bits/lib/**/*.dart`).
