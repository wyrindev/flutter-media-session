<div align="center">
    <img src="doc/img/banner.png" width="70%" alt="Banner">
</div>

# flutter_media_session

A powerful Flutter plugin for integrating your app with system-level media controls (lock screen, notification, media center) across Android, iOS, macOS, Windows, and Web.

This plugin allows your app to display media metadata (title, artist, artwork) in the system's media center and respond to system actions like Play, Pause, Skip, and Seek.

## Platform Support

| Platform | Support | Underlying API |
| :--- | :--- | :--- |
| <img src="doc/img/platform/head.svg" alt="Android" width="18" style="vertical-align: middle;"> Android | Available | [Media3 MediaSessionService](https://developer.android.com/media/media3/session/control-playback) |
| <img src="doc/img/platform/apple.svg" alt="Apple" width="18" style="vertical-align: middle;"> iOS / macOS | Available | [MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) / [MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) |
| <img src="doc/img/platform/windows.svg" alt="Windows" width="18" style="vertical-align: middle;"> Windows | Available | [SystemMediaTransportControls (SMTC)](https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/system-media-transport-controls) |
| <img src="doc/img/platform/tux.svg" alt="Linux" width="18" style="vertical-align: middle;"> Linux | Planned | [MPRIS](https://specifications.freedesktop.org/mpris-spec/) |
| Web | Available | [Media Session API](https://developer.mozilla.org/en-US/docs/Web/API/Media_Session_API) |

## Features

- 🧩 **Professional Adapter Architecture**: Decouple player implementations from system controls. Easily bind players using a unified `MediaSessionAdapter` interface without bloating the core package with third-party dependencies.
- 🎵 **Rich Metadata & Artwork Synchronization**: Display titles, artists, album names, and artwork on system lock screens and media centers across all platforms.
- ⏯️ **Precise Playback & Timeline Tracking**: Synchronize playing/paused states, playback speed, and current elapsed position across all supported platforms.
- 📡 **Bi-directional System Media Commands**: Respond to standard system-level media controls, including **Play, Pause, Stop, Seek, Skip Forward/Backward, Shuffle, and Repeat**.
- 📶 **Smart Background Keep-Alive**: Maintain connection stability for off-device playback when the app is backgrounded using native platform keep-alive primitives.
- 🔈 **Audio Focus Management (Optional)**: Built-in handling of audio focus interruptions for players that do not manage focus natively.
- 🎨 **Custom Notification Actions (Android)**: Go beyond standard controls by adding custom actions with custom icons and labels directly inside the notification.
- 🎧 **Out-of-the-Box Background Support (Android)**: Automatically manages foreground service requirements, notification lifecycles, and system notification permissions.

## Installation

Add `flutter_media_session` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_media_session: ^3.0.0
```

## Setup

### Android, macOS & Web

No configuration required.

### iOS

1. **Background Audio**: Add the `audio` background mode to your `Info.plist`:
    ```xml
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
    ```
    This allows system-level controls to interact with your app in the background.

### Windows

For proper application identification (avoiding the "Unknown Application" label in system controls), please refer to the:

**[Windows Setup Guide](doc/windows_setup.md)**

## Usage

For detailed instructions and examples on how to initialize the plugin, manage media metadata, respond to system media events, and customize available media controls layout dynamically, please refer to our full breakdown:

**[Detailed Usage Guide](doc/usage.md)**

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
