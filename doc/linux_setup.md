# Linux Setup

`flutter_media_session` integrates with the Linux desktop media subsystem via the **MPRIS 2** (Media Player Remote Interfacing Specification) interface over D-Bus (`org.mpris.MediaPlayer2` and `org.mpris.MediaPlayer2.Player`).

Desktop environments (GNOME, KDE Plasma, Cinnamon, XFCE) and CLI tools such as `playerctl` discover the session through this standard interface.

---

## Prerequisites

No extra runtime dependencies are required on standard distributions; GDBus is part of GLib/GTK. When building from source:

```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

---

## D-Bus Registration

Calling `FlutterMediaSession().activate()` registers the plugin on the D-Bus Session Bus under:

```text
org.mpris.MediaPlayer2.<ApplicationName>.instance<PID>
```

Both the root interface (`org.mpris.MediaPlayer2`) and the player interface (`org.mpris.MediaPlayer2.Player`) are exported at `/org/mpris/MediaPlayer2`.

Calling `deactivate()` unowns the bus name and unregisters the exported objects.

---

## Application Identity

By default the MPRIS `Identity` and `DesktopEntry` are derived from the process name. Call `setAppId` before `activate()` to set them explicitly:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isLinux) {
    await FlutterMediaSession().setAppId(
      'com.example.myapp',           // matches the DesktopEntry filename
      displayName: 'My Media Player', // shown as MPRIS Identity
    );
  }

  runApp(const MyApp());
}
```

`setAppId` is also the replacement for the deprecated `setWindowsAppUserModelId` on Windows. Use a platform guard (`Platform.isLinux` / `Platform.isWindows`) when behaviour differs, or call it unconditionally when the same ID applies cross-platform.

---

## MPRIS 2 Mapping

### Commands

| MPRIS Method | Flutter action |
| :--- | :--- |
| `Play` | `MediaAction.play` |
| `Pause` | `MediaAction.pause` |
| `PlayPause` | Toggles play/pause based on current `PlaybackState` |
| `Stop` | `MediaAction.stop` |
| `Next` | `MediaAction.skipToNext` |
| `Previous` | `MediaAction.skipToPrevious` |
| `Seek` | `MediaAction.seekTo` (offset applied to current position) |
| `SetPosition` | `MediaAction.seekTo` (absolute position) |

### Properties

| MPRIS Property | Flutter source |
| :--- | :--- |
| `PlaybackStatus` | `PlaybackState.status` → `"Playing"` / `"Paused"` / `"Stopped"` |
| `Position` | `PlaybackState.position` (converted to microseconds) |
| `Rate` | `PlaybackState.speed` |
| `LoopStatus` | `PlaybackState.repeatMode` → `"None"` / `"Track"` / `"Playlist"` |
| `Shuffle` | `PlaybackState.shuffleModeEnabled` |
| `Metadata` | `MediaMetadata` → `xesam:title`, `xesam:artist`, `xesam:album`, `mpris:artUrl`, `mpris:length`, etc. |
| `CanPlay` / `CanPause` / `CanSeek` / `CanGoNext` / `CanGoPrevious` | Derived from `updateAvailableActions()` |

---

## Verifying with playerctl

After launching your app, confirm the session is visible:

```bash
playerctl -l                          # list registered players
playerctl -p <player-name> status     # check playback status
playerctl -p <player-name> metadata   # inspect track metadata
```
