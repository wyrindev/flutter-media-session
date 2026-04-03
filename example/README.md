# Flutter Media Session Example

A Material Design 3 music player that demonstrates how to integrate the `flutter_media_session` plugin with a real audio player (`audioplayers`).

## Features

- 📱 **Native Control Center Integration**: See what's playing in the system's media center (Android, Windows, Web).
- 🖼️ **Dynamic Metadata**: Real-time updates for song titles, artists, and high-quality artwork from network URLs.
- ⏯️ **Remote Control**: Respond to Play, Pause, Skip Next, and Skip Previous commands from your headphones, lock screen, or system media panel.
- 🚀 **Material 3 Interface**: A clean, modern UI featuring:
    - Animated song transitions.
    - Progress synchronization with system controls.
    - Adaptive color schemes.

## Getting Started

### Prerequisites

- Flutter SDK (latest version recommended)
- A physical device or emulator (Android 7.0+, Windows 10+, or a modern Web browser)

### Installation

1.  Clone the repository and navigate to the example directory:
    ```bash
    cd example
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```

### Running the App

To run the example app on your connected device:

```bash
flutter run
```

## How It Works

### Activating the Session

The app initializes the `FlutterMediaSession` and calls `activate()` to hook into native media APIs.

```dart
final _mediaSession = FlutterMediaSession();
await _mediaSession.activate();
```

### Syncing with Audio Player

The app listens to `audioplayers` events and updates the plugin's metadata and playback state accordingly.

```dart
_audioPlayer.onPositionChanged.listen((p) {
  _mediaSession.updatePlaybackState(
    PlaybackState(
      status: PlaybackStatus.playing,
      position: p,
      speed: 1.0,
    ),
  );
});
```

### Handling External Actions

When a user clicks "Next" on their headphones or system panel, the app receives an event through the `onMediaAction` stream.

```dart
_mediaSession.onMediaAction.listen((action) {
  if (action == MediaAction.skipToNext) {
    _playNextSong();
  }
});
```

## Demo Songs

The example uses creative commons audio from [SoundHelix](https://www.soundhelix.com/song-examples) and images from [Picsum](https://picsum.photos/).
