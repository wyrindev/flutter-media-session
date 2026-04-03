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

  /// A stream of media actions emitted by the current platform.
  Stream<MediaAction> get onMediaAction {
    throw UnimplementedError('onMediaAction has not been implemented.');
  }
}
