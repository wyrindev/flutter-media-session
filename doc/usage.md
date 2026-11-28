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
  onPlayFromMediaId: (mediaId, resumeFrom) => playlist.playItem(mediaId),
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
- **Default (`false`)**: If your player engine (`just_audio`, `audioplayers`, etc.) already manages Android audio focus, leave this disabled to avoid conflicting focus requests within the same process. To enable it with such a player, turn the player's own focus handling off (for example `audioplayers`: `AudioContextAndroid(audioFocus: AndroidAudioFocus.none)`): two focus requests in one app knock each other out.
- **When to enable**: When using custom pipelines or engines that do not handle OS focus (e.g., bare `fvp` or raw video decoders).
- **Other platforms**: No-op on iOS, macOS, Windows, and Web.

#### Spoken content: pause for navigation prompts (`pauseWhenDucked`, Android)

By default a brief interruption that only asks to lower other audio (a navigation prompt, especially in Android Auto) ducks your volume. That suits music, but lowered speech under another voice can't be followed. Podcast, audiobook and text-to-speech apps can pause instead:

```dart
import 'package:flutter_media_session/flutter_media_session.dart';

await session.setAutoHandleInterruptions(true, pauseWhenDucked: true);

FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
  if (action == MediaAction.play && action.isInterruption) {
    // Back after a call or a prompt: step back a little so nothing is missed.
    player.seek(player.position - const Duration(seconds: 3));
  }
});
```

- The focus request is made with `CONTENT_TYPE_SPEECH` and `willPauseWhenDucked`, so the system tells the app instead of ducking it. The pause and the resume arrive as `pause` and `play` actions.
- Each `setAutoHandleInterruptions` call sets both, so pass `pauseWhenDucked` every time; without it, ducking is back.
- The plugin must be the only one in the app requesting audio focus. If the player requests its own (the default for `audioplayers` and `just_audio`), the system ducks the player's request and this has no effect; turn the player's focus handling off as above.
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

### Opening the App from the Media Controls (Android)

Tapping the media notification (or the system's media controls) opens the app with its launch intent, marked with the extra `FlutterMediaSessionService.EXTRA_OPENED_FROM_SESSION` set to `true`. An app that wants to show what is playing when opened this way checks for it in its `MainActivity`, both when it is created and in `onNewIntent` (when it was already running), and passes it on to Dart however it likes:

```kotlin
import dev.wyrin.flutter_media_session.FlutterMediaSessionService

val fromControls = intent.getBooleanExtra(FlutterMediaSessionService.EXTRA_OPENED_FROM_SESSION, false)
```

Opened from the launcher, the extra is absent.

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
  onPlayFromMediaId: (mediaId, resumeFrom) => playlist.playItem(mediaId),
  // A voice request; the query is the spoken words, interpreted by the app:
  onPlayFromSearch: (query) => playlist.playMatching(query),
);

// Turn it off again:
await session.setMediaLibrary();
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

#### When the app is closed (cold start)

Android Auto browses media apps that aren't running. Without more setup, a closed app's library is empty until the app is opened on the phone. To have the plugin start the app's Dart code in the background when it's needed, opt into a Flutter engine shared by the app's screen and the media service.

Declare it in the app's `AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="dev.wyrin.flutter_media_session.background_engine"
    android:value="true" />
```

and make `MainActivity` use the shared engine:

```kotlin
import dev.wyrin.flutter_media_session.FlutterMediaSessionActivity

class MainActivity : FlutterMediaSessionActivity()
```

If your app uses `FlutterFragmentActivity` (e.g. for plugins that require Android fragments, such as `local_auth`), extend `FlutterMediaSessionFragmentActivity` instead:

```kotlin
import dev.wyrin.flutter_media_session.FlutterMediaSessionFragmentActivity

class MainActivity : FlutterMediaSessionFragmentActivity()
```

The app then starts in the background (running its normal `main()`, without a screen) when the library is opened in the car or something is asked to play, not merely when Android Auto connects. The screen attaches to the same engine when the app is opened, and the engine keeps running when the screen closes. Swiping the app away from recent apps sends `stop`, as closing the screen used to end playback.

Started this way, the app should set up its library and action handlers but not activate its session or start playing until it is asked to: an active session makes it the app Android Auto resumes, taking over from whatever was playing. `wasStartedInBackground()` tells it which case it is in:

```dart
await session.setMediaLibrary(getChildren: libraryChildren);
if (!await session.wasStartedInBackground()) {
  await session.activate();
}
// Otherwise activate in onPlayFromMediaId / onPlayFromSearch / onPlay.
```

Apps without a media library or a saved resumption item keep the v3.2.1 activation behavior. On Android, `activate()` initially exposes a paused session with a placeholder item. With either feature enabled, the session has an empty playlist until the app sends metadata or playback state, so automatic playback requests can go through the resumption callback. Enabling the library or saving a resumption item after activation also updates the initial session state if the app has yet to send metadata or playback state.

#### Resuming playback

Android Auto asks the media app it used last to resume when it connects, as do Bluetooth devices and the system's resume card. With nothing loaded, the plugin answers with the item the app saved, which survives the app being closed:

```dart
await session.setResumptionItem(
  MediaLibraryItem(id: 'track-2', title: 'Song 3', subtitle: 'Artist'),
  position: currentPosition,
);
```

Save it when the item changes and when playback pauses or stops. The resume arrives as `playFromMediaId`: in `setActionHandler`, `onPlayFromMediaId` gets the saved position as `resumeFrom` (null for a pick); on the `MediaAction`, `isResumption` and `startPosition`. With nothing saved, or after `setResumptionItem(null)`, the request is declined and nothing starts.

Read the current position from your player when saving a resume point. Position updates driven by UI frames can stall when the app is in the background or starts without a screen. For `audioplayers`, the example uses `TimerPositionUpdater` for position events and `getCurrentPosition()` to sample the player directly.

```dart
session.setActionHandler(
  onPlayFromMediaId: (mediaId, resumeFrom) {
    playItem(mediaId, from: resumeFrom ?? Duration.zero);
  },
);
```

The id is yours: an app whose position isn't a time (a reader, a podcast app's own bookmarks) can save an id that identifies what to continue, keep the exact position itself, and leave `position` at zero.

Controllers usually send `play` right after a pick or a resume; treat it as part of the request if that item is already starting. Android Auto also sends the current item again when it reconnects to a running app: continue it rather than starting it over.

On other platforms `setMediaLibrary` has no effect.
