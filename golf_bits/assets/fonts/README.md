# Brand fonts (bundling prep)

The app currently loads **Bricolage Grotesque**, **Hanken Grotesk**, and **DM Mono** at runtime via `google_fonts` ([`lib/theme/app_theme.dart`](../../lib/theme/app_theme.dart)).

Before store / offline-hardened releases, bundle the faces used by the theme into this folder and wire them in `pubspec.yaml` + `AppTheme` so runtime fetching can be disabled:

| Family | Weights in use (approx.) |
|--------|---------------------------|
| Bricolage Grotesque | 700, 800 |
| Hanken Grotesk | text theme defaults (400–700) |
| DM Mono | 500 |

Steps when ready:

1. Download OFL files from [Google Fonts](https://fonts.google.com/) (or the [google/fonts](https://github.com/google/fonts) repo).
2. Place `.ttf` / `.otf` files here.
3. Register under `flutter: fonts:` in `pubspec.yaml`.
4. Point `AppTheme` at `fontFamily` / `TextTheme` from bundled families.
5. Set `GoogleFonts.config.allowRuntimeFetching = false` in `main()` for release builds.
