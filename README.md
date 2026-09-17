<div align="center">
  <img src="assets/icon.png" alt="Murrmobile logo" width="120" />
  <h1>Murrmobile</h1>
  <p>A native Flutter client for <a href="https://murrtube.net">murrtube.net</a></p>
</div>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white" alt="Dart" /></a>
</p>

## What is this?

Unofficial app for [murrtube.net](https://murrtube.net). Built in Flutter, reverse-engineered from the site's Inertia.js frontend since there's no public API. Works on iOS, Android, macOS, Linux, Windows, and Web.

## Features

- Browse Trending / Latest / Subscriptions
- HLS video player with quality switching, fullscreen, scrubbing, wakelock
- Search videos, tags, and users with live suggestions
- Comments (view, post, reply, delete)
- User profiles, subscribe/unsubscribe, block/unblock
- Notifications feed
- Upload videos from the app
- Dark / light / AMOLED themes

## Building

You need Flutter 3.12.1 or newer.

```bash
git clone https://gitlab.com/HttpAnimations/Murrmobile-App.git
cd Murrmobile-App
flutter pub get
flutter run
```

Release builds:

```bash
flutter build apk --release        # Android APK
flutter build appbundle --release  # Android AAB
flutter build ios --release        # iOS
flutter build macos --release      # macOS
flutter build linux --release      # Linux
flutter build windows --release    # Windows
```

## Downloads

Prebuilt binaries are on the [releases page](https://github.com/openlyst/Murrmobile-App/releases).

> This is an **unofficial** fan app. Not affiliated with or endorsed by murrtube.net. The Inertia.js protocol the app relies on can change at any time and break things.
>
> Hoping to maybe become part of the official stack one day, but for now this is just a side project.