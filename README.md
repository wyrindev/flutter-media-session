<div align="center">
    <img src="doc/img/banner.png" width="70%" alt="Banner">
</div>

# flutter_media_session

[![pub package](https://img.shields.io/pub/v/flutter_media_session.svg)](https://pub.dev/packages/flutter_media_session)
[![pub points](https://img.shields.io/pub/points/flutter_media_session)](https://pub.dev/packages/flutter_media_session/score)
[![CI](https://github.com/wyrindev/flutter-media-session/actions/workflows/ci.yml/badge.svg)](https://github.com/wyrindev/flutter-media-session/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Web-blue.svg)](https://pub.dev/packages/flutter_media_session)

A Flutter plugin that connects media playback to OS media hubs — Android notifications, iOS Lock Screen & Dynamic Island, macOS Control Center, Windows SMTC, and the Web Media Session API.

The plugin handles metadata and remote command routing only. It does not include an audio engine; you bring your own player (`just_audio`, `media_kit`, `audioplayers`, etc.) and wire it in via an adapter.

## Platform Support

| Platform | Minimum Version |
| :--- | :--- |
| <img src="doc/img/platform/head.svg" alt="Android" width="18" style="vertical-align: middle;"> Android | Android 7.0 (API 24+) |
| <img src="doc/img/platform/apple.svg" alt="Apple" width="18" style="vertical-align: middle;"> iOS | iOS 12.0+ |
| <img src="doc/img/platform/apple.svg" alt="Apple" width="18" style="vertical-align: middle;"> macOS | macOS 10.15+ |
| <img src="doc/img/platform/windows.svg" alt="Windows" width="18" style="vertical-align: middle;"> Windows | Windows 10 1809+ (Build 17763+) |
| Web | Modern Browsers |
| <img src="doc/img/platform/tux.svg" alt="Linux" width="18" style="vertical-align: middle;"> Linux | Planned (MPRIS) |

> For architecture and native backend details (Media3, MediaPlayer, SMTC), see the [Architecture Guide](doc/architecture.md).

## Installation

Run this command:

```bash
flutter pub add flutter_media_session
```

Or add `flutter_media_session` manually to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_media_session: ^3.1.0-pre.3
```

## Platform Prerequisites

### iOS

To keep media controls responsive and receive remote commands while your application is backgrounded, add `UIBackgroundModes` with `audio` to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

> **Note**: While the plugin configures `AVAudioSession` category to `.playback` upon activation, iOS background execution relies on the application actively playing audio through an audio session.

### Android

- **Permissions**: Core permissions (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `POST_NOTIFICATIONS`, `WAKE_LOCK`, and `ACCESS_WIFI_STATE`) are declared in the plugin's `AndroidManifest.xml` and merged automatically by Gradle. (To strip unused casting permissions, see [Opting Out of Permissions](doc/usage.md#opting-out-of-android-permissions).)
- **Android 13+ (API 33+)**: Notification posting requires runtime permission. Calling `FlutterMediaSession().activate()` automatically requests notification permission on Android.
- **Custom Icons**: Custom notification action drawables must exist in your application's `android/app/src/main/res/drawable*` folders.

### Windows

- **Packaged Apps (MSIX)**: When packaged via MSIX, Windows assigns the App User Model ID (AUMID) automatically from the manifest. No configuration required.
- **Unpackaged / Portable Apps**: To display your application's name and icon instead of "Unknown Application" in the volume flyout, refer to the [Windows Setup Guide](doc/windows_setup.md).

### macOS & Web

No configuration required.

## Quick Start

### Approach A: Using a Player Adapter (Recommended)

Adapters handle the stream subscriptions and state mapping between your player and the media session. Ready-to-use adapters for `just_audio` and `media_kit` are available in the docs:

```dart
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:just_audio/just_audio.dart';
// Import your adapter implementation (see doc/adapters/just_audio.md)
import 'just_audio_media_session_adapter.dart';

final player = AudioPlayer();
final session = FlutterMediaSession();

// 1. Activate session (starts Android foreground service, binds SMTC / NowPlaying)
await session.activate();

// 2. Bind adapter to automatically synchronize metadata, playback states, and commands
session.bind(JustAudioMediaSessionAdapter(player));
```

### Approach B: Direct API Usage

You can also push metadata and playback states manually, and receive system actions via high-level callbacks or streams:

```dart
import 'package:flutter_media_session/flutter_media_session.dart';

final session = FlutterMediaSession();

// 1. Activate native session
await session.activate();

// 2. Update media metadata
await FlutterMediaSessionPlatform.instance.updateMetadata(
  const MediaMetadata(
    title: 'Song Title',
    artist: 'Artist Name',
    album: 'Album Title',
    artworkUri: 'https://example.com/cover.jpg',
    duration: Duration(minutes: 3, seconds: 30),
  ),
);

// 3. Update playback state
await FlutterMediaSessionPlatform.instance.updatePlaybackState(
  const PlaybackState(
    status: PlaybackStatus.playing,
    position: Duration(seconds: 45),
    speed: 1.0,
  ),
);

// 4. Handle incoming system media actions
session.setActionHandler(
  onPlay: () => myAudioPlayer.resume(),
  onPause: () => myAudioPlayer.pause(),
  onSeekTo: (position) => myAudioPlayer.seek(position),
  onSkipToNext: () => myPlaylist.next(),
  onSkipToPrevious: () => myPlaylist.previous(),
);
```

## Documentation

- **[Usage Guide](doc/usage.md)**: Full API reference, writing custom adapters, configuring Android notification layouts (`ActionSlotLayout`), audio interruption handling, background keep-alive, and high-level callbacks.
- **[Player Adapter Guides](doc/usage.md#1-player-adapters)**:
  - **[`just_audio` Adapter](doc/adapters/just_audio.md)**: Implementation and binding guide for `just_audio`.
  - **[`media_kit` Adapter](doc/adapters/media_kit.md)**: Implementation and binding guide for `media_kit`.
- **[Windows Setup Guide](doc/windows_setup.md)**: Resolving the "Unknown Application" display name issue via MSIX, Inno Setup, or dynamic runtime shortcut registration.
- **[Architecture & Design Decisions](doc/architecture.md)**: Platform internals, Android Media3 service lifecycles, iOS/macOS `MediaPlayer` integration, Windows SMTC thread dispatching, and Web MediaSession limits.
- **[Release Guide](doc/release.md)**: Verification steps, build checks, and publishing procedures.