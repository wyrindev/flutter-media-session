# Flutter Media Session Example

A music player that demonstrates how to integrate the `flutter_media_session` plugin with a real audio player (`audioplayers`).

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

The app defines a `MediaSessionAdapter` to synchronize playback state and metadata, then binds it to `FlutterMediaSession`:

```dart
class MyPlayerAdapter implements MediaSessionAdapter {
  final AudioPlayer player;
  StreamSubscription? _actionSubscription;

  MyPlayerAdapter(this.player);

  @override
  void bind(FlutterMediaSession session) {
    _actionSubscription = FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
      if (action.name == 'play') player.resume();
      if (action.name == 'pause') player.pause();
    });
  }

  @override
  void unbind() {
    _actionSubscription?.cancel();
  }

  void syncState() {
    FlutterMediaSessionPlatform.instance.updatePlaybackState(
      PlaybackState(
        status: PlaybackStatus.playing,
        position: player.position,
      ),
    );
  }
}

// Bind the adapter to your session instance:
_mediaSession.bind(MyPlayerAdapter(_audioPlayer));
```

### Handling External Actions

Alternatively, for simple use cases without a full adapter, you can use `setActionHandler` or listen to `FlutterMediaSessionPlatform.instance.onMediaAction`:

```dart
_mediaSession.setActionHandler(
  onPlay: () => _audioPlayer.resume(),
  onPause: () => _audioPlayer.pause(),
  onSkipToNext: () => _playNextSong(),
  onSkipToPrevious: () => _playPreviousSong(),
);
```

## Demo Songs

The example uses creative commons audio from [SoundHelix](https://www.soundhelix.com/song-examples) and images from [Picsum](https://picsum.photos/).
