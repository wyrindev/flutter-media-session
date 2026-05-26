import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_media_session/flutter_media_session_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeFlutterMediaSessionPlatform
    with MockPlatformInterfaceMixin
    implements FlutterMediaSessionPlatform {
  final List<MediaMetadata> metadataUpdates = [];
  final List<PlaybackState> playbackStateUpdates = [];
  final List<Set<MediaAction>?> availableActionsUpdates = [];
  final StreamController<MediaAction> actionController = StreamController<MediaAction>.broadcast();

  @override
  Future<void> activate() => Future.value();

  @override
  Future<void> deactivate() => Future.value();

  @override
  Future<void> updateMetadata(MediaMetadata metadata) {
    metadataUpdates.add(metadata);
    return Future.value();
  }

  @override
  Future<void> updatePlaybackState(PlaybackState state) {
    playbackStateUpdates.add(state);
    return Future.value();
  }

  @override
  Future<void> updateAvailableActions(Set<MediaAction>? actions) {
    availableActionsUpdates.add(actions);
    return Future.value();
  }

  @override
  Future<bool> requestNotificationPermission() => Future.value(true);



  @override
  Future<void> setAutoHandleInterruptions(bool enabled) => Future.value();

  @override
  Stream<MediaAction> get onMediaAction => actionController.stream;

  @override
  Future<void> setWindowsAppUserModelId(String id,
          {String? displayName, String? iconPath}) =>
      Future.value();
}

class TestCustomAdapter extends MediaSessionAdapter {
  late FlutterMediaSession _session;
  bool isBound = false;
  final StreamController<String> playerEvents = StreamController<String>.broadcast();
  StreamSubscription? _actionSub;

  @override
  void bind(FlutterMediaSession session) {
    _session = session;
    isBound = true;

    // Listen to mock system actions
    _actionSub = FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
      playerEvents.add('action_${action.name}');
    });
  }

  @override
  void unbind() {
    isBound = false;
    _actionSub?.cancel();
  }

  void simulateMetadataChange(String title, String artist) {
    FlutterMediaSessionPlatform.instance.updateMetadata(MediaMetadata(title: title, artist: artist));
  }

  void simulateStateChange(PlaybackStatus status, Duration position) {
    FlutterMediaSessionPlatform.instance.updatePlaybackState(PlaybackState(status: status, position: position));
  }
}

void main() {
  late FakeFlutterMediaSessionPlatform fakePlatform;
  late FlutterMediaSession session;

  setUp(() {
    fakePlatform = FakeFlutterMediaSessionPlatform();
    FlutterMediaSessionPlatform.instance = fakePlatform;
    session = FlutterMediaSession();
  });

  test('Adapter lifecycle and bind/unbind', () {
    final adapter = TestCustomAdapter();
    expect(adapter.isBound, isFalse);

    session.bind(adapter);
    expect(adapter.isBound, isTrue);

    session.unbind();
    expect(adapter.isBound, isFalse);
  });

  test('Adapter propagates metadata and playback updates', () {
    final adapter = TestCustomAdapter();
    session.bind(adapter);

    adapter.simulateMetadataChange('Test Title', 'Test Artist');
    expect(fakePlatform.metadataUpdates.length, 1);
    expect(fakePlatform.metadataUpdates.first.title, 'Test Title');
    expect(fakePlatform.metadataUpdates.first.artist, 'Test Artist');

    adapter.simulateStateChange(PlaybackStatus.playing, const Duration(seconds: 15));
    expect(fakePlatform.playbackStateUpdates.length, 1);
    expect(fakePlatform.playbackStateUpdates.first.status, PlaybackStatus.playing);
    expect(fakePlatform.playbackStateUpdates.first.position, const Duration(seconds: 15));

    session.unbind();
  });

  test('Adapter receives system actions from session', () async {
    final adapter = TestCustomAdapter();
    session.bind(adapter);

    final eventExpectation = expectLater(
      adapter.playerEvents.stream,
      emitsInOrder([
        'action_play',
        'action_pause',
      ]),
    );

    fakePlatform.actionController.add(MediaAction.play);
    fakePlatform.actionController.add(MediaAction.pause);

    await eventExpectation;
    session.unbind();
  });
}
