import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';

import 'models/track.dart';
import 'widgets/player_button.dart';
import 'widgets/artwork_widget.dart';
import 'widgets/settings_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      minimumSize: Size(400, 600),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  if (!kIsWeb && Platform.isWindows) {
    await FlutterMediaSession().setWindowsAppUserModelId(
      'dev.wyrin.flutter_media_session_example',
      displayName: 'Flutter Media Session Example',
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const PlayerHome(),
    );
  }
}

class PlayerHome extends StatefulWidget {
  const PlayerHome({super.key});

  @override
  State<PlayerHome> createState() => _PlayerHomeState();
}

class _PlayerHomeState extends State<PlayerHome> {
  final _plugin = FlutterMediaSession();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _active = false;
  PlaybackStatus _status = PlaybackStatus.idle;
  bool _isBuffering = false;
  bool _handlesInterruptions = false;
  bool _hasError = false;
  bool _isSwitchingTrack = false;
  int _currentIndex = 0;
  int _trackVersion = 0;
  Duration _position = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _playPressed = false;
  bool _isDragging = false;
  bool _shouldResumeAfterDrag = false;
  final _random = Random();

  MediaAction get _shuffleAction => !kIsWeb && Platform.isAndroid
      ? MediaAction.custom(
          name: 'shuffle',
          customLabel: 'Shuffle',
          customIconResource: _isShuffle ? 'ic_shuffle_on' : 'ic_shuffle_off',
        )
      : MediaAction.shuffle;

  MediaAction get _repeatAction => !kIsWeb && Platform.isAndroid
      ? MediaAction.custom(
          name: 'repeat',
          customLabel: 'Repeat',
          customIconResource: _isRepeat ? 'ic_repeat_on' : 'ic_repeat_off',
        )
      : MediaAction.repeat;

  Set<MediaAction>? _availableActions;

  String? _loadedUrl;
  Timer? _seekDebounce;
  DateTime _lastSeekTime = DateTime.fromMillisecondsSinceEpoch(0);
  final List<StreamSubscription> _subscriptions = [];

  final List<Track> _playlist = List.generate(17, (index) {
    final id = index + 1;
    return Track(
      title: 'SoundHelix Song $id',
      artist: 'SoundHelix',
      artwork: 'https://picsum.photos/400/400?seed=$id',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-$id.mp3',
    );
  });

  Track get current => _playlist[_currentIndex];

  @override
  void initState() {
    super.initState();
    _availableActions = {
      MediaAction.play,
      MediaAction.pause,
      MediaAction.skipToNext,
      MediaAction.skipToPrevious,
      MediaAction.seekTo,
      MediaAction.stop,
      MediaAction.rewind,
      MediaAction.fastForward,
      _shuffleAction,
      _repeatAction,
    };
    _listenMediaSessionActions();
    _listenAudioPlayerEvents();
  }

  void _listenMediaSessionActions() {
    _subscriptions.add(_plugin.onMediaAction.listen((action) {
      switch (action) {
        case MediaAction.play:
          _play();
          break;
        case MediaAction.pause:
          _pause();
          break;
        case MediaAction.skipToNext:
          _next();
          break;
        case MediaAction.skipToPrevious:
          _prev();
          break;
        case MediaAction.seekTo:
          if (action.seekPosition != null) {
            final newPosition = action.seekPosition!;
            if (mounted) {
              setState(() {
                _position = newPosition;
                _lastSeekTime = DateTime.now();
              });
            }
            _updatePlayback();
            _seekDebounce?.cancel();
            _seekDebounce = Timer(const Duration(milliseconds: 200), () {
              if (mounted) {
                _audioPlayer.seek(newPosition).catchError((_) {});
              }
            });
          }
          break;
        default:
          if (action.name == 'shuffle') {
            if (mounted) _toggleShuffle();
          } else if (action.name == 'repeat') {
            if (mounted) _toggleRepeat();
          }
          break;
      }
    }));
  }

  void _listenAudioPlayerEvents() {
    _subscriptions.add(_audioPlayer.onDurationChanged.listen((Duration d) {
      if (mounted) {
        setState(() {
          _currentDuration = d;
          if (d > Duration.zero) _isBuffering = false;
        });
        _updateAll();
      }
    }));

    _subscriptions.add(_audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        if (_isDragging) return;
        if (DateTime.now().difference(_lastSeekTime).inMilliseconds < 500) {
          return;
        }

        final wasBuffering = _isBuffering;
        setState(() {
          _position = p;
          if (!_isSwitchingTrack) _isBuffering = false;
        });
        if (wasBuffering && !_isBuffering) _updatePlayback();
      }
    }));

    _subscriptions.add(_audioPlayer.onPlayerComplete.listen((event) {
      if (_isRepeat) {
        _replayTrack();
      } else {
        _next();
      }
    }));

    _subscriptions.add(_audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          if (state == PlayerState.playing) {
            _status = PlaybackStatus.playing;
            _isBuffering = _currentDuration == Duration.zero;
            _isSwitchingTrack = false;
          } else if (state == PlayerState.paused) {
            _status = PlaybackStatus.paused;
            // Only stop buffering if we actually have metadata/duration
            if (_currentDuration > Duration.zero) _isBuffering = false;
          } else if (state == PlayerState.completed ||
              state == PlayerState.stopped) {
            _status = PlaybackStatus.idle;
            _isBuffering = false;
          }
        });
        _updatePlayback();
      }
    }));
  }

  Future<void> _activate() async {
    final granted = await _plugin.requestNotificationPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Notification permission is required for media controls')),
      );
    }
    await _plugin.activate();
    if (!mounted) return;
    setState(() => _active = true);
    await Future.wait([
      _updateAvailableActions(),
      _updateAll(),
    ]);
  }

  Future<void> _updateAvailableActions() async {
    if (!_active) return;
    await _plugin.updateAvailableActions(_availableActions);
  }

  Future<void> _deactivate() async {
    _seekDebounce?.cancel();
    await _plugin.deactivate();
    await _audioPlayer.stop();
    setState(() {
      _active = false;
      _status = PlaybackStatus.idle;
      _isBuffering = false;
      _position = Duration.zero;
      _isSwitchingTrack = false;
      _handlesInterruptions = false;
    });
  }

  Future<void> _attemptPlay() async {
    for (int i = 0; i < 2; i++) {
      try {
        await _audioPlayer.play(UrlSource(current.url));
        return;
      } catch (e) {
        if (e.toString().contains('AbortError') ||
            e.toString().contains('interrupted')) {
          return;
        }
        debugPrint("Play attempt ${i + 1} failed: $e");
        if (i == 1) rethrow;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _play() async {
    final bool wasError = _hasError;
    setState(() {
      _hasError = false;
      if (_status != PlaybackStatus.playing) _isBuffering = true;
    });
    try {
      if (wasError ||
          _loadedUrl != current.url ||
          _audioPlayer.source == null) {
        _loadedUrl = current.url;
        await _attemptPlay();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      if (e.toString().contains('AbortError') ||
          e.toString().contains('interrupted')) {
        return;
      }
      debugPrint("Play error: $e");
      _handleError();
    }
  }

  Future<void> _pause() async {
    try {
      await _audioPlayer.pause();
    } catch (_) {}
  }

  Future<void> _next() async {
    _changeTrack(1);
  }

  Future<void> _prev() async {
    _changeTrack(-1);
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
      _availableActions?.removeWhere((a) => a.name == 'shuffle');
      _availableActions?.add(_shuffleAction);
    });
    _updateAvailableActions();
  }

  void _toggleRepeat() {
    setState(() {
      _isRepeat = !_isRepeat;
      _availableActions?.removeWhere((a) => a.name == 'repeat');
      _availableActions?.add(_repeatAction);
    });
    _updateAvailableActions();
  }

  void _changeTrack(int step) async {
    _seekDebounce?.cancel();
    await _audioPlayer.stop().catchError((_) {});

    final versionAtStart = ++_trackVersion;

    setState(() {
      _isSwitchingTrack = true;
      if (_isShuffle && _playlist.length > 1) {
        int newIndex;
        do {
          newIndex = _random.nextInt(_playlist.length);
        } while (newIndex == _currentIndex);
        _currentIndex = newIndex;
      } else {
        _currentIndex =
            (_currentIndex + step + _playlist.length) % _playlist.length;
      }
      _position = Duration.zero;
      _currentDuration = Duration.zero;
      _isBuffering = true;
      _hasError = false;
      _status = PlaybackStatus.idle;
      _loadedUrl = current.url;
    });
    _updateAll();

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (_trackVersion != versionAtStart) return;

      try {
        await _attemptPlay();
      } catch (e) {
        if (e.toString().contains('AbortError') ||
            e.toString().contains('interrupted')) {
          return;
        }
        debugPrint("Change track error: $e");
        _handleError();
      }
    });
  }

  Future<void> _replayTrack() async {
    setState(() {
      _position = Duration.zero;
      _isBuffering = true;
      _hasError = false;
      _status = PlaybackStatus.idle;
    });
    _updatePlayback();
    try {
      await _attemptPlay();
    } catch (_) {
      _handleError();
    }
  }

  void _handleError() {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _isBuffering = false;
      _isSwitchingTrack = false;
      _status = PlaybackStatus.error;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to load ${current.title}')));
  }

  Future<void> _updateAll() async {
    if (!_active) return;
    await _plugin.updateMetadata(
      MediaMetadata(
        title: current.title,
        artist: current.artist,
        album: 'SoundHelix Demo',
        artworkUri: current.artwork,
        duration: _currentDuration,
      ),
    );
    await _updatePlayback();
  }

  Future<void> _updatePlayback() async {
    if (!_active) return;
    PlaybackStatus status = _status;
    if (_isSwitchingTrack) {
      status = PlaybackStatus.idle;
    } else if (_isBuffering) {
      status = PlaybackStatus.buffering;
    }

    await _plugin.updatePlaybackState(
      PlaybackState(
        status: status,
        position: _position,
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _seekDebounce?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    if (_isBuffering || _isSwitchingTrack) return "--:--";
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inMinutes)}:${two(d.inSeconds % 60)}";
  }

  @override
  Widget build(BuildContext context) {
    final track = current;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("MD3 Player"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 1,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ArtworkWidget(
                              track: track,
                              trackVersion: _trackVersion,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 32),
                            ..._buildPlayerControls(
                                track, colorScheme, textTheme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Media Session Settings",
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            SettingsPanel(
                              active: _active,
                              onActivate: _activate,
                              onDeactivate: _deactivate,
                              availableActions: _availableActions,
                              onActionsChanged: (actions) {
                                setState(() => _availableActions = actions);
                                _updateAvailableActions();
                              },
                              shuffleAction: _shuffleAction,
                              repeatAction: _repeatAction,
                              handlesInterruptions: _handlesInterruptions,
                              onHandleInterruptionsChanged: (val) {
                                setState(() => _handlesInterruptions = val);
                                _plugin.setHandlesInterruptions(val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ArtworkWidget(
                      track: track,
                      trackVersion: _trackVersion,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 32),
                    ..._buildPlayerControls(track, colorScheme, textTheme),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                    Text(
                      "Media Session Settings",
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SettingsPanel(
                      active: _active,
                      onActivate: _activate,
                      onDeactivate: _deactivate,
                      availableActions: _availableActions,
                      onActionsChanged: (actions) {
                        setState(() => _availableActions = actions);
                        _updateAvailableActions();
                      },
                      shuffleAction: _shuffleAction,
                      repeatAction: _repeatAction,
                      handlesInterruptions: _handlesInterruptions,
                      onHandleInterruptionsChanged: (val) {
                        setState(() => _handlesInterruptions = val);
                        _plugin.setHandlesInterruptions(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPlayerControls(
      Track track, ColorScheme colorScheme, TextTheme textTheme) {
    return [
      Text(
        track.title,
        style: textTheme.headlineMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
      ),
      const SizedBox(height: 8),
      Text(
        track.artist,
        style: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      // Playback Progress
      SizedBox(
        height: 20,
        child: (_isBuffering ||
                _isSwitchingTrack ||
                (_status == PlaybackStatus.playing &&
                    _currentDuration <= Duration.zero))
            ? Center(
                child: LinearProgressIndicator(
                  minHeight: 12.0,
                  borderRadius: BorderRadius.circular(6.0),
                ),
              )
            : SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 12,
                  padding: EdgeInsets.zero,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8.0,
                  ),
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble().clamp(
                        0.0,
                        _currentDuration.inMilliseconds.toDouble() > 0
                            ? _currentDuration.inMilliseconds.toDouble()
                            : 1.0,
                      ),
                  min: 0.0,
                  max: _currentDuration.inMilliseconds.toDouble() > 0
                      ? _currentDuration.inMilliseconds.toDouble()
                      : 1.0,
                  onChangeStart: (_hasError ||
                          _currentDuration <= Duration.zero ||
                          (_availableActions != null &&
                              !_availableActions!.contains(MediaAction.seekTo)))
                      ? null
                      : (v) {
                          setState(() {
                            _isDragging = true;
                            if (_status == PlaybackStatus.playing || _status == PlaybackStatus.buffering) {
                              _shouldResumeAfterDrag = true;
                              _audioPlayer.pause();
                            } else {
                              _shouldResumeAfterDrag = false;
                            }
                          });
                        },
                  onChanged: (_hasError ||
                          _currentDuration <= Duration.zero ||
                          (_availableActions != null &&
                              !_availableActions!.contains(MediaAction.seekTo)))
                      ? null
                      : (v) {
                          setState(() {
                            _position = Duration(milliseconds: v.toInt());
                          });
                        },
                  onChangeEnd: (_hasError ||
                          _currentDuration <= Duration.zero ||
                          (_availableActions != null &&
                              !_availableActions!.contains(MediaAction.seekTo)))
                      ? null
                      : (v) async {
                          final newPosition = Duration(milliseconds: v.toInt());
                          await _audioPlayer.seek(newPosition);
                          if (_shouldResumeAfterDrag) {
                            await _audioPlayer.resume();
                          }
                          setState(() {
                            _isDragging = false;
                            _position = newPosition;
                            _lastSeekTime = DateTime.now();
                          });
                          _updatePlayback();
                        },
                ),
              ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_format(_position), style: textTheme.labelMedium),
            Text(
              _format(_currentDuration),
              style: textTheme.labelMedium,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Unified control row
      SizedBox(
        height: 64,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlayerToggleButton(
              isOn: _isRepeat,
              enabled: _active,
              onTap: _toggleRepeat,
              icon: _isRepeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              normalWidth: 40,
              pressedWidth: 50,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 6),
            PlayerActionButton(
              onTap: _prev,
              icon: Icons.skip_previous_rounded,
              isFilled: false,
              normalWidth: 64,
              pressedWidth: 80,
              squeezed: _playPressed,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: PlayerActionButton(
                onTap: (_isBuffering || _isSwitchingTrack)
                    ? null
                    : () {
                        if (_hasError || _status != PlaybackStatus.playing) {
                          _play();
                        } else {
                          _pause();
                        }
                      },
                icon: _status == PlaybackStatus.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                isFilled: true,
                normalWidth: null,
                pressedWidth: null,
                onPressChanged: (v) => setState(() => _playPressed = v),
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 6),
            PlayerActionButton(
              onTap: _next,
              icon: Icons.skip_next_rounded,
              isFilled: false,
              normalWidth: 64,
              pressedWidth: 80,
              squeezed: _playPressed,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 6),
            PlayerToggleButton(
              isOn: _isShuffle,
              enabled: _active,
              onTap: _toggleShuffle,
              icon: Icons.shuffle_rounded,
              normalWidth: 40,
              pressedWidth: 50,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    ];
  }
}
