<div align="center">
    <img src="doc/img/banner.png" width="70%" alt="Banner">
</div>

# flutter_media_session

[![pub package](https://img.shields.io/pub/v/flutter_media_session.svg)](https://pub.dev/packages/flutter_media_session)
[![pub points](https://img.shields.io/pub/points/flutter_media_session)](https://pub.dev/packages/flutter_media_session/score)
[![CI](https://github.com/wyrindev/flutter-media-session/actions/workflows/ci.yml/badge.svg)](https://github.com/wyrindev/flutter-media-session/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Web-blue.svg)](https://pub.dev/packages/flutter_media_session)

A Flutter plugin for integrating media playback controls and metadata with system-level interfaces (lock screen, notification center, and control centers) across Android, iOS, macOS, Windows, and Web.

This plugin displays media metadata (title, artist, artwork) in system media hubs and handles standard media actions such as Play, Pause, Skip, and Seek.

## Platform Support

| Platform | Minimum Version |
| :--- | :--- |
| <img src="doc/img/platform/head.svg" alt="Android" width="18" style="vertical-align: middle;"> Android | Android 7.0+ (API 24+) |
| <img src="doc/img/platform/apple.svg" alt="Apple" width="18" style="vertical-align: middle;"> iOS | iOS 12.0+ |
| <img src="doc/img/platform/apple.svg" alt="Apple" width="18" style="vertical-align: middle;"> macOS | macOS 10.15+ |
| <img src="doc/img/platform/windows.svg" alt="Windows" width="18" style="vertical-align: middle;"> Windows | Windows 10 1809+ (Build 17763+) |
| Web | Modern Browsers |
| <img src="doc/img/platform/tux.svg" alt="Linux" width="18" style="vertical-align: middle;"> Linux | Planned |

## Features

- 🧩 **Decoupled Adapter Architecture**: Connect any player engine (e.g. `just_audio`, `media_kit`, `audioplayers`) via a unified `MediaSessionAdapter` interface without bundling unnecessary third-party audio packages.
- 🎵 **Metadata & Artwork Synchronization**: Display titles, artists, album names, and artwork across system lock screens and media centers.
- ⏯️ **Playback & Timeline Tracking**: Synchronize playing/paused states, playback speed, and current elapsed position.
- 📡 **Bi-directional Media Commands**: Receive and respond to system controls, including Play, Pause, Stop, Seek, Skip, Shuffle, and Repeat.
- 📶 **Background Keep-Alive**: Maintain playback state and connection stability when the application is backgrounded.
- 🔈 **Audio Focus Handling**: Manage audio focus interruptions and pauses automatically or cooperatively.
- 🎨 **Custom Notification Actions (Android)**: Add custom actions with dedicated icons and keys directly inside system media notifications.

## Installation

Add `flutter_media_session` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_media_session: ^3.0.5
```

> **Note**: Version 3.x is a complete architectural overhaul. If you are upgrading from 1.x or 2.x, refer to the [Migration and Usage Guide](doc/usage.md).

## Setup

### Android, Windows, macOS & Web

No configuration required. (For optional Windows branding customization, see the [Usage Guide](doc/usage.md).)

### iOS

1. **Background Audio**: Add the `audio` background mode to your `Info.plist`:
    ```xml
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
    ```
    This allows system-level controls to interact with your app in the background.

## Quick Start

```dart
import 'package:flutter_media_session/flutter_media_session.dart';

final mediaSession = FlutterMediaSession();

// 1. Activate session
await mediaSession.activate();

// 2. Update metadata
await mediaSession.setMetadata(
  const MediaMetadata(
    title: 'Song Title',
    artist: 'Artist Name',
    album: 'Album Title',
    duration: Duration(minutes: 3, seconds: 30),
  ),
);

// 3. Update playback state
await mediaSession.setPlaybackState(
  const PlaybackState(
    state: MediaPlaybackState.playing,
    position: Duration(seconds: 45),
  ),
);

// 4. Listen to system actions
FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
  if (action == MediaAction.play) {
    // Resume playback
  } else if (action == MediaAction.pause) {
    // Pause playback
  }
});
```

> **Using with existing players?** Check out the ready-to-use adapter implementations for `just_audio`, `media_kit`, and `audioplayers` in the [Usage Guide](doc/usage.md).

## Documentation

- **[Usage Guide](doc/usage.md)**: Detailed API references, Windows AUMID setup, and production player adapters (`just_audio`, `media_kit`, `audioplayers`).
- **[Architecture & Design Decisions](doc/architecture.md)**: Deep dive into the federated structure, adapter rationale, lifecycle management, and platform internals.
- **[Release Guide](doc/release.md)**: Checklist and procedures for dry-run verification, version tagging, and publishing.