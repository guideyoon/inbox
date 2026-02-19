# URL Inbox

Save links from share sheets and organize them with search, tags, folders, and reminders.

## Features

- Save links from Android/iOS share sheets, clipboard detection, and manual input
- Auto-fetch metadata (title/description/preview image) for saved URLs
- Organize with folders, tags, and read/star/archive states
- Optional cloud sign-in and sync via Supabase

## Current Architecture

- App entry: `lib/main.dart`
- Current implementation keeps UI, state, repository, sync, and metadata fetch logic in a single Dart file
- Native share ingestion is bridged through:
  - Android `MethodChannel` in `android/app/src/main/kotlin/com/example/url_inbox/MainActivity.kt`
  - iOS AppDelegate/Share Extension in `ios/Runner/AppDelegate.swift` and `ios/ShareExtension/ShareViewController.swift`

## Cloud Sync Configuration (Optional)

Cloud features are enabled when Supabase is configured.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `WEB_AUTH_REDIRECT` (web only)

Example:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Development

- Run app: `flutter run`
- Analyze: `flutter analyze`
- Test: `flutter test`

## Release Preparation

- Release checklist: `RELEASE_CHECKLIST.md`
- Privacy policy draft: `PRIVACY_POLICY.md`
