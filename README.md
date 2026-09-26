# gramX

An Android client for Telegram channels, laid out like a timeline rather than
a chat list.

gramX signs in to your Telegram account through [TDLib](https://core.telegram.org/tdlib)
and shows the channels you follow as one feed: posts, comments, reactions,
media, polls and quoted replies. It is
not made by, affiliated with, or endorsed by Telegram.

## What it does

- **Feed.** Every channel you follow, newest first, with folders as tabs,
  unread tracking that stays in step with your other Telegram clients, and
  threads drawn as threads.
- **Channels.** A profile per channel with posts, media, files and links tabs,
  and statistics for channels you own or administer.
- **Messages.** Direct messages and groups, with replies, forwards, pins,
  search, scheduled messages and the message kinds Telegram supports.
- **Compose.** Post to the channels you run: text, photos, videos, files,
  polls, stickers, voice and round-video messages, locations.
- **Activity.** Mentions, replies and reactions in one place, with system
  notifications drawn from what TDLib already decided to notify about.
- **Guest mode.** Read public channels without an account, from the same
  `t.me/s/<channel>` pages a browser would fetch.
- **Links.** `t.me` and `tg://` links open inside the app, and a share from
  another app lands in the composer.
- **Bookmarks, search and explore.**

## Privacy

gramX has no servers of its own. Signed in or as a guest, it talks to
Telegram and to nobody else, and everything it keeps stays on the phone.
TDLib's local database is encrypted with a key kept in the platform's
secure storage.
The privacy policy and terms ship inside the app, under Settings, and are
written to describe what the code actually does.

## Building

Requirements:

- Flutter 3.47 or later (Dart 3.11.5 or later)
- Android SDK and NDK, JDK 17
- A Telegram API id and hash from <https://my.telegram.org> (API development
  tools)

Then:

```bash
cp lib/core/config/app_config.example.dart lib/core/config/app_config.dart
```

Fill in `apiId` and `apiHash` in the copy. The file is ignored by git, so the
credentials never leave your machine.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Android is the only supported platform: the TDLib binaries come from
[`handy_tdlib`](https://pub.dev/packages/handy_tdlib), which ships them for
Android alone. The `ios/` directory is the Flutter scaffold and does not build
a working app.

### Tests

```bash
flutter test
```

The suite is pure Dart and widget tests; nothing in it needs a device or a
Telegram account.

### Release builds

Release builds are signed with a keystore that is kept out of the repository.
Copy `android/key.properties.example` to `android/key.properties`, point it at
your keystore, and build:

```bash
flutter build apk --release
```

Without `key.properties` the build still succeeds but is signed with the debug
key, and Gradle prints a warning saying so. Do not distribute that build: a
device that installs it cannot take an update signed with the real key.

The version lives in `pubspec.yaml` (`version: x.y.z+build`) and is read from
there by both the Android build and the app itself.

## How the code is organised

```
lib/
  app/             MaterialApp, router, theme, shared chrome
  core/            config, strings, navigation, diagnostics, shared widgets
  features/<name>/ data / domain / presentation for each screen family
  infrastructure/  TDLib service, chat cache, sync, storage
test/              mirrors lib/
```

A few conventions run through the code and are checked by tests:

- **Every user-facing string lives in `lib/core/l10n/app_strings.dart`.** A
  test fails on a literal inside a widget.
- **The request budget.** TDLib's update stream is free; requests are not.
  Nothing loops a request over the chat list, nothing fetches per row of a
  list, and a typed search reaches TDLib only after a debounce. Anything
  networked is driven by one deliberate tap and answers one bounded page.
- **A control that renders must do something.** If an action is not available,
  the control is hidden or explains itself; it is never drawn and inert.
- **State carried by shape alone gets a label.** Ticks, badges and arrows are
  labelled for screen readers.
- **Pure logic is split from I/O** so the decisions with a wrong answer can be
  tested without a TDLib client.

## Support

If gramX is useful to you, the developer can be supported at
<https://gurshaplus.com/ragoose>.
