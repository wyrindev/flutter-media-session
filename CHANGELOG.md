## 2.1.0-pre.1

* **Android Custom Media Actions**: Added support for adding custom buttons (like "Like", "Shuffle") to the system notification and lock screen controls via Media3.
* **Audio Focus Management**: Added `setHandlesInterruptions(bool)` to opt-in to automatic audio focus handling on Android.
* **iOS & macOS Support**: Added full support for Darwin platforms using `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.
* **Windows Improvements**: Resolved the "Unknown Application" issue in system media controls and lock screen using dynamic AUMID registration.
* Extended `MediaAction` to support custom labels and Android drawable resources.
* Improved Android `MediaSessionService` to dynamically update custom layout commands.
* Fixed a `Slider` rendering assertion failure in the example application when durations were zero or negative.
* Updated documentation and example app to demonstrate new platform features.

## 2.0.0

* Added `updateAvailableActions` API to dynamically toggle system media controls (Play, Pause, Skip, Seek, etc.).
* Improved Web Media Session playback buffering and synchronized seeking logic.
* Fixed Android and Windows media progress bar synchronization, with advanced position extrapolation.
* Enhanced debounced seeking strategy across all platforms.
* Improved documentation and fixed cross-platform link consistency.

## 1.0.0

* Initial release of `flutter_media_session`.
* Support for Android (Media3), Windows (SMTC), and Web (Media Session API).
* Synchronize track metadata (title, artist, album, artwork).
* Synchronize playback states (playing, paused, position, speed).
* Receive media actions (play, pause, next, previous) from system controls.