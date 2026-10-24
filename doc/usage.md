# Usage Guide

This guide covers how to use `flutter_media_session` to sync media metadata and playback state with OS media hubs, handle remote transport commands, and configure platform-specific behaviors.

---

## 1. Player Adapters

The recommended approach is to implement `MediaSessionAdapter`, which keeps playback engine events separate from media session synchronization.

Ready-to-use adapter implementations and guides are provided for:
- **[`just_audio` Adapter Guide](adapters/just_audio.md)**: Full adapter code with queue tracking, stream subscriptions, and lifecycle management for `just_audio`.
- **[`media_kit` Adapter Guide](adapters/media_kit.md)**: Full adapter code with playlist position tracking and rate synchronization for `media_kit`.

---

## 2. Implementing a Custom Adapter

To integrate a player (e.g. `audioplayers`, `video_player`, or a proprietary audio pipeline), implement the `MediaSessionAdapter` interface:

```dart
import 'dart:async';
import 'package:flutter_media_session/flutter_media_session.dart';

class CustomPlayerAdapter implements MediaSessionAdapter {
  final MyPlayer player;
  final List<StreamSubscription> _subscriptions = [];
  FlutterMediaSession? _session;

  CustomPlayerAdapter(this.player);

  @override
  void bind(FlutterMediaSession session) {
    _session = session;

    // 1. Synchronize metadata changes
    _subscriptions.add(player.trackStream.listen((track) {
      FlutterMediaSessionPlatform.instance.updateMetadata(
        MediaMetadata(
          title: track.title,
          artist: track.artist,
          album: track.album,
          artworkUri: track.coverUrl,
          duration: track.duration,
        ),
      );
    }));

    // 2. Synchronize playback status and timeline
    _subscriptions.add(player.statusStream.listen((status) {
      FlutterMediaSessionPlatform.instance.updatePlaybackState(
        PlaybackState(
          status: status == MyStatus.playing
              ? PlaybackStatus.playing
              : PlaybackStatus.paused,
          position: player.currentPosition,
          speed: player.playbackRate,
          bufferedPosition: player.bufferedPosition,
          repeatMode: player.isLooping ? MediaRepeatMode.one : MediaRepeatMode.none,
          shuffleModeEnabled: player.isShuffle,
        ),
      );
    }));

    // 3. Receive system transport commands
    _subscriptions.add(
      FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
        switch (action.name) {
          case 'play':
            player.play();
            break;
          case 'pause':
            player.pause();
            break;
          case 'stop':
            player.stop();
            break;
          case 'seekTo':
            if (action.seekPosition != null) {
              player.seek(action.seekPosition!);
            }
            break;
          case 'skipToNext':
            player.next();
            break;
          case 'skipToPrevious':
            player.previous();
            break;
        }
      }),
    );
  }

  @override
  void unbind() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _session = null;
  }
}
```

Bind and unbind the adapter to your session:

```dart
final session = FlutterMediaSession();
await session.activate();

final adapter = CustomPlayerAdapter(myPlayer);
session.bind(adapter);

// When tearing down or switching players:
session.unbind();
```

---

## 3. High-Level Action Handling (`setActionHandler`)

If you are not using a full `MediaSessionAdapter` class, you can register high-level action callbacks directly on the `FlutterMediaSession` singleton. This avoids manually listening to and parsing `FlutterMediaSessionPlatform.instance.onMediaAction`:

```dart
final session = FlutterMediaSession();

session.setActionHandler(
  onPlay: () => player.play(),
  onPause: () => player.pause(),
  onStop: () => player.stop(),
  onSeekTo: (position) => player.seek(position),
  onSkipToNext: () => playlist.next(),
  onSkipToPrevious: () => playlist.previous(),
  onRewind: () => player.seek(player.position - const Duration(seconds: 10)),
  onFastForward: () => player.seek(player.position + const Duration(seconds: 10)),
  onShuffle: () => player.toggleShuffle(),
  onRepeat: () => player.toggleRepeat(),
);

// Clear callbacks when no longer needed:
session.clearActionHandler();
```

---

## 4. Session Lifecycle Management

Session state maps directly to what the OS shows (background services, lock screen widgets, system resources):

```
[ Idle ] ── session.activate() ──> [ Active (Service / SMTC Live) ]
                                          │
                                 session.bind(adapter)
                                          │
                                          ▼
                                 [ Bound (Auto Syncing) ]
                                          │
                                 session.unbind()
                                          │
                                          ▼
[ Idle ] <── session.deactivate() ── [ Active ]
```

- **`activate()`**:
  - **Android**: Starts `FlutterMediaSessionService` as a foreground service with `mediaPlayback|connectedDevice` types and creates the notification channel. Automatically prompts for `POST_NOTIFICATIONS` permission on Android 13+ (API 33+).
  - **iOS**: Activates `AVAudioSession` with the `.playback` category and registers targets on `MPRemoteCommandCenter`.
  - **macOS**: Registers command targets with `MPRemoteCommandCenter`.
  - **Windows**: Obtains `SystemMediaTransportControls` for the application window HWND via `ISystemMediaTransportControlsInterop` and enables default controls.
  - **Web**: Registers command handlers on `window.navigator.mediaSession`.
- **`deactivate()`**:
  - Cancels high-level action handlers registered via `setActionHandler()`.
  - **Android**: Stops the foreground service, dismisses the system notification, and unbinds the Media3 session.
  - **iOS/macOS**: Clears now-playing info, releases power assertions, and removes remote command handlers.
  - **Windows**: Disables SMTC and resets timeline properties.
  - **Web**: Resets `navigator.mediaSession.playbackState` to `'none'`.

---

## 5. Direct State & Action APIs

For low-level control or standalone synchronization without an adapter, interact directly with `FlutterMediaSessionPlatform.instance`:

```dart
// 1. Update metadata
await FlutterMediaSessionPlatform.instance.updateMetadata(
  const MediaMetadata(
    title: 'Track Title',
    artist: 'Artist Name',
    album: 'Album Title',
    artworkUri: 'https://example.com/artwork.jpg', // HTTP URL or local absolute path
    duration: Duration(minutes: 4, seconds: 12),
  ),
);

// 2. Update playback state
await FlutterMediaSessionPlatform.instance.updatePlaybackState(
  const PlaybackState(
    status: PlaybackStatus.playing,
    position: Duration(seconds: 30),
    speed: 1.0,
    bufferedPosition: Duration(seconds: 60),
    repeatMode: MediaRepeatMode.all,
    shuffleModeEnabled: true,
  ),
);

// 3. Restrict enabled system buttons (null enables all supported buttons)
await FlutterMediaSessionPlatform.instance.updateAvailableActions({
  MediaAction.play,
  MediaAction.pause,
  MediaAction.skipToNext,
  MediaAction.skipToPrevious,
  MediaAction.seekTo,
});

// 4. Raw stream of media actions
FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
  print('Received action: ${action.name}, seek: ${action.seekPosition}');
});
```

---

## 6. Platform-Specific Configuration

### Action Slot Layout (Android Notification & System Controls)

On Android, action buttons in the `MediaStyle` notification and Android 11+ quick settings media card can be arranged using `ActionSlotLayout`. On other platforms, setting a layout registers and enables the transport buttons included in the layout.

```dart
// Symmetrical layout (Spotify / Modern layout):
// Order: [leftCustom, skipPrevious, playPause, skipNext, rightCustom]
// Compact view (collapsed notification) displays: [skipPrevious, playPause, skipNext]
await session.setActionLayout(
  ActionSlotLayout.symmetrical(
    left: MediaAction.custom(
      name: 'repeat',
      customLabel: 'Repeat',
      customIconResource: 'ic_repeat_all',
    ),
    skipPrevious: MediaAction.skipToPrevious,
    playPause: MediaAction.play,
    skipNext: MediaAction.skipToNext,
    right: MediaAction.custom(
      name: 'shuffle',
      customLabel: 'Shuffle',
      customIconResource: 'ic_shuffle_on',
    ),
  ),
);

// Sequential layout (Left-to-right standard order):
// Order: [skipPrevious, playPause, skipNext, custom1, custom2]
await session.setActionLayout(
  ActionSlotLayout.sequential(
    skipPrevious: MediaAction.skipToPrevious,
    playPause: MediaAction.play,
    skipNext: MediaAction.skipToNext,
    custom1: favoriteAction,
    custom2: downloadAction,
  ),
);

// Explicit custom layout with specific compact view indices:
await session.setActionLayout(
  const ActionSlotLayout(
    [
      MediaAction.skipToPrevious,
      MediaAction.play,
      MediaAction.skipToNext,
      favoriteAction,
    ],
    compactActionIndices: [0, 1, 2],
  ),
);
```

> **Android Resource Requirement**: Custom actions require drawable resource names matching files in `android/app/src/main/res/drawable*` (e.g. `ic_repeat_all.xml` or `.png`).

### Opting Out of Android Permissions

The plugin's `AndroidManifest.xml` declares `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `WAKE_LOCK`, and `ACCESS_WIFI_STATE` to support off-device casting via `setBackgroundKeepAlive`.

If your application only plays local audio and does not require off-device keep-alive, you can strip these permissions and update the foreground service type using Android Gradle's Manifest Merger in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Strip unused casting/keep-alive permissions -->
    <uses-permission
        android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE"
        tools:node="remove" />
    <uses-permission
        android:name="android.permission.ACCESS_WIFI_STATE"
        tools:node="remove" />

    <application>
        <!-- Update service type to match the retained permissions (Android 14+ compliance) -->
        <service
            android:name="dev.wyrin.flutter_media_session.FlutterMediaSessionService"
            android:foregroundServiceType="mediaPlayback"
            tools:replace="android:foregroundServiceType" />
    </application>
</manifest>
```

> **Android 14+ Notice**: If you remove `FOREGROUND_SERVICE_CONNECTED_DEVICE`, you must also override the `<service>` declaration with `tools:replace="android:foregroundServiceType"` set to `"mediaPlayback"` as shown above. Otherwise, Android 14+ will throw a `SecurityException` at runtime when starting the foreground service.

### Skip Intervals (iOS & macOS)

Configure the step size (in seconds) for rewind and fast-forward remote commands:

```dart
await session.setSkipIntervals(
  forwardSeconds: 15,
  backwardSeconds: 15,
);
```

### Audio Interruption Handling (`setAutoHandleInterruptions`)

```dart
await session.setAutoHandleInterruptions(true);
```

- **Behavior**: When enabled on Android, the plugin requests audio focus (`AUDIOFOCUS_GAIN`) when the state changes to `PlaybackStatus.playing`, and abandons focus on stop/deactivate. Focus loss events are converted into `pause` or `play` actions on the `onMediaAction` stream.
- **When to disable (Default: `false`)**: If your underlying player engine (`just_audio`, `audioplayers`, etc.) already manages Android audio focus, leave this set to `false`. Otherwise, the plugin's focus request will conflict with the player engine within the same application process.
- **When to enable**: Use this when playing through custom pipelines or engines that do not handle OS focus (e.g., bare `fvp` or raw video decoders).
- **Other Platforms**: No-op on iOS, macOS, Windows, and Web (session focus is managed by the OS or audio engine).

### Background Keep-Alive (`setBackgroundKeepAlive`)

For audio streamed or cast off-device (e.g. Google Cast / DLNA sockets), the local audio hardware is idle, leaving the app vulnerable to OS sleep or Doze termination:

```dart
await session.setBackgroundKeepAlive(true);
```

Platform implementation details:
- **Android**: Acquires a `PARTIAL_WAKE_LOCK` and a `WIFI_MODE_FULL_HIGH_PERF` Wi-Fi lock, running under the `connectedDevice` foreground service type.
- **macOS**: Holds an `IOPMAssertion` (`kIOPMAssertionTypePreventUserIdleSystemSleep`) preventing system idle sleep.
- **Windows**: Calls `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)`.
- **Web**: Acquires a Screen Wake Lock via `navigator.wakeLock` (best-effort while tab is active).
- **iOS**: No-op (iOS does not offer runtime CPU keep-alive locks; background longevity requires active local audio playback via `AVAudioSession`).

### Windows AppUserModelID Setup

On Windows, portable or unpackaged `.exe` builds show up as "Unknown Application" in the SMTC volume flyout unless an Application User Model ID (AUMID) and a matching Start Menu shortcut are registered.

Call `setWindowsAppUserModelId` during early initialization:

```dart
if (Platform.isWindows) {
  await session.setWindowsAppUserModelId(
    'Com.Company.MyApp',
    displayName: 'My App Name', // Creates Start Menu shortcut for unpackaged apps
    iconPath: r'C:\path\to\icon.ico', // Optional
  );
}
```

For complete packaging options (MSIX vs. portable vs. Inno Setup / WiX installers), see the dedicated [Windows Setup Guide](windows_setup.md).