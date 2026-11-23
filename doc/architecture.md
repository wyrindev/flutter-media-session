# Architecture & Design Decisions

`flutter_media_session` follows the Flutter federated plugin pattern, separating application-level playback logic, the platform interface contract, and platform-specific native implementations.

```
┌────────────────────────────────────────────────────────┐
│               Application Audio Player                 │
│         (just_audio / media_kit / custom audio)        │
└───────────────────────────┬────────────────────────────┘
                            │ (MediaSessionAdapter / setActionHandler)
┌───────────────────────────▼────────────────────────────┐
│      flutter_media_session (Public Dart Singleton)     │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│        FlutterMediaSessionPlatform (Interface)         │
└─────────────┬────────────────────────────┬─────────────┘
              │ (MethodChannel & Events)   │ (dart:js_interop / web)
┌─────────────▼─────────────┐ ┌────────────▼─────────────┐
│ Native Mobile & Desktop   │ │           Web            │
│  - Android (Media3)       │ │ (HTML5 MediaSession API) │
│  - Darwin (iOS / macOS)   │ └──────────────────────────┘
│  - Windows (SMTC)         │
│  - Linux (D-Bus MPRIS 2)  │
└───────────────────────────┘
```

1. **Player Engine Layer**: Manages decoding, buffering, rendering, and audio hardware output. The core plugin does not import or bundle any audio player packages.
2. **Adapter Layer (`MediaSessionAdapter`)**: Subscribes to player streams, maps application metadata to `MediaMetadata`, maps playback status to `PlaybackState`, and converts incoming system `MediaAction` events into player function calls.
3. **Public API (`FlutterMediaSession`)**: Adapter lifecycle binding (`bind`/`unbind`), direct action callbacks (`setActionHandler`), and session configuration (`activate`, `deactivate`, `setActionLayout`, `setSkipIntervals`, `setAutoHandleInterruptions`, `setBackgroundKeepAlive`, `setAppId`, and deprecated `setWindowsAppUserModelId`).
4. **Platform Interface (`FlutterMediaSessionPlatform`)**: Typed contract across all platform implementations.
5. **Platform Implementations**:
   - `MethodChannelFlutterMediaSession`: `MethodChannel('flutter_media_session')` for imperative commands; `EventChannel('flutter_media_session_events')` for action events.
   - `FlutterMediaSessionWeb`: Browser DOM interop via `package:web`.

---

## 2. Design Rationale: Decoupled Adapter Architecture

Bundling an audio engine inside a media session plugin causes a few concrete problems:
- **Dependency bloat & version conflicts**: Locking consumers to a specific player pulls in unneeded native libraries and transitive dependencies for everyone else.
- **Divergent player primitives**: Different engines model state differently. `just_audio` uses `ProcessingState` + `playing`; `media_kit` uses separate `playing`, `buffering`, and `completed` booleans. The adapter isolates this mapping outside the plugin core.
- **Resource ownership**: Keeping session management separate from playback enables multi-player scenarios, such as crossfading between two player instances while maintaining a single uninterrupted system session.

---

## 3. Lifecycle Mechanics & Resource Management

Media sessions interface with shared OS hubs (notifications, lock screens, Control Center, Windows taskbar). Strict lifecycle transitions prevent resource leaks and ensure proper foreground service handling.

```
App Playback Start
       │
       ├──> `FlutterMediaSession.activate()`
       │      ├── Android: Starts `FlutterMediaSessionService` (Foreground Service),
       │      │   requests notification permission (API 33+), builds initial notification.
       │      ├── iOS: Configures `AVAudioSession` category `.playback`, registers `MPRemoteCommandCenter`.
       │      ├── macOS: Registers `MPRemoteCommandCenter` handlers.
       │      ├── Windows: Calls `GetForWindow(HWND)` to initialize SMTC.
       │      ├── Linux: Owns D-Bus name `org.mpris.MediaPlayer2.<app>.instance<PID>` and exports MPRIS 2 interfaces.
       │      └── Web: Binds action handlers on `navigator.mediaSession`.
       │
       ├──> `FlutterMediaSession.bind(adapter)`
       │      └── Adapter begins streaming metadata, playback state, and action dispatching.
       │
App Playback Stop / Teardown
       │
       ├──> `FlutterMediaSession.unbind()`
       │      └── Cancels active stream subscriptions between player and session.
       │
       └──> `FlutterMediaSession.deactivate()`
              ├── Clears high-level action callbacks (`clearActionHandler`).
              ├── Android: Calls `stopForeground(STOP_FOREGROUND_REMOVE)` and stops the service.
              ├── iOS/macOS: Clears `MPNowPlayingInfoCenter.default().nowPlayingInfo` and releases commands.
              ├── Windows: Disables SMTC (`smtc.IsEnabled(false)`).
              ├── Linux: Unregisters MPRIS 2 D-Bus objects and releases the D-Bus bus name.
              └── Web: Sets `navigator.mediaSession.playbackState = 'none'`.
```

---

## 4. Native Platform Implementations

### Android: AndroidX Media3 Architecture

- **Core Framework**: Built on AndroidX Media3 `MediaLibraryService` and `MediaLibrarySession` (a `MediaSessionService` with browsing). Browse requests are refused unless the app opts into a media library with `setMediaLibrary`; then the library's nodes are fetched from Dart over the method channel (`getMediaLibraryChildren`), and picking an item or a voice search (media items set on the stand-in player, `handleSetMediaItems` / `handleAddMediaItems`) is forwarded as `playFromMediaId` / `playFromSearch`.
- **Play requests and resumption**: every media item set on the stand-in player becomes one action for Dart: a voice search (`playFromSearch`), a pick (`playFromMediaId`), or a resumed item (`playFromMediaId` with `resumed` and `positionMs`). Resumption comes from Media3's `onPlaybackResumption`, answered from the item the app saved with `setResumptionItem` (kept in SharedPreferences) and marked in the item's request extras; without one it is declined. Until the app gives the session content, the player reports nothing loaded, so an automatic `play` goes to resumption instead of starting playback.
- **Cold start (opt-in)**: with the `background_engine` meta-data, `FlutterMediaSessionEngine` keeps one Flutter engine in `FlutterEngineCache`, shared by the app's screen (`FlutterMediaSessionActivity`) and the service. The service starts it when a library node below the root is requested or a play request arrives while the app is closed; requests made meanwhile wait (library requests up to 15 seconds) and run once the app turns its library on. Swiping the app away sends `stop`.
- **Foreground Service Lifecycle**:
  - `FlutterMediaSessionService` runs as an Android foreground service with types `mediaPlayback|connectedDevice` (complying with Android 14+ background execution policies).
  - Handles `POST_NOTIFICATIONS` runtime permission on Android 13+ (API 33+) via automatic permission request during `activate()`.
- **Notification Presentation**:
  - Implements a custom `FlutterMediaNotificationProvider` extending `DefaultMediaNotificationProvider`.
  - Maps `ActionSlotLayout` directly to notification buttons and compact view indices (`setShowActionsInCompactView`).
  - Supports custom actions with custom icon resources (`customIconResource`) located in `res/drawable*`.
- **Audio Focus**:
  - When `setAutoHandleInterruptions(true)` is set, the service requests `AUDIOFOCUS_GAIN` via `AudioManagerCompat` upon playback and listens for `AUDIOFOCUS_LOSS` / `AUDIOFOCUS_LOSS_TRANSIENT`, dispatching `pause` or `play` actions across the event channel, marked with `reason: interruption`.
  - With `setPauseWhenDucked(true)` the request uses `CONTENT_TYPE_SPEECH` and `willPauseWhenDucked`, so `AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK` (a navigation prompt) pauses instead of being ducked; focus is kept, and `AUDIOFOCUS_GAIN` resumes.
- **Keep-Alive**:
  - When `setBackgroundKeepAlive(true)` is enabled, acquires a `PARTIAL_WAKE_LOCK` and a `WIFI_MODE_FULL_HIGH_PERF` Wi-Fi lock to preserve network connections during screen-off streaming (e.g. casting).

### Apple (iOS & macOS): MediaPlayer & AVFoundation

- **Core Framework**: `MediaPlayer` (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`) and `AVFoundation` (`AVAudioSession`).
- **iOS Execution**:
  - Upon `activate()`, configures `AVAudioSession` with `.playback` category and default mode.
  - Requires `UIBackgroundModes: audio` in `Info.plist` for background command routing.
  - Updates lock screen artwork asynchronously from HTTP/HTTPS URLs or local file paths via `MPMediaItemArtwork`.
- **macOS Execution**:
  - Shares the Darwin Swift source tree with iOS (`sharedDarwinSource: true`).
  - Implements power management via `IOKit`: `setBackgroundKeepAlive(true)` creates an `IOPMAssertion` of type `kIOPMAssertionTypePreventUserIdleSystemSleep`, preventing the Mac from entering idle sleep while casting or streaming off-device.
- **Remote Commands**: Registers event targets on `MPRemoteCommandCenter` (play, pause, stop, togglePlayPause, skipToNext, skipToPrevious, seekTo, skipForward, skipBackward, changePlaybackPosition, shuffle, repeat) and maps them to Flutter event sink calls.

### Windows: WinRT SystemMediaTransportControls (SMTC)

- **Core Framework**: Windows Runtime (WinRT) `Windows.Media.SystemMediaTransportControls` obtained via interop with the application's root window handle (`HWND`).
- **Threading Model & Message Dispatch**:
  - WinRT event callbacks (such as `ButtonPressed` and `PlaybackPositionChangeRequested`) fire on arbitrary background thread-pool threads.
  - The plugin dispatches these events to the Flutter UI thread using `PostMessage` with custom window message `WM_MEDIA_ACTION`, intercepted in the registered top-level window proc delegate. This prevents concurrency collisions with the Flutter engine.
- **Metadata Caching & Deduplication**:
  - Avoids UI flickering in the Windows volume flyout by deduplicating identical metadata updates (`title`, `artist`, `album`, `artworkUri`).
  - Supports local artwork files by brokering access via `StorageFile::GetFileFromPathAsync` and `RandomAccessStreamReference::CreateFromFile`.
- **App Identification (AUMID)**:
  - If packaged with MSIX, the OS automatically resolves the identity.
  - For unpackaged apps, `setAppId` (and deprecated `setWindowsAppUserModelId`) invokes `SetCurrentProcessExplicitAppUserModelID` and dynamically creates a Start Menu shortcut (`IShellLinkW` + `IPropertyStore`) matching the AUMID to resolve the display name in SMTC.
- **Keep-Alive**:
  - Calls `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)` when `setBackgroundKeepAlive(true)` is invoked, preventing system sleep.

### Linux: D-Bus MPRIS 2 Architecture

- **Core Framework**: Built directly with GDBus (`gio/gio.h`) and GLib, requiring no external MPRIS daemons or heavy C++ wrappers.
- **D-Bus Object & Bus Registration**:
  - Upon `activate()`, acquires the session bus and owns the well-known name `org.mpris.MediaPlayer2.<app>.instance<PID>`.
  - Exports standard MPRIS 2 interfaces on `/org/mpris/MediaPlayer2`:
    - `org.mpris.MediaPlayer2`: Root properties (`Identity`, `DesktopEntry`, `CanQuit`, `CanRaise`).
    - `org.mpris.MediaPlayer2.Player`: Playback methods (`Play`, `Pause`, `PlayPause`, `Stop`, `Next`, `Previous`, `Seek`, `SetPosition`) and properties (`PlaybackStatus`, `Metadata`, `Position`, `Rate`, `LoopStatus`, `Shuffle`, `Volume`).
- **App Identity**:
  - `setAppId(appId, displayName: ...)` sets `DesktopEntry` to `<appId>` (without `.desktop`) and updates `Identity` to `displayName` (or falls back to `appId`).
- **Property Change Notifications**:
  - Emits `org.freedesktop.DBus.Properties.PropertiesChanged` signals whenever metadata, playback status, rate, loop status, or volume changes.
- **Event Dispatch**:
  - Incoming method calls from MPRIS clients (`playerctl`, GNOME Shell, KDE plasma media controller) are routed to the Flutter event sink.
- **Deactivation**:
  - Upon `deactivate()`, unregisters exported object paths and releases the bus name.

### Web: W3C Media Session API

- **Core Framework**: `window.navigator.mediaSession` via Dart JS interop (`dart:js_interop` and `package:web`).
- **Command Handling**: Registers browser action handlers (`play`, `pause`, `previoustrack`, `nexttrack`, `stop`, `seekbackward`, `seekforward`, `seekto`) and forwards events to a broadcast stream.
- **Timeline & Position**: Updates browser media notifications using `session.setPositionState` with duration, position, and playback rate.
- **Keep-Alive**: Uses the W3C Screen Wake Lock API (`navigator.wakeLock.request('screen')`) as a best-effort mechanism while the page remains active. Browsers do not expose background thread execution locks for dormant web tabs.

