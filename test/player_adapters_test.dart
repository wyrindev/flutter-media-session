import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_media_session/flutter_media_session_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../doc/adapters/just_audio_adapter.dart';
import '../doc/adapters/media_kit_adapter.dart';

// Fake platform implementation to capture method calls
class FakePlatform with MockPlatformInterfaceMixin implements FlutterMediaSessionPlatform {
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
  Future<void> setHandlesInterruptions(bool enabled) => Future.value();

  @override
  Future<void> setAutoHandleInterruptions(bool enabled) => Future.value();

  @override
  Stream<MediaAction> get onMediaAction => actionController.stream;

  @override
  Future<void> setWindowsAppUserModelId(String id, {String? displayName, String? iconPath}) =>
      Future.value();
}

// Minimal Fake implementation of just_audio's AudioPlayer
class FakeAudioPlayer extends Fake implements AudioPlayer {
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _sequenceStateController = StreamController<SequenceState?>.broadcast();

  PlayerState _state = PlayerState(false, ProcessingState.idle);
  Duration _pos = Duration.zero;
  Duration? _dur = Duration.zero;
  double _spd = 1.0;
  Duration _buf = Duration.zero;
  LoopMode _loop = LoopMode.off;
  bool _shuffle = false;
  SequenceState? _seq;

  final List<String> calls = [];

  void setPlayerState(bool playing, ProcessingState processingState) {
    _state = PlayerState(playing, processingState);
    _playerStateController.add(_state);
  }

  void setPosition(Duration position) {
    _pos = position;
    _positionController.add(_pos);
  }

  void setDuration(Duration? duration) {
    _dur = duration;
    _durationController.add(_dur);
  }

  Future<void> setSpeedHelper(double speed) async {
    _spd = speed;
    _speedController.add(_spd);
  }

  void setBufferedPosition(Duration bufferedPosition) {
    _buf = bufferedPosition;
    _bufferedPositionController.add(_buf);
  }

  void setSequenceState(SequenceState? seq) {
    _seq = seq;
    _sequenceStateController.add(_seq);
  }

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  @override
  Stream<Duration> get positionStream => _positionController.stream;
  @override
  Stream<Duration?> get durationStream => _durationController.stream;
  @override
  Stream<double> get speedStream => _speedController.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufferedPositionController.stream;
  @override
  Stream<SequenceState?> get sequenceStateStream => _sequenceStateController.stream;

  @override
  PlayerState get playerState => _state;
  @override
  Duration get position => _pos;
  @override
  Duration? get duration => _dur;
  @override
  double get speed => _spd;
  @override
  Duration get bufferedPosition => _buf;
  @override
  LoopMode get loopMode => _loop;
  @override
  bool get shuffleModeEnabled => _shuffle;
  @override
  SequenceState? get sequenceState => _seq;

  @override
  bool get hasNext => _seq != null && _seq!.currentIndex < _seq!.sequence.length - 1;
  @override
  bool get hasPrevious => _seq != null && _seq!.currentIndex > 0;

  @override
  Future<void> play() async {
    calls.add('play');
    setPlayerState(true, ProcessingState.ready);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    setPlayerState(false, ProcessingState.ready);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    setPlayerState(false, ProcessingState.idle);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    calls.add('seek_${position?.inMilliseconds}');
    if (position != null) setPosition(position);
  }

  @override
  Future<void> seekToNext() async {
    calls.add('seekToNext');
  }

  @override
  Future<void> seekToPrevious() async {
    calls.add('seekToPrevious');
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    calls.add('setShuffleModeEnabled_$enabled');
    _shuffle = enabled;
  }

  @override
  Future<void> setLoopMode(LoopMode loopMode) async {
    calls.add('setLoopMode_$loopMode');
    _loop = loopMode;
  }

  @override
  Future<void> setSpeed(double speed) async {
    calls.add('setSpeed_$speed');
    await setSpeedHelper(speed);
  }

  @override
  Future<void> dispose() async {
    _playerStateController.close();
    _positionController.close();
    _durationController.close();
    _speedController.close();
    _bufferedPositionController.close();
    _sequenceStateController.close();
  }
}

// Fake implementation of media_kit's PlayerState
class FakePlayerState extends Fake implements mk.PlayerState {
  @override
  mk.Playlist playlist = const mk.Playlist([]);
  @override
  bool playing = false;
  @override
  bool buffering = false;
  @override
  bool completed = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = Duration.zero;
  @override
  double rate = 1.0;
  @override
  Duration buffer = Duration.zero;
  @override
  mk.PlaylistMode playlistMode = mk.PlaylistMode.none;
}

// Minimal Fake implementation of media_kit's Player
class FakeMediaKitPlayer extends Fake implements mk.Player {
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _bufferController = StreamController<Duration>.broadcast();
  final _playlistController = StreamController<mk.Playlist>.broadcast();

  final _playerState = FakePlayerState();
  late final _playerStream = FakePlayerStreams(this);

  final List<String> calls = [];

  void setPlaying(bool playing) {
    _playerState.playing = playing;
    _playingController.add(playing);
  }

  void setPosition(Duration position) {
    _playerState.position = position;
    _positionController.add(position);
  }

  void setDuration(Duration duration) {
    _playerState.duration = duration;
    _durationController.add(duration);
  }

  void setBufferedPosition(Duration buffer) {
    _playerState.buffer = buffer;
    _bufferController.add(buffer);
  }

  void setPlaylist(mk.Playlist playlist) {
    _playerState.playlist = playlist;
    _playlistController.add(playlist);
  }

  @override
  mk.PlayerState get state => _playerState;

  @override
  mk.PlayerStream get stream => _playerStream;

  @override
  Future<void> play() async {
    calls.add('play');
    setPlaying(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    setPlaying(false);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    setPlaying(false);
  }

  @override
  Future<void> seek(Duration duration) async {
    calls.add('seek_${duration.inMilliseconds}');
    setPosition(duration);
  }

  @override
  Future<void> next() async {
    calls.add('next');
  }

  @override
  Future<void> previous() async {
    calls.add('previous');
  }

  @override
  Future<void> setPlaylistMode(mk.PlaylistMode playlistMode) async {
    calls.add('setPlaylistMode_$playlistMode');
    _playerState.playlistMode = playlistMode;
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('setRate_$rate');
    _playerState.rate = rate;
    _rateController.add(rate);
  }

  @override
  Future<void> dispose() async {
    _playingController.close();
    _positionController.close();
    _durationController.close();
    _rateController.close();
    _bufferController.close();
    _playlistController.close();
  }
}

class FakePlayerStreams extends Fake implements mk.PlayerStream {
  final FakeMediaKitPlayer _player;
  FakePlayerStreams(this._player);

  @override
  Stream<bool> get playing => _player._playingController.stream;
  @override
  Stream<Duration> get position => _player._positionController.stream;
  @override
  Stream<Duration> get duration => _player._durationController.stream;
  @override
  Stream<double> get rate => _player._rateController.stream;
  @override
  Stream<Duration> get buffer => _player._bufferController.stream;
  @override
  Stream<mk.Playlist> get playlist => _player._playlistController.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlatform fakePlatform;
  late FlutterMediaSession session;

  setUp(() {
    fakePlatform = FakePlatform();
    FlutterMediaSessionPlatform.instance = fakePlatform;
    session = FlutterMediaSession();
  });

  group('JustAudioMediaSessionAdapter Tests', () {
    late FakeAudioPlayer player;
    late JustAudioMediaSessionAdapter adapter;

    setUp(() {
      player = FakeAudioPlayer();
      adapter = JustAudioMediaSessionAdapter(player);
    });

    tearDown(() {
      adapter.unbind();
      player.dispose();
    });

    test('Binds and syncs initial state correctly', () async {
      player.setPlayerState(true, ProcessingState.ready);
      player.setPosition(const Duration(seconds: 10));
      player.setDuration(const Duration(seconds: 180));

      session.bind(adapter);

      // Verify initial updates
      expect(fakePlatform.metadataUpdates.isNotEmpty, true);
      expect(fakePlatform.metadataUpdates.last.title, 'Unknown Title');
      expect(fakePlatform.metadataUpdates.last.duration, const Duration(seconds: 180));

      expect(fakePlatform.playbackStateUpdates.isNotEmpty, true);
      expect(fakePlatform.playbackStateUpdates.last.status, PlaybackStatus.playing);
      expect(fakePlatform.playbackStateUpdates.last.position, const Duration(seconds: 10));
    });

    test('Propagates stream changes dynamically', () async {
      session.bind(adapter);

      player.setPosition(const Duration(seconds: 45));
      await Future.delayed(Duration.zero);
      expect(fakePlatform.playbackStateUpdates.last.position, const Duration(seconds: 45));

      player.setPlayerState(false, ProcessingState.ready);
      await Future.delayed(Duration.zero);
      expect(fakePlatform.playbackStateUpdates.last.status, PlaybackStatus.paused);
    });

    test('Handles incoming system media actions correctly', () async {
      session.bind(adapter);

      // Play action
      fakePlatform.actionController.add(MediaAction.play);
      await Future.delayed(Duration.zero);
      expect(player.calls.contains('play'), true);

      // Pause action
      fakePlatform.actionController.add(MediaAction.pause);
      await Future.delayed(Duration.zero);
      expect(player.calls.contains('pause'), true);

      // Seek action
      fakePlatform.actionController.add(const MediaAction('seekTo', seekPosition: Duration(seconds: 90)));
      await Future.delayed(Duration.zero);
      expect(player.calls.contains('seek_90000'), true);
    });
  });

  group('MediaKitMediaSessionAdapter Tests', () {
    late FakeMediaKitPlayer player;
    late MediaKitMediaSessionAdapter adapter;

    setUp(() {
      player = FakeMediaKitPlayer();
      adapter = MediaKitMediaSessionAdapter(player);
    });

    tearDown(() {
      adapter.unbind();
      player.dispose();
    });

    test('Binds and syncs initial state correctly', () async {
      player.setPlaying(true);
      player.setPosition(const Duration(seconds: 15));
      player.setDuration(const Duration(seconds: 200));

      session.bind(adapter);

      expect(fakePlatform.metadataUpdates.isNotEmpty, true);
      expect(fakePlatform.metadataUpdates.last.title, 'Unknown Title');

      expect(fakePlatform.playbackStateUpdates.isNotEmpty, true);
      expect(fakePlatform.playbackStateUpdates.last.status, PlaybackStatus.playing);
      expect(fakePlatform.playbackStateUpdates.last.position, const Duration(seconds: 15));
    });

    test('Propagates stream changes dynamically', () async {
      session.bind(adapter);

      player.setPosition(const Duration(seconds: 60));
      await Future.delayed(Duration.zero);
      expect(fakePlatform.playbackStateUpdates.last.position, const Duration(seconds: 60));

      player.setPlaying(false);
      await Future.delayed(Duration.zero);
      expect(fakePlatform.playbackStateUpdates.last.status, PlaybackStatus.paused);
    });

    test('Handles incoming system media actions correctly', () async {
      session.bind(adapter);

      // Play action
      fakePlatform.actionController.add(MediaAction.play);
      await Future.delayed(Duration.zero);
      expect(player.calls.contains('play'), true);

      // Pause action
      fakePlatform.actionController.add(MediaAction.pause);
      await Future.delayed(Duration.zero);
      expect(player.calls.contains('pause'), true);

      // Seek action
      fakePlatform.actionController.add(const MediaAction('seekTo', seekPosition: Duration(seconds: 120)));
      await Future.delayed(Duration.zero);
      expect(player.calls.contains('seek_120000'), true);
    });
  });
}
