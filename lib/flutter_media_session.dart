import 'dart:async';
import 'src/models/media_metadata.dart';
import 'src/models/playback_state.dart';
import 'src/models/media_action.dart';
import 'flutter_media_session_platform_interface.dart';

export 'src/models/media_metadata.dart';
export 'src/models/playback_state.dart';
export 'src/models/media_action.dart';

/// The main entry point for the Flutter Media Session plugin.
///
/// This class provides a singleton interface to interact with the system media session,
/// allowing you to update metadata, sync playback state, and listen for media actions.
class FlutterMediaSession {
  static final FlutterMediaSession _instance = FlutterMediaSession._internal();

  /// Factory constructor to return the singleton instance.
  factory FlutterMediaSession() => _instance;

  FlutterMediaSession._internal();

  /// A stream of media actions triggered from the system media controls.
  ///
  /// Actions include 'play', 'pause', 'skipToNext', 'skipToPrevious', etc.
  Stream<MediaAction> get onMediaAction =>
      FlutterMediaSessionPlatform.instance.onMediaAction;

  /// Activates the media session on the current platform.
  ///
  /// On Android, this starts the foreground media service.
  /// On Windows and Web, it initializes the system media transport controls.
  Future<void> activate() {
    return FlutterMediaSessionPlatform.instance.activate();
  }

  /// Deactivates the media session and releases platform resources.
  Future<void> deactivate() {
    return FlutterMediaSessionPlatform.instance.deactivate();
  }

  /// Updates the media metadata (title, artist, album, etc.) displayed in system controls.
  Future<void> updateMetadata(MediaMetadata metadata) {
    return FlutterMediaSessionPlatform.instance.updateMetadata(metadata);
  }

  /// Updates the playback state (status, position, speed) synchronized with system controls.
  Future<void> updatePlaybackState(PlaybackState state) {
    return FlutterMediaSessionPlatform.instance.updatePlaybackState(state);
  }

  /// Updates which media actions are available in system controls.
  ///
  /// Actions not in [actions] will be disabled in the notification.
  /// Pass null to enable all actions (the default).
  ///
  /// Example — disable skip buttons:
  /// ```dart
  /// await _mediaSession.updateAvailableActions({
  ///   MediaAction.play,
  ///   MediaAction.pause,
  ///   MediaAction.seekTo,
  ///   MediaAction.stop,
  /// });
  /// ```
  Future<void> updateAvailableActions(Set<MediaAction>? actions) {
    return FlutterMediaSessionPlatform.instance.updateAvailableActions(actions);
  }
}
