import 'package:flutter/material.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class Track {
  final String title;
  final String artist;
  final String artwork;
  final String url;

  const Track({
    required this.title,
    required this.artist,
    required this.artwork,
    required this.url,
  });
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
  bool _hasError = false;
  bool _isSwitchingTrack = false;
  int _currentIndex = 0;
  Duration _position = Duration.zero;
  Duration _currentDuration = Duration.zero;

  String? _loadedUrl;
  Timer? _seekDebounce;
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
              setState(() => _position = newPosition);
            }
            _updatePlayback();

            // Debouncing external seek commands to avoid flooding the audio player.
            // 200ms provides a good balance between responsiveness and stability.
            _seekDebounce?.cancel();
            _seekDebounce = Timer(const Duration(milliseconds: 200), () {
              if (mounted) {
                _audioPlayer.seek(newPosition).catchError((_) {});
              }
            });
          }
          break;
        default:
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
        setState(() {
          _position = p;
          if (!_isSwitchingTrack) _isBuffering = false;
        });
        // System Media Sessions (Android/Windows) extrapolate position automatically.
        // Spamming updates overrides extrapolation and breaks external controllers (e.g., KDE Connect).
      }
    }));

    _subscriptions.add(_audioPlayer.onPlayerComplete.listen((event) => _next()));

    _subscriptions.add(_audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          if (state == PlayerState.playing) {
            _status = PlaybackStatus.playing;
            _isBuffering = _currentDuration == Duration.zero;
            _isSwitchingTrack = false;
          } else if (state == PlayerState.paused) {
            _status = PlaybackStatus.paused;
            _isBuffering = false;
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
    await _plugin.activate();
    setState(() => _active = true);
    await _updateAll();
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
    });
  }

  Future<void> _play() async {
    setState(() {
      _hasError = false;
      if (_status != PlaybackStatus.playing) _isBuffering = true;
    });
    try {
      if (_loadedUrl != current.url || _audioPlayer.source == null) {
        _loadedUrl = current.url;
        await _audioPlayer.play(UrlSource(current.url));
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("Play error: $e");
      _handleError();
    }
  }

  Future<void> _pause() async => await _audioPlayer.pause();
  Future<void> _next() async => _changeTrack(1);
  Future<void> _prev() async => _changeTrack(-1);

  void _changeTrack(int step) async {
    _seekDebounce?.cancel();
    await _audioPlayer.stop().catchError((_) {});
    setState(() {
      _isSwitchingTrack = true;
      _currentIndex =
          (_currentIndex + step + _playlist.length) % _playlist.length;
      _position = Duration.zero;
      _currentDuration = Duration.zero;
      _isBuffering = true;
      _hasError = false;
      _status = PlaybackStatus.idle;
      _loadedUrl = current.url;
    });
    _updateAll();
    
    Future.delayed(const Duration(milliseconds: 50), () async {
      try {
        await _audioPlayer.play(UrlSource(current.url));
      } catch (e) {
        debugPrint("Change track error: $e");
        _handleError();
      }
    });
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
    await _plugin.updatePlaybackState(
      PlaybackState(
        status: _isSwitchingTrack ? PlaybackStatus.idle : _status,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Card(
                      key: ValueKey(track.artwork),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        track.artwork,
                        width: 280,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 280,
                          height: 280,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.music_off,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
                                  _currentDuration.inMilliseconds.toDouble(),
                                ),
                            min: 0.0,
                            max: _currentDuration.inMilliseconds.toDouble() > 0
                                ? _currentDuration.inMilliseconds.toDouble()
                                : 1.0,
                            onChanged: (_hasError || _currentDuration <= Duration.zero)
                                ? null
                                : (v) {
                                    final newPosition = Duration(
                                      milliseconds: v.toInt(),
                                    );
                                    setState(() => _position = newPosition);
                                  },
                            onChangeEnd: (_hasError || _currentDuration <= Duration.zero)
                                ? null
                                : (v) {
                                    final newPosition = Duration(
                                      milliseconds: v.toInt(),
                                    );
                                    _audioPlayer.seek(newPosition).catchError((_) {});
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
                const SizedBox(height: 24),
                // Control Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filledTonal(
                      iconSize: 32,
                      onPressed: _prev,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filled(
                      iconSize: 56,
                      onPressed: _hasError
                          ? _play
                          : (_status == PlaybackStatus.playing
                              ? _pause
                              : _play),
                      icon: Icon(
                        _status == PlaybackStatus.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                    ),
                    IconButton.filledTonal(
                      iconSize: 32,
                      onPressed: _next,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Active'),
                        icon: Icon(Icons.sensors),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Inactive'),
                        icon: Icon(Icons.sensors_off),
                      ),
                    ],
                    selected: {_active},
                    onSelectionChanged: (set) {
                      final val = set.first;
                      if (val != _active) val ? _activate() : _deactivate();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
