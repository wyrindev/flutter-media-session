# flutter_media_session

> [!IMPORTANT]  
> **Experimental API**: This plugin is currently experimental. The API is subject to change without notice in future versions.

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

For detailed instructions and examples on how to initialize the plugin, manage media metadata, respond to system media events, and customize available media controls layout dynamically, please refer to our full breakdown:

**[Detailed Usage Guide](docs/usage.md)**

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.