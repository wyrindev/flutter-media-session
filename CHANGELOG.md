## 2.0.0-pre.1

* **Breaking Feature**: Added `updateAvailableActions` API to dynamically toggle system media controls (Play, Pause, Skip, Seek, etc.).
* Improved Web Media Session playback buffering and synchronized seeking logic.
* Fixed Android and Windows media progress bar synchronization, with advanced position extrapolation.
* Enhanced debounced seeking strategy across all platforms.

## 1.0.0

* Initial release of `flutter_media_session`.
* Support for Android (Media3), Windows (SMTC), and Web (Media Session API).
* Synchronize track metadata (title, artist, album, artwork).
* Synchronize playback states (playing, paused, position, speed).
* Receive media actions (play, pause, next, previous) from system controls.