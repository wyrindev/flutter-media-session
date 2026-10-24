## 3.1.0

### Features

* **Android**: Added `ActionSlotLayout` and `setActionLayout` to customize media notification button ordering (`symmetrical` and `sequential` presets) and compact view slots.

### Improvements

* **Android**: Cleaned up duplicate media button and action registration logs.
* **Example**: Added action slot layout configuration in the settings panel.

---

## 3.0.9

### Bug Fixes

* **Android**: Removed redundant `onStartCommand` media button handling in `FlutterMediaSessionService` to eliminate duplicate event dispatch and prevent state decoupling between the service notification and player callback.

---

## 3.0.8

### Documentation

* Added library documentation comments and explicit constructor documentation across public API elements.
* Fixed unresolved doc references and refined comment formatting for pub.dev analysis.

---

## 3.0.7

### Bug Fixes

* **Android**: Cleaned up legacy media button routing and explicitly canceled notifications on deactivation to ensure complete dismissal.

---

## 3.0.6

### Bug Fixes

* **Android**:
  * Added `MediaButtonRoutingCompat` audio track hook to ensure OS hardware media button dispatch routes to the active session UID.
  * Enhanced `MediaButtonReceiver` and `FlutterMediaSessionService` foreground lifecycle and media button event routing.
  * Added consumer ProGuard rules (`consumer-rules.pro`) for Android media button compatibility classes.

---

## 3.0.5

### Bug Fixes

* **Android**:
  * Registered explicit `MediaButtonReceiver` `PendingIntent` onto legacy `SessionCompat` to ensure hardware media buttons are routed to the session.
  * Started `FlutterMediaSessionService` via `ContextCompat.startForegroundService` to keep background media controls reliable.
* **Windows**:
  * Fixed an Access Violation crash (`0xc0000005`) in `updateMetadata` when using local artwork paths with `seekTo` enabled by passing variables as by-value coroutine parameters.
  * Handled `Stop`, `FastForward`, and `Rewind` button events in SMTC `ButtonPressed` callbacks.

### Improvements

* **Example**:
  * Displayed application version in the AppBar using `package_info_plus`.
  * Added `stop` action handling and simplified platform-specific settings.

---

## 3.0.4

### Bug Fixes

* **Android**:
  * Fixed lingering notifications and zombie media controls on deactivation, and ensured state recovery upon re-activation.
  * Directly intercepted and dispatched `ACTION_DOWN` media button events (play, pause, next, previous, stop) to Flutter in `onMediaButtonEvent`.
  * Automatically deactivated and released media session resources when the Flutter engine detaches.
* **Example**: Re-bound adapter on activation and auto-resumed playback after `seekTo`.

---

## 3.0.3

### Bug Fixes

* **Android**: Fixed hardware media button interactions by updating `MediaButtonReceiver` to Media3 (`androidx.media3.session.MediaButtonReceiver`), adding `android.intent.action.MEDIA_BUTTON` to the service intent-filter, and overriding `onMediaButtonEvent` in `CustomMediaSessionCallback`.

### Improvements

* Re-exported `flutter_media_session_platform_interface.dart` directly from `flutter_media_session.dart`, allowing custom `MediaSessionAdapter` implementations with a single import.
* Updated `example/README.md` and `doc/usage.md` snippets to align with 3.x adapter patterns and remove deprecated 2.x API references.

---

## 3.0.2

### Bug Fixes

* **Android**:
  * Fixed missing custom buttons (e.g., Shuffle, Repeat) in release builds by adding resource shrinking keep rules (`keep.xml`) and enhancing drawable resource resolution.
  * Synchronized updated player commands dynamically to active system controllers in `updateAvailableActions`, enabling immediate seek bar updates when toggling `seekTo`.
  * Ignored system seek gestures in `handleSeek` when `MediaAction.seekTo` is disabled.
  * Fixed an issue where background keep-alive (`setBackgroundKeepAlive`) could disconnect when playback was paused on Android 12+ (e.g., while casting to a TV).

---

## 3.0.1

### Bug Fixes

* **Example**:
  * Added `<uses-permission android:name="android.permission.INTERNET" />` and `android:usesCleartextTraffic="true"` to `example/android/app/src/main/AndroidManifest.xml`.
  * Restored reliable public sample audio URLs (`soundhelix.com`) and cover images in `example/lib/main.dart`.

---

## 3.0.0

This release consolidates the Adapter Pattern API, introduces off-device casting background keep-alive, resolves platform compiler warnings, and removes the deprecated legacy direct-sync APIs from the public class interface.

### Features

* **Background Keep-Alive (`setBackgroundKeepAlive`)**: An opt-in API that keeps backgrounded sessions alive when audio is rendered off-device (e.g., Chromecast/DLNA). Off by default; uses the best available primitive per platform:
  * **Android**: Partial wake lock (CPU) + high-performance Wi-Fi lock (radio), under `mediaPlayback|connectedDevice` foreground service type.
  * **macOS**: `IOPMAssertion` to prevent idle system sleep.
  * **Windows**: `SetThreadExecutionState` to prevent system sleep.
  * **Web**: Best-effort Screen Wake Lock.
  * **iOS**: No-op (depends on native audio playback).
* **Android**: Dynamically detects the Android Gradle Plugin (AGP) version to support both older KGP versions and the new built-in Kotlin mechanism in AGP 9.0+, preventing compile errors and JVM target mismatches.
* **Darwin**: Improved thread safety, resource management, and error handling in `MediaSessionManager`.
* iOS/macOS repeat/shuffle synchronization via `changeShuffleModeCommand` / `changeRepeatModeCommand`.
* Customizable skip intervals (`setSkipIntervals`).
* Synchronized `shuffleModeEnabled` with Media3's `SimpleBasePlayer` state on Android.

### Breaking Changes

* Removed deprecated legacy direct-sync APIs from the public `FlutterMediaSession` class: `updateMetadata`, `updatePlaybackState`, `updateAvailableActions`, `onMediaAction`, and `requestNotificationPermission`. Use `FlutterMediaSessionPlatform.instance` for direct manual updates.
* Removed deprecated `setHandlesInterruptions` in favor of `setAutoHandleInterruptions`.
* Refactored `JustAudioMediaSessionAdapter` and `MediaKitMediaSessionAdapter` to update state directly via `FlutterMediaSessionPlatform.instance`.

### Bug Fixes

* **Example**: Fixed reload bug by resetting the loaded URL when deactivating the media session.

---

## 2.3.0

### Features

* **iOS / macOS**: Registered native `changeShuffleModeCommand` and `changeRepeatModeCommand` to sync repeat and shuffle modes.
* **iOS / macOS**: Added customizable skip intervals for rewind and fast-forward commands (`setSkipIntervals`).
* **Android**: Synchronized `shuffleModeEnabled` with Media3's `SimpleBasePlayer` state.

### Bug Fixes

* **Example**: Fixed reload bug by resetting the loaded URL when deactivating the media session.

---

## 2.2.0

### Features

* Introduced `MediaSessionAdapter` interface to decouple player implementations from media session controls.
* Provided copy-ready adapter classes for `just_audio` and `media_kit` in `doc/adapters/` and the wiki, keeping the core package free of third-party player dependencies.
* Added lifecycle state management: `Idle` → `Active` → `Bound` → `Unbound` → `Deactivated`.

### Improvements

* **API**: Renamed `setHandlesInterruptions` to `setAutoHandleInterruptions` across platform interfaces, Android, Windows, and Dart layers.
* **Windows**:
  * Added metadata deduplication caching in C++ to prevent cover art flashing on state changes.
  * Fixed shuffle/repeat button states resetting or locking to "Closed" in the OS UI via robust type parsing and synchronous WinRT callback feedback.
* **Darwin**: Updated `Package.swift` to correctly declare the `FlutterFramework` dependency, resolving iOS/macOS compiler warnings.

### Deprecations

* Marked legacy manual sync APIs as deprecated (`updateMetadata`, `updatePlaybackState`, `updateAvailableActions`, `onMediaAction`). Scheduled for removal in `3.0.0`.

---

## 2.1.3

### Features

* Added `MediaAction.shuffle` and `MediaAction.repeat` for native shuffle and repeat toggles.

### Improvements

* **Windows**:
  * Enhanced artwork handling for local file paths (converting to `file://` URIs).
  * Improved timeline synchronization to prevent progress bar drift in system controls.
  * Added native Shuffle and Repeat button support in SMTC.
  * Added safety checks and error handling for SMTC updates.
* **Android**: Refined custom action rendering and fixed potential slider rendering issues.
* **Example**: Modularized UI components and implemented a "ping-pong" player strategy for smoother track transitions on Windows.

---

## 2.1.2

### Bug Fixes

* Fixed version number in README.

---

## 2.1.1

### Bug Fixes

* Fixed version number in README.

---

## 2.1.0

### Features

* **Android**: Added support for custom notification buttons (e.g., Like, Shuffle) via Media3.
  * Extended `MediaAction` with custom labels and Android drawable resources.
  * `MediaSessionService` now dynamically updates custom layout commands.
  * Added input validation and size-limited caching for custom action parameters.
* **iOS / macOS**: Added support for `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.
* **Android**: Added `setHandlesInterruptions(bool)` for automatic audio focus handling during calls or interruptions.
* **Windows**: Resolved the "Unknown Application" display issue using dynamic AUMID registration and Start Menu shortcut creation.

### Bug Fixes

* **Android**: Exposed playback state via accessor for better integration with custom services (PR #16).
* **Windows**: Improved COM lifecycle management and path traversal handling.
* **Example**: Fixed a `Slider` rendering assertion failure when durations were zero or negative.
* **Web**: Improved `updateAvailableActions` parity.

### Improvements

* Updated documentation and example app to demonstrate new platform features.

---

## 2.0.0

### Features

* Added `updateAvailableActions` API to dynamically toggle system media controls (Play, Pause, Skip, Seek, etc.).

### Improvements

* Improved Web Media Session playback buffering and synchronized seeking logic.
* Enhanced debounced seeking strategy across all platforms.
* Improved documentation and fixed cross-platform link consistency.

### Bug Fixes

* Fixed Android and Windows media progress bar synchronization with advanced position extrapolation.

---

## 1.0.0

Initial release.

* Support for Android (Media3), Windows (SMTC), and Web (Media Session API).
* Synchronize track metadata (title, artist, album, artwork).
* Synchronize playback states (playing, paused, position, speed).
* Receive media actions (play, pause, next, previous) from system controls.