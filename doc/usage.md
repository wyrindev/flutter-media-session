# Usage Guide

> The latest documentation and interactive guides are available at **[docs.wyrin.dev/flutter-media-session](https://docs.wyrin.dev/flutter-media-session)**.

---

## 1. Player Adapters

The recommended approach is to implement `MediaSessionAdapter`, keeping playback engine events separate from media session synchronization.

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

Without a full `MediaSessionAdapter`, register action callbacks directly on the singleton to avoid manually parsing `FlutterMediaSessionPlatform.instance.onMediaAction`:

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
  // Android, with a media library (see "Media Library & Android Auto"):
  onPlayFromMediaId: (mediaId) => playlist.playItem(mediaId),
  onPlayFromSearch: (query) => playlist.playMatching(query),
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

For low-level control without an adapter, interact directly with `FlutterMediaSessionPlatform.instance`:

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

### Action Slot Layout (Android)

On Android, action buttons in the `MediaStyle` notification and Android 11+ quick settings media card can be arranged using `ActionSlotLayout`. On other platforms this is a no-op — use `updateAvailableActions` via `FlutterMediaSessionPlatform.instance` to control which controls are enabled.

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

If your app only plays local audio, strip these permissions via Manifest Merger in `android/app/src/main/AndroidManifest.xml`:

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

- **Behavior**: On Android, requests `AUDIOFOCUS_GAIN` when playback transitions to `PlaybackStatus.playing`, and abandons focus on stop/deactivate. Focus loss events are converted into `pause` or `play` actions on `onMediaAction`.
- **Default (`false`)**: If your player engine (`just_audio`, `audioplayers`, etc.) already manages Android audio focus, leave this disabled to avoid conflicting focus requests within the same process.
- **When to enable**: When using custom pipelines or engines that do not handle OS focus (e.g., bare `fvp` or raw video decoders).
- **Other platforms**: No-op on iOS, macOS, Windows, and Web.

#### Spoken content: pause for navigation prompts (`setPauseWhenDucked`, Android)

By default a brief interruption that only asks to lower other audio (a navigation prompt, especially in Android Auto) ducks your volume. That suits music, but lowered speech under another voice can't be followed. Podcast, audiobook and text-to-speech apps can pause instead:

```dart
import 'package:flutter_media_session/flutter_media_session.dart';

await session.setAutoHandleInterruptions(true);
await session.setPauseWhenDucked(true);

FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
  if (action == MediaAction.play && action.isInterruption) {
    // Back after a call or a prompt: step back a little so nothing is missed.
    player.seek(player.position - const Duration(seconds: 3));
  }
});
```

- The focus request is made with `CONTENT_TYPE_SPEECH` and `willPauseWhenDucked`, so the system tells the app instead of ducking it. The pause and the resume arrive as `pause` and `play` actions.
- Pauses and resumes caused by an interruption (a call, a prompt) carry `MediaAction.isInterruption`, so an app can tell them from the user pressing pause, and step back on resume.

### Background Keep-Alive (`setBackgroundKeepAlive`)

For audio streamed or cast off-device (e.g. Google Cast / DLNA), the local audio hardware is idle, leaving the app vulnerable to OS sleep or Doze termination:

```dart
await session.setBackgroundKeepAlive(true);
```

Platform implementation details:
- **Android**: Acquires a `PARTIAL_WAKE_LOCK` and a `WIFI_MODE_FULL_HIGH_PERF` Wi-Fi lock, running under the `connectedDevice` foreground service type.
- **Linux**: Inhibits system screensaver and idle sleep via D-Bus (`org.freedesktop.ScreenSaver` `Inhibit`/`UnInhibit`).
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

### Media Library & Android Auto (Android)

Media browsers such as Android Auto show a library the user can browse and pick from, and accept voice requests ("play X on My App"). The library is opt-in: until `setMediaLibrary` is called, browse requests are refused and the service behaves as before.

```dart
import 'package:flutter_media_session/flutter_media_session.dart';

final session = FlutterMediaSession();

await session.setMediaLibrary(getChildren: (parentId) async {
  if (parentId == MediaLibraryItem.rootId) {
    return const [
      MediaLibraryItem(id: 'recent', title: 'Recently played', isBrowsable: true, isPlayable: false),
    ];
  }
  if (parentId == 'recent') {
    return [
      for (final track in await history.recent())
        MediaLibraryItem(id: track.id, title: track.title, subtitle: track.artist, artworkUri: track.coverUri),
    ];
  }
  return const [];
});

session.setActionHandler(
  onPlay: () => player.play(),
  onPause: () => player.pause(),
  // An item picked in the library:
  onPlayFromMediaId: (mediaId) => playlist.playItem(mediaId),
  // A voice request; the query is the spoken words, interpreted by the app:
  onPlayFromSearch: (query) => playlist.playMatching(query),
);

// Turn it off again:
await session.clearMediaLibrary();
```

- The browser asks for the children of `MediaLibraryItem.rootId` first, then of any item with `isBrowsable: true`. Items with `isPlayable: true` can be picked.
- Picking an item sends `MediaAction.playFromMediaId` (its id in `action.mediaId`); a voice request sends `MediaAction.playFromSearch` (the words in `action.query`). Start playback and update metadata and state as usual.
- Paging requested by the browser is applied to the list `getChildren` returns.

To be listed in Android Auto, the app also declares itself a media app in its **own** `AndroidManifest.xml`:

```xml
<application>
    <meta-data
        android:name="com.google.android.gms.car.application"
        android:resource="@xml/automotive_app_desc" />
</application>
```

with `android/app/src/main/res/xml/automotive_app_desc.xml`:

```xml
<automotiveApp>
    <uses name="media" />
</automotiveApp>
```

Android Auto lists apps installed from Google Play. To test a debug or sideloaded build, enable **Unknown sources** in Android Auto's developer settings (tap the version number in Android Auto's settings ten times to reveal them).

On other platforms `setMediaLibrary` has no effect.
