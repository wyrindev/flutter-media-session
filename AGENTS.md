# AGENTS.md

Agent instructions for working in this repository.

---

## Project Overview

`flutter_media_session` is a Flutter federated plugin. It bridges player engines (`just_audio`, `media_kit`, etc.) to OS media hubs (Android notifications, iOS/macOS lock screen, Windows SMTC, Web MediaSession API) via a metadata and remote command routing layer.

- **No audio engine is included.** The plugin only handles metadata, playback state, and transport commands.
- **Current version**: `3.1.0` (see `pubspec.yaml`)
- **Dart SDK**: `>=3.3.0 <4.0.0` / **Flutter SDK**: `>=3.3.0`

---

## Repository Layout

```
lib/
  flutter_media_session.dart              # Public singleton (FlutterMediaSession)
  flutter_media_session_platform_interface.dart
  flutter_media_session_method_channel.dart
  flutter_media_session_web.dart
  src/
    models/
      media_action.dart                   # MediaAction + static constants
      media_metadata.dart                 # MediaMetadata
      playback_state.dart                 # PlaybackState, PlaybackStatus, MediaRepeatMode
      action_slot_layout.dart             # ActionSlotLayout
    adapters/
      media_session_adapter.dart          # MediaSessionAdapter interface
android/                                  # Kotlin / AndroidX Media3
darwin/                                   # Shared Swift (iOS + macOS)
windows/                                  # C++ / WinRT SMTC
doc/
  usage.md
  architecture.md
  windows_setup.md
  adapters/just_audio.md
  adapters/media_kit.md
  release.md
```

---

## Key API Syntax

### Activate / deactivate

```dart
final session = FlutterMediaSession();   // Singleton — factory returns same instance
await session.activate();
await session.deactivate();
```

`activate()` on Android automatically calls `requestNotificationPermission()` before starting the foreground service. Do **not** call `requestNotificationPermission()` manually.

### Adapter binding

```dart
session.bind(adapter);   // Calls adapter.bind(session) internally; unbinds any previous adapter
session.unbind();        // Cancels subscriptions; does NOT deactivate the session
```

Never call `adapter.bind()` directly — always go through `session.bind()`.

### Direct updates (low-level)

Access via `FlutterMediaSessionPlatform.instance`, **not** `FlutterMediaSession`:

```dart
await FlutterMediaSessionPlatform.instance.updateMetadata(const MediaMetadata(...));
await FlutterMediaSessionPlatform.instance.updatePlaybackState(const PlaybackState(...));
await FlutterMediaSessionPlatform.instance.updateAvailableActions({...});
```

These methods do **not** exist on the public `FlutterMediaSession` class (removed in 3.0.0).

### MediaAction name strings

Action names are plain `String`s matched by `switch` in `setActionHandler`. Use the defined static constants:

| Constant | `name` string |
| :--- | :--- |
| `MediaAction.play` | `'play'` |
| `MediaAction.pause` | `'pause'` |
| `MediaAction.stop` | `'stop'` |
| `MediaAction.skipToNext` | `'skipToNext'` |
| `MediaAction.skipToPrevious` | `'skipToPrevious'` |
| `MediaAction.seekTo` | `'seekTo'` |
| `MediaAction.rewind` | `'rewind'` |
| `MediaAction.fastForward` | `'fastForward'` |
| `MediaAction.shuffle` | `'shuffle'` |
| `MediaAction.repeat` | `'repeat'` |

Custom actions require `name`, `customLabel`, and `customIconResource` — use the factory:

```dart
MediaAction.custom(
  name: 'my_action',
  customLabel: 'My Label',
  customIconResource: 'ic_my_icon',   // Must exist in android/app/src/main/res/drawable*
)
```

### PlaybackState fields

```dart
PlaybackState(
  status: PlaybackStatus.playing,         // required
  position: Duration(seconds: 30),        // default: Duration.zero
  speed: 1.0,                             // default: 1.0
  bufferedPosition: Duration(seconds: 60),// default: Duration.zero
  repeatMode: MediaRepeatMode.none,       // .none / .one / .all — default: .none
  shuffleModeEnabled: false,              // default: false
)
```

`position` and `bufferedPosition` serialize to milliseconds (`positionMs`, `bufferedPositionMs`) over the method channel. Do not pass `Duration` in milliseconds manually.

### ActionSlotLayout

Three constructors:

```dart
// Symmetrical (Spotify-style): [left?, skipPrev, playPause, skipNext, right?]
ActionSlotLayout.symmetrical(left: ..., right: ...)

// Sequential: [skipPrev, playPause, skipNext, custom1?, custom2?]
ActionSlotLayout.sequential(custom1: ..., custom2: ...)

// Explicit
ActionSlotLayout([action1, action2, action3], compactActionIndices: [0, 1, 2])
```

`compactActionIndices` is **inferred automatically** for the two presets when omitted. Pass it explicitly only when the default three-button compact view is not appropriate.

---

## Commit & PR Conventions

Format: `<type>(<platform>): <description>`

- **Types**: `feat`, `fix`, `docs`, `refactor`, `style`, `test`, `chore`
- **Platforms**: `android`, `ios`, `macos`, `windows`, `web`, `all`, `core`

Example: `fix(android): cancel notification on deactivate`

---

## Documentation Conventions

- One `###` section per platform within a feature description when behavior differs.
- Code blocks in docs always use the full import path (`package:flutter_media_session/flutter_media_session.dart`).
- `FlutterMediaSessionPlatform.instance` (not `FlutterMediaSession`) for low-level API examples.
- CHANGELOG entries follow `### Features` / `### Bug Fixes` / `### Improvements` / `### Breaking Changes` / `### Deprecations` with two-space indented bullets and `---` separators between versions.

---

## Platform-Specific Notes

### Android

- Foreground service type declared as `mediaPlayback|connectedDevice`. If stripping `FOREGROUND_SERVICE_CONNECTED_DEVICE`, also override the `<service>` declaration with `tools:replace="android:foregroundServiceType"` set to `"mediaPlayback"` — otherwise Android 14+ throws `SecurityException`.
- Custom action icons must be in `android/app/src/main/res/drawable*`. String is the resource name without extension (e.g., `ic_repeat_all`, not `ic_repeat_all.xml`).
- `setBackgroundKeepAlive(true)` acquires `PARTIAL_WAKE_LOCK` + `WIFI_MODE_FULL_HIGH_PERF`. Both are no-ops unless the permission is declared.

### iOS

- Requires `UIBackgroundModes: audio` in `Info.plist` for background command routing.
- `AVAudioSession` is configured automatically on `activate()`. Do not configure it again externally.

### Windows

- SMTC is obtained per-window via `HWND`. `activate()` must be called after the window is created (i.e., after `runApp`).
- For unpackaged/portable `.exe` builds, call `setWindowsAppUserModelId` before `activate()`. If using MSIX or an installer that creates the shortcut, omit `displayName` to avoid duplicate shortcuts.
- WinRT callbacks fire on thread-pool threads. The plugin dispatches to the Flutter UI thread via `PostMessage`. Do not call Flutter methods from native WinRT callbacks directly.

### Web

- The Screen Wake Lock (`setBackgroundKeepAlive`) is best-effort and revokes when the page loses visibility.
- `updateAvailableActions` controls which browser action handlers are registered. Unregistered actions are silently ignored by the browser.

---

## Linting

`analysis_options.yaml` extends `package:flutter_lints/flutter.yaml`. The `analyzer` excludes `doc/**`, `build/**`, `android/**`, and `windows/**`. Run `flutter analyze` before committing Dart changes.
