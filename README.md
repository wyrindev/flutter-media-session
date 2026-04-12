# flutter_media_session

A powerful Flutter plugin for integrating your app with system-level media controls (lock screen, notification, media center) across Android, iOS, macOS, Windows, and Web.

This plugin allows your app to display media metadata (title, artist, artwork) in the system's media center and respond to system actions like Play, Pause, Skip, and Seek.

## Platform Support

| Platform | Support | Underlying API |
| :--- | :--- | :--- |
| **Android** | ✅ | [Media3 MediaSessionService](https://developer.android.com/media/media3/session/control-playback) |
| **iOS** | ✅ | [MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) / [MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) |
| **macOS** | ✅ | [MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) / [MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) |
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
  flutter_media_session: ^2.0.0
```

## Setup

### Android

1.  **Foreground Service Permission**: Ensure your `android/app/src/main/AndroidManifest.xml` includes the necessary permissions (usually added by the plugin automatically, but worth verifying):
    ```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    ```

2.  **Service Declaration**: The plugin handles the service declaration internally via its manifest merger.

### iOS

1. **Background Audio**: Add the `audio` background mode to your `Info.plist`:
    ```xml
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
    ```
    This allows the Now Playing controls to work when the app is backgrounded.

2. **Audio Session**: Call `requestNotificationPermission()` before activating the session. On iOS, this configures the `AVAudioSession` with the `.playback` category.

### macOS

No specific configuration is required. The plugin uses `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` directly.

### Windows & Web

No specific configuration is required. The plugin uses winrt on Windows and standard JS interop on Web.

## Usage

For detailed instructions and examples on how to initialize the plugin, manage media metadata, respond to system media events, and customize available media controls layout dynamically, please refer to our full breakdown:

**[Detailed Usage Guide](doc/usage.md)**

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
