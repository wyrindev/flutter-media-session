/// Represents a media playback action triggered by system media controls.
class MediaAction {
  /// The unique name of the action.
  final String name;

  /// Creates a new [MediaAction] instance with the given [name].
  const MediaAction(this.name);

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
  String toString() => name;
}
