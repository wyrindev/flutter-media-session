# Flutter Media Session Usage Guide

This document provides a comprehensive guide on how to integrate and use the `flutter_media_session` plugin in your application to synchronize media metadata and playback state with system-level controls.

## 1. Initialization and Permissions

First, create an instance of `FlutterMediaSession` and activate it. On Android 13+ (API 33+), you may also need to request notification permissions to display the media controls.

```dart
import 'package:flutter_media_session/flutter_media_session.dart';

final _mediaSession = FlutterMediaSession();

// Request permissions on Android (optional but recommended)
await _mediaSession.requestNotificationPermission();

// Activate to start the media session
await _mediaSession.activate();
```

## 2. Handle Media Actions

Listen to the `onMediaAction` stream to respond to user interactions from system controls (like Play, Pause, Skip, or Seek).

```dart
_mediaSession.onMediaAction.listen((action) {
  switch (action) {
    case MediaAction.play:
      // Resume your player
      break;
    case MediaAction.pause:
      // Pause your player
      break;
    case MediaAction.skipToNext:
      // Move to the next track
      break;
    case MediaAction.skipToPrevious:
      // Move to the previous track
      break;
    case MediaAction.seekTo:
      if (action.seekPosition != null) {
        // Seek your player to the new position
        // e.g. _audioPlayer.seek(action.seekPosition!);
      }
      break;
    case MediaAction.stop:
      // Stop the player
      break;
    case MediaAction.shuffle:
      // Toggle shuffle mode
      break;
    case MediaAction.repeat:
      // Toggle repeat mode
      break;
    // Handle other actions...
  }
});
```

## 3. Update Available Actions (New in v2.0.0)

You can dynamically declare which media controls should be available and visible on the system UI (e.g., hiding the skip buttons or seek bar when appropriate).

```dart
// To enable specific actions, pass a Set of MediaAction:
await _mediaSession.updateAvailableActions({
  MediaAction.play,
  MediaAction.pause,
  MediaAction.seekTo, // This enables the seek bar/progress bar interactions
});

// To enable ALL supported actions, simply pass null:
await _mediaSession.updateAvailableActions(null);
```

### Android Custom Media Actions (New in v2.1.0)

On Android, you can add completely custom buttons to the notification (e.g., "Like", "Shuffle"). You need to provide the name of a drawable resource (XML or PNG) that exists in your Android project's `res/drawable` folder.

```dart
final likeAction = MediaAction.custom(
  name: 'like',
  customLabel: 'Like',
  customIconResource: 'ic_thumb_up', // Must exist in android/app/src/main/res/drawable/
);

// Add it to your available actions
await _mediaSession.updateAvailableActions({
  MediaAction.play,
  MediaAction.pause,
  likeAction,
});

// Listen for the custom action
_mediaSession.onMediaAction.listen((action) {
  if (action.name == 'like') {
    // Handle the custom action
  }
});
```

> **Note:** Custom actions are currently only supported on Android. On other platforms, custom actions passed to `updateAvailableActions` will be gracefully ignored.

## 4. Update Metadata

Whenever a new track starts or metadata changes, update the system controls.

```dart
await _mediaSession.updateMetadata(
  MediaMetadata(
    title: 'SoundHelix Song 1',
    artist: 'SoundHelix',
    album: 'SoundHelix Demo',
    artworkUri: 'https://example.com/artwork.png', // Or a local file path on Windows
    duration: const Duration(minutes: 6, seconds: 12),
  ),
);
```

> **Windows Tip:** On Windows, `artworkUri` can be a local file path (e.g., `C:\Users\Name\Music\cover.jpg`). The plugin will automatically convert it to a valid file URI for the system media controls.

## 5. Update Playback State

Keep the system synchronized with your player's current status (playing, paused, buffering, etc.) and its current position. This is critical for keeping the system's progress bar in sync.

```dart
await _mediaSession.updatePlaybackState(
  PlaybackState(
    status: PlaybackStatus.playing, // buffering, paused, idle, error
    position: const Duration(seconds: 42),
    speed: 1.0, // Optional playback speed
  ),
);
```

## 6. Audio Focus Management (New in v2.1.0)

On Android, you can opt-in to automatic audio focus management. When enabled, the plugin will:
1. Request audio focus when playback starts.
2. Automatically pause playback (via `onMediaAction`) when another app takes focus (e.g., an incoming call).
3. Automatically resume playback when the interruption ends (if the interruption was transient).

```dart
// Enable automatic focus management
await _mediaSession.setHandlesInterruptions(true);
```

> **Important:** If your underlying audio player already handles audio focus (like `audioplayers` or `just_audio`), you should keep this **disabled** (the default) to avoid conflicts. Enable it only for players that don't manage focus themselves (like `fvp` or `video_player`).

## 7. Deactivate

When your app no longer needs the media session (e.g., the app is closing or the music is completely stopped and dismissed), deactivate it to release resources cleanly.

```dart
await _mediaSession.deactivate();
```