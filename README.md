# bits

Mobile app source lives in **[golf_bits/](golf_bits/)** — **Flutter** + **Material 3** + **Supabase**.

Previous Expo/React Native documentation has been removed per project direction.

## Quick start

```bash
cd golf_bits
flutter create . --project-name golf_bits --org com.golfbits --platforms=ios,android,web
flutter pub get
flutter run
```

See [golf_bits/README.md](golf_bits/README.md) for details.

## Online preview (GitHub Pages)

Push to **`main`** after enabling **Pages → GitHub Actions** in the repo settings. The workflow [`.github/workflows/flutter-web-gh-pages.yml`](.github/workflows/flutter-web-gh-pages.yml) builds Flutter Web and publishes a public URL (see `golf_bits/README.md`).

## Connect to GitHub

There is no remote configured yet. Follow **[GITHUB_SETUP.md](GITHUB_SETUP.md)** to create the repo on github.com, add `origin`, and push.
