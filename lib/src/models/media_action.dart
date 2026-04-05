/// Represents a media playback action triggered by system media controls.
class MediaAction {
  /// The unique name of the action.
  final String name;

  /// Optional seek position in milliseconds (only set for [seekTo] actions).
  final Duration? seekPosition;

  /// Creates a new [MediaAction] instance with the given [name] and optional
  /// [seekPosition].
  const MediaAction(this.name, {this.seekPosition});

  /// Action to resume playback.
  static const play = MediaAction('play');

  /// Action to pause playback.
  static const pause = MediaAction('pause');

  /// Action to skip to the next track.
  static const skipToNext = MediaAction('skipToNext');

  /// Action to skip to the previous track.
  static const skipToPrevious = MediaAction('skipToPrevious');

  /// Action to stop playback.
  static const stop = MediaAction('stop');

  /// Action to seek to a specific position.
  ///
  /// When received from system controls, [seekPosition] contains the target
  /// position. Use [MediaAction.seekTo] as a constant only for equality checks;
  /// actual seek events will have a non-null [seekPosition].
  static const seekTo = MediaAction('seekTo');

  /// Action to rewind playback by a standard interval.
  static const rewind = MediaAction('rewind');

  /// Action to fast-forward playback by a standard interval.
  static const fastForward = MediaAction('fastForward');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAction &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() =>
      seekPosition != null ? '$name(${seekPosition!.inMilliseconds}ms)' : name;
}
