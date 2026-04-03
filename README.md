# flutter_media_session

A powerful Flutter plugin for integrating your app with system-level media controls (lock screen, notification, media center) across Android, Windows, and Web.

This plugin allows your app to display media metadata (title, artist, artwork) in the system's media center and respond to system actions like Play, Pause, Skip, and Seek.

## Platform Support

| Platform | Support | Underlying API |
| :--- | :--- | :--- |
| **Android** | ✅ | [Media3 MediaSessionService](https://developer.android.com/media/media3/session/control-playback) |
| **Windows** | ✅ | [SystemMediaTransportControls (SMTC)](https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/system-media-transport-controls) |
| **Web** | ✅ | [Media Session API](https://developer.mozilla.org/en-US/docs/Web/API/Media_Session_API) |

## Features

- 🎵 **Metadata Synchronization**: Display title, artist, album, and artwork in the lock screen or system media center.
- ⏯️ **Playback State Control**: Sync playing/paused status and current playback position.
- 📡 **Native Media Actions**: Receive events from system controls (Play, Pause, Skip, Seek, etc.) and handle them in your Dart code.
- 🎧 **Android Background Support**: Automatically handles foreground service requirements for media playback on Android.

## Installation

Add `flutter_media_session` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_media_session: ^1.0.0
```

## Setup

### Android

1.  **Foreground Service Permission**: Ensure your `android/app/src/main/AndroidManifest.xml` includes the necessary permissions (usually added by the plugin automatically, but worth verifying):
    ```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    ```

2.  **Service Declaration**: The plugin handles the service declaration internally via its manifest merger.

### Windows & Web

No specific configuration is required. The plugin uses winrt on Windows and standard JS interop on Web.

## Usage

### 1. Initialize the Plugin

Create an instance of `FlutterMediaSession` and activate it.

```dart
final _mediaSession = FlutterMediaSession();

// Activate to start the media session
await _mediaSession.activate();
```

### 2. Handle Media Actions

Listen to the `onMediaAction` stream to respond to user interactions from system controls.

```dart
_mediaSession.onMediaAction.listen((action) {
  if (action == MediaAction.play) {
    // Resume your player
  } else if (action == MediaAction.pause) {
    // Pause your player
  } else if (action == MediaAction.skipToNext) {
    // Move to the next track
  }
  // Handle other actions like skipToPrevious, stop, seekTo, etc.
});
```

### 3. Update Metadata

Whenever a new track starts or metadata changes, update the system controls.

```dart
await _mediaSession.updateMetadata(
  MediaMetadata(
    title: 'Song Title',
    artist: 'Artist Name',
    album: 'Album Title',
    artworkUri: 'https://example.com/artwork.png',
    duration: Duration(minutes: 3, seconds: 45),
  ),
);
```

### 4. Update Playback State

Keep the system synchronized with your player's current status and position.

```dart
await _mediaSession.updatePlaybackState(
  PlaybackState(
    status: PlaybackStatus.playing, // or paused, buffering, idle, etc.
    position: Duration(seconds: 42),
    speed: 1.0,
  ),
);
```

### 5. Deactivate

When your app no longer needs the media session (e.g., app closing or music stopped), deactivate it.

```dart
await _mediaSession.deactivate();
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
