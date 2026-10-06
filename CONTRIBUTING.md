# Working on gramX

This is the developer guide. For what the app is and how to install it, see
the [README](README.md).

## Requirements

- Flutter 3.47 or later (stable channel), which brings Dart 3.11
- For Android: the Android SDK and NDK, and JDK 17
- For iOS: Xcode, CocoaPods and CMake (`brew install cmake`)
- A Telegram API id and hash, from <https://my.telegram.org> under
  "API development tools"

TDLib, the library that talks to Telegram, comes from
[`handy_tdlib`](https://pub.dev/packages/handy_tdlib) on Android. It ships no
iOS build, so the iOS app embeds its own, built from source. Before the first
iOS build, run:

```bash
tool/build_tdlib_ios.sh
```

It builds the TDLib version handy_tdlib was generated from, with OpenSSL, for
iPhones and for the simulator on Apple silicon, into
`ios/Frameworks/tdjson.xcframework`. That takes a few minutes and the result
is ignored by git. When handy_tdlib moves to a new TDLib, update `TD_COMMIT`
in the script to match and run it again.

## Setup

Copy the config template and fill in your `apiId` and `apiHash`:

```bash
cp lib/core/config/app_config.example.dart lib/core/config/app_config.dart
```

`app_config.dart` is ignored by git, so your credentials stay on your machine.
Every app that uses the Telegram API needs its own id and hash; please don't
ship someone else's.

Then:

```bash
flutter pub get
flutter run
```

Generated code (`*.g.dart`, `*.freezed.dart`) is committed. After changing a
model, table or anything annotated for code generation, regenerate it:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Checks

Run these before opening a pull request:

```bash
dart format lib test
flutter analyze
flutter test
```

The tests are plain Dart and widget tests. None of them needs a device or a
Telegram account.

## Release builds

Release builds are signed with a keystore kept outside the repository. Copy
`android/key.properties.example` to `android/key.properties`, point it at
your keystore, and build:

```bash
flutter build apk --release --split-per-abi
```

Without `key.properties` the build is signed with the debug key and Gradle
warns about it. Don't distribute that build: phones that install it can't
take an update signed with the real key.

For iOS, put your Apple team id in `ios/Flutter/Signing.xcconfig`, which git
ignores, so your team stays out of the repository:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

Both the app and its share extension read it. That is enough for
`flutter run` on an iPhone, and for a release:

```bash
flutter build ipa
```

A few things work differently on iOS:

- **Voice messages.** Telegram sends and expects Opus in OGG, which Apple's
  audio frameworks don't read. `lib/core/audio/opus_container.dart` moves
  the audio into CAF for playback and back into OGG after recording, without
  re-encoding.
- **Sharing.** `ios/ShareExtension` puts gramX in the share sheet. It opens
  the app with `gramx://share?text=…`, so it needs no app group. A shared
  Telegram link opens in gramX; anything else opens the composer.
- **Links.** `tg://` links open the app. `t.me` links can't open it directly,
  since that would need t.me to list the app in its
  `apple-app-site-association`, so they come in through the share sheet.

The version comes from `pubspec.yaml` (`version: x.y.z+build`), which both
the Android build and the app read.

## Website

The website is plain HTML, CSS and JavaScript in `docs/`, published with
GitHub Pages. There is no build step. To preview it locally:

```bash
python3 -m http.server --directory docs
```

The download buttons look up the latest GitHub release when the page loads,
so publishing a release is enough and the page needs no edit. They find the
APKs by the `arm64-v8a`, `armeabi-v7a` and `x86_64` in their file names, so
keep those in the names of release assets. Visitors who can't reach GitHub's
API get the version in `FALLBACK_VERSION` in `docs/site.js`; bump it with
each release.

The site's privacy policy and terms are generated from
`lib/core/l10n/legal_text.dart`. After changing that file, run:

```bash
dart run tool/site_legal.dart
```

## Code layout

```
lib/
  app/             app shell, router, theme, shared widgets
  core/            config, strings, navigation, diagnostics, shared widgets
  features/<name>/ data, domain and presentation for each part of the app
  infrastructure/  TDLib service, chat cache, sync, local storage
test/              mirrors lib/
```

## Conventions

- **Strings.** Every user-facing string lives in
  `lib/core/l10n/app_strings.dart`. A test fails on a string literal inside a
  widget.
- **Requests.** Telegram rate-limits accounts, and the penalty lands on the
  user. TDLib's update stream is free; requests are not. Don't send a request
  per chat or per list row, debounce anything driven by typing, and read from
  TDLib's local database before asking the server.
- **Controls.** A control that is shown must work. If an action isn't
  available, hide it or explain why.
- **Accessibility.** Anything that carries meaning only by its shape (ticks,
  badges, arrows) gets a label for screen readers.
- **Testable logic.** Keep decisions in pure functions or small classes,
  apart from TDLib calls, so they can be tested without a client.
- **Commits.** `type(scope): summary`, for example `fix(feed): ...` or
  `feat(chats): ...`, with a body when the reason isn't obvious.

## Pull requests

Issues and pull requests are welcome. For anything large, open an issue first
so we can agree on the approach. By sending a pull request you agree that
your contribution is licensed under the [Apache License 2.0](LICENSE), like
the rest of the project.

## Forks

You're free to fork gramX and build on it under the Apache License 2.0. Keep
the [NOTICE](NOTICE) file and its credit, and give your app its own name and
logo: the gramX name and logo are not covered by the license.
