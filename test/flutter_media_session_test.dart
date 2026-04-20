import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_media_session/flutter_media_session_platform_interface.dart';
import 'package:flutter_media_session/flutter_media_session_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterMediaSessionPlatform
    with MockPlatformInterfaceMixin
    implements FlutterMediaSessionPlatform {
  @override
  Future<void> activate() => Future.value();

  @override
  Future<void> deactivate() => Future.value();

  @override
  Future<void> updateMetadata(MediaMetadata metadata) => Future.value();

  @override
  Future<void> updatePlaybackState(PlaybackState state) => Future.value();

  @override
  Future<void> updateAvailableActions(Set<MediaAction>? actions) =>
      Future.value();

  @override
  Future<bool> requestNotificationPermission() => Future.value(true);

  @override
  Future<void> setHandlesInterruptions(bool enabled) => Future.value();

  @override
  Stream<MediaAction> get onMediaAction => const Stream.empty();

  @override
  Future<void> setWindowsAppUserModelId(String id, {String? displayName, String? iconPath}) => Future.value();
}

void main() {
  final FlutterMediaSessionPlatform initialPlatform =
      FlutterMediaSessionPlatform.instance;

  test('$MethodChannelFlutterMediaSession is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterMediaSession>());
  });
}
