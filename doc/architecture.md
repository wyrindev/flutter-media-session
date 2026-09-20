# Architecture & Design Decisions

This document outlines the internal architecture, lifecycle mechanics, platform implementations, and API design philosophy of `flutter_media_session`.

---

## 1. Architectural Overview

`flutter_media_session` follows the standard Flutter federated plugin pattern to cleanly separate the public API, platform interfaces, and native platform bindings:

```
┌────────────────────────────────────────────────────────┐
│               Application / Audio Player               │
└───────────────────────────┬────────────────────────────┘
                            │ (Adapter Pattern)
┌───────────────────────────▼────────────────────────────┐
│          flutter_media_session (Public Dart API)       │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│      flutter_media_session_platform_interface          │
└─────────────┬────────────────────────────┬─────────────┘
              │ (MethodChannel)            │ (JS / W3C)
┌─────────────▼─────────────┐ ┌────────────▼─────────────┐
│ Native Mobile & Desktop   │ │           Web            │
│  - Android (Media3)       │ │ (HTML5 MediaSession API) │
│  - Darwin (iOS / macOS)   │ └──────────────────────────┘
│  - Windows (SMTC)         │
└───────────────────────────┘
```

1. **App / Player Layer**: Audio playback libraries (e.g. `just_audio`, `media_kit`, `audioplayers`, or custom audio engines).
2. **Adapter Layer**: Bridges the player state and metadata streams with `flutter_media_session` without hard dependencies.
3. **Public API (`flutter_media_session`)**: Exposes lifecycle control, metadata models, playback state synchronizers, and action streams.
4. **Platform Interface**: Enforces contract boundaries across all target platforms.
5. **Platform Implementations**: Native channels for Android, iOS/macOS, Windows, and Web.

---

## 2. Design Rationale: Decoupled Adapter Architecture

Integrating media session controls directly with audio engines often creates tight coupling and dependency challenges:
- **Audio Engine Independence**: Applications frequently use different playback engines (such as `just_audio`, `media_kit`, `audioplayers`, or custom platform channels). Hardcoding an engine dependency in the session plugin introduces unnecessary dependencies for projects using alternative players.
- **Dependency Isolation**: Separating playback and session layers prevents version constraint conflicts across dependencies.
- **Flexible Data Mapping**: Applications often maintain distinct metadata representations (e.g. streaming tokens, track IDs, chapter markers). An adapter pattern allows flexible mapping between internal application models and platform session requirements.

### Implementation
`flutter_media_session` uses a lightweight `MediaSessionAdapter` contract:
- The core plugin remains strictly agnostic of the audio player implementation.
- Ready-to-use adapter implementations are provided for popular Flutter players.
- Developers can fully customize how player streams map to session metadata and playback actions.

---

## 3. Lifecycle & System State Management

Media sessions represent a shared operating system resource. Proper lifecycle management ensures seamless playback transitions and avoids resource contention.

### Activation Flow
```
App requests playback
   │
   ├──> `FlutterMediaSession.activate()`
   │      ├── Requests audio focus / system media slot
   │      ├── Registers system media event handlers
   │      └── Initializes notification / flyout controls
   │
   ├──> `FlutterMediaSession.setMetadata(...)`
   └──> `FlutterMediaSession.setPlaybackState(...)`
```

### Deactivation & Teardown Flow
```
Playback completes / stopped
   │
   └──> `FlutterMediaSession.deactivate()`
          ├── Clears lock screen metadata & artwork caches
          ├── Dismisses system notification / flyout
          ├── Releases audio focus / audio session category
          └── Tears down event listener channels
```

---

## 4. Platform Internals

### Android
- **Underlying Framework**: AndroidX Media3 / `MediaSessionCompat`.
- **System Integration**:
  - Automatically manages foreground service lifecycles to comply with modern Android background execution limits (API 26+ / API 34+).
  - Generates system notification channel with `MediaStyle` notification.
  - Supports custom notification action buttons with custom icons and action keys.
  - Handles audio focus ducking, pauses on noisy events (e.g. headphones unplugged), and audio focus loss.

### Apple (iOS & macOS)
- **Underlying Framework**: `MediaPlayer` (`MPNowPlayingInfoCenter` & `MPRemoteCommandCenter`) and `AVFoundation` (`AVAudioSession`).
- **System Integration**:
  - Coordinates with `MPNowPlayingInfoCenter` to project title, artist, album, duration, elapsed playback time, and playback rate to the iOS Lock Screen, Dynamic Island, and macOS Control Center.
  - Registers handlers with `MPRemoteCommandCenter` for remote command dispatching (play, pause, toggle, skip, seek).
  - Requires `UIBackgroundModes: audio` in `Info.plist` for uninterrupted background control.

### Windows
- **Underlying Framework**: Windows Runtime (WinRT) `SystemMediaTransportControls` (SMTC).
- **System Integration**:
  - Couples to the Flutter window's HWND to display media controls in the Windows Volume Flyout / Taskbar preview.
  - Supports display updater metadata (music properties) and timeline properties for progress tracking.
  - Supports proper Application User Model ID (AUMID) binding to display correct application branding instead of "Unknown Application".

### Web
- **Underlying Framework**: W3C Media Session API (`navigator.mediaSession`).
- **System Integration**:
  - Binds metadata into browser media notifications (e.g. Chrome Global Media Controls).
  - Registers action handlers via `navigator.mediaSession.setActionHandler` for standard playback commands.
