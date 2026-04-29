# Golf Bits — agent / contributor notes

Flutter app under this folder. Use this file plus [`README.md`](README.md) to stay aligned with the design system.

**Supabase (DB, migrations, Edge Functions):** use the CLI from the repo root — see **[`../AGENTS.md`](../AGENTS.md)** (project-wide); do not rely on the Dashboard SQL editor as the main way to change schema.

**Delivery flow:** after significant updates, agents should **ask** whether to push to GitHub; Supabase **`db push`** only if migrations changed, **`functions deploy`** only if Edge Function code changed. Details: **[`../AGENTS.md`](../AGENTS.md)** (*Delivery workflow*).

**Current target:** web-first delivery for now; mobile-specific polish/validation is a later phase.

## Design system (non-negotiable)

1. **Colours**
   - **All hex literals** live in [`lib/theme/app_colors.dart`](lib/theme/app_colors.dart) (brand + dark surface ramp).
   - **Screens and widgets** use `Theme.of(context).colorScheme` (and `AppColors` only where the gallery shows a token not on `ColorScheme`, e.g. `accentLime`).
   - Do not add `Color(0xFF…)`, `Colors.*` for product UI, or one-off `withOpacity` without a named token in [`lib/theme/app_theme.dart`](lib/theme/app_theme.dart).

2. **Layout, spacing, radii, type rhythm**
   - Use **`AppTheme`** constants for `SizedBox`, `EdgeInsets`, corner radii (`fieldRadius`, `radiusSm`, `radiusMd`, `cardRadius`, `stadiumRadius`), letter-spacing (`letterWordmark`, `letterStepCaps`, …), opacities (`opacityPrimaryBorder`, …), icon sizes (`iconDense`, `iconHero`, …), and line heights (`bodyLineHeightRelaxed`, `bodyLineHeightTight`).
   - Prefer **`AppTheme.screenPadding`** / **`AppTheme.pageHorizontal`** for page edges and sheets.

3. **Forms**
   - Global field chrome is defined in **`AppTheme.dark()` → `inputDecorationTheme`**. Pass only what differs: `hintText`, `labelText`, `prefixIcon` / **`suffixIcon`** (not `suffix` for icon buttons), validators.
   - Do not duplicate filled/outline border `InputDecoration` blocks in screens.

4. **Components**
   - Prefer Material 3: `Card`, `FilledButton`, `SearchBar`, `Chip`, `TabBar`, etc., as themed in `AppTheme`.
   - The only approved custom widget today is **`OutlinedSurfaceCard`**. Add new shared widgets only after explicit agreement (document in README when you do).

5. **Typography**
   - **Lexend** comes from the theme (`google_fonts`). Use `Theme.of(context).textTheme` roles; avoid raw `fontSize:` unless you are mirroring a token (prefer `textTheme` + `copyWith`).

6. **Preview**
   - **Style guide & components** in the app mirrors tokens and patterns; keep it updated when you add new categories of UI.

## Key files

| Area | File |
|------|------|
| Brand + surface hex | `lib/theme/app_colors.dart` |
| `ThemeData`, spacing, input/search themes | `lib/theme/app_theme.dart` |
| Living UI reference | `lib/screens/component_gallery_screen.dart` |
| Accent card | `lib/widgets/outlined_surface_card.dart` |
| Wordmark | `lib/widgets/brand_wordmark.dart` |
| In-round hole + event sheet | `lib/screens/hole_scoring_screen.dart` |
| End-of-round summary | `lib/screens/round_summary_screen.dart` |
| Player timeline | `lib/screens/player_breakdown_screen.dart` |
| History list + empty | `lib/screens/history_screen.dart` |
| History round detail | `lib/screens/history_detail_screen.dart` |
| Past-round DTOs (demo) | `lib/models/history_round.dart` |

## Cursor

Repo-level rule: [`.cursor/rules/golf-bits-flutter-ui.mdc`](../.cursor/rules/golf-bits-flutter-ui.mdc) (applies when editing `golf_bits/lib/**/*.dart`).
