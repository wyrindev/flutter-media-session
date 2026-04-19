import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'src/models/media_metadata.dart';
import 'src/models/playback_state.dart';
import 'src/models/media_action.dart';
import 'flutter_media_session_method_channel.dart';

/// The platform-specific interface for [FlutterMediaSession].
///
/// Platform implementations should extend this class and register themselves
/// with [FlutterMediaSessionPlatform.instance].
abstract class FlutterMediaSessionPlatform extends PlatformInterface {
  /// Constructs a [FlutterMediaSessionPlatform].
  FlutterMediaSessionPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterMediaSessionPlatform _instance =
      MethodChannelFlutterMediaSession();

  /// The default instance of [FlutterMediaSessionPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterMediaSession].
  static FlutterMediaSessionPlatform get instance => _instance;

  /// Sets the platform-specific instance.
  static set instance(FlutterMediaSessionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Activates the media session on the current platform.
  Future<void> activate() {
    throw UnimplementedError('activate() has not been implemented.');
  }

  /// Deactivates the media session on the current platform.
  Future<void> deactivate() {
    throw UnimplementedError('deactivate() has not been implemented.');
  }

  /// Updates the media metadata on the current platform.
  Future<void> updateMetadata(MediaMetadata metadata) {
    throw UnimplementedError('updateMetadata() has not been implemented.');
  }

  /// Updates the playback state on the current platform.
  Future<void> updatePlaybackState(PlaybackState state) {
    throw UnimplementedError('updatePlaybackState() has not been implemented.');
  }

  /// Updates the set of media actions available in system controls.
  ///
  /// Actions not in [actions] will be disabled (hidden or greyed out)
  /// in the notification and lock screen. Pass null to enable all actions.
  Future<void> updateAvailableActions(Set<MediaAction>? actions) {
    throw UnimplementedError(
        'updateAvailableActions() has not been implemented.');
  }

  /// Requests the POST_NOTIFICATIONS permission on Android (33+).
  ///
  /// Returns true if granted or if not needed (e.g., older Android version).
  Future<bool> requestNotificationPermission() {
    throw UnimplementedError(
        'requestNotificationPermission() has not been implemented.');
  }

  /// Sets the AppUserModelID for the current process on Windows.
  ///
  /// This is used by Windows to identify the application in the system media center.
  /// If not set, the application might show up as "Unknown Application".
  ///
  /// Provide [displayName] (and optionally [iconPath]) to dynamically create a 
  /// Start Menu shortcut. This is highly recommended for unpackaged/portable apps.
  /// If your app is packaged via MSIX or uses an installer to create shortcuts, 
  /// you should **omit** [displayName] to avoid creating duplicate shortcuts.
  ///
  /// This method is only effective on Windows.
  Future<void> setWindowsAppUserModelId(String id, {String? displayName, String? iconPath}) {
    throw UnimplementedError(
        'setWindowsAppUserModelId() has not been implemented.');
  }

  /// A stream of media actions emitted by the current platform.
  Stream<MediaAction> get onMediaAction {
    throw UnimplementedError('onMediaAction has not been implemented.');
  }
}
