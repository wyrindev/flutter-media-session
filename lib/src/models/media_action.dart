/// Represents a media playback action triggered by system media controls.
class MediaAction {
  /// The unique name of the action.
  final String name;

  /// Optional seek position in milliseconds (only set for [seekTo] actions).
  final Duration? seekPosition;

  /// The Android resource name for the icon (e.g., 'ic_favorite_border').
  ///
  /// This is only used for custom actions.
  final String? customIconResource;

  /// The label to display for this custom action.
  final String? customLabel;

  /// Optional bundle of extra data to pass with the custom action.
  final Map<String, dynamic>? customExtras;

  /// Creates a new [MediaAction] instance with the given [name] and optional
  /// [seekPosition].
  const MediaAction(
    this.name, {
    this.seekPosition,
    this.customIconResource,
    this.customLabel,
    this.customExtras,
  });

  /// Creates a custom media action for Android.
  ///
  /// Custom actions must have a [name], a [customLabel], and a [customIconResource].
  factory MediaAction.custom({
    required String name,
    required String customLabel,
    required String customIconResource,
    Map<String, dynamic>? customExtras,
  }) {
    return MediaAction(
      name,
      customLabel: customLabel,
      customIconResource: customIconResource,
      customExtras: customExtras,
    );
  }

  /// Converts this action to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (customIconResource != null) 'customIconResource': customIconResource,
      if (customLabel != null) 'customLabel': customLabel,
      if (customExtras != null) 'customExtras': customExtras,
    };
  }

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

  /// Action to toggle shuffle mode.
  static const shuffle = MediaAction('shuffle');

  /// Action to toggle repeat mode.
  static const repeat = MediaAction('repeat');

  /// A media browser (such as Android Auto) asked to play an item of the media library.
  ///
  /// The item's id is in [customExtras] under `mediaId` (see [mediaId]). Only sent once the app
  /// has opted into a library with `FlutterMediaSession.setMediaLibrary`. Android only.
  static const playFromMediaId = MediaAction('playFromMediaId');

  /// A voice request such as `play X on <app>` (Google Assistant, Android Auto).
  ///
  /// The spoken query is in [customExtras] under `query` (see [query]); what it means is up to the
  /// app. Android only.
  static const playFromSearch = MediaAction('playFromSearch');

  /// The media library item to play, for [playFromMediaId] actions.
  String? get mediaId => customExtras?['mediaId'] as String?;

  /// Whether this [playFromMediaId] resumes the item saved with
  /// `FlutterMediaSession.setResumptionItem` (Android Auto reconnecting, the system's resume card),
  /// rather than the user picking it.
  bool get isResumption => customExtras?['resumed'] == true;

  /// Where to start, for a [playFromMediaId] that resumes a saved item ([isResumption]); null to
  /// start from the beginning.
  Duration? get startPosition {
    final ms = customExtras?['positionMs'];
    return ms is int ? Duration(milliseconds: ms) : null;
  }

  /// The spoken search query, for [playFromSearch] actions.
  String? get query => customExtras?['query'] as String?;

  /// Whether this `pause` or `play` was caused by an audio interruption (a call, a navigation
  /// prompt) rather than by the user, when the platform reports it (Android with
  /// `setAutoHandleInterruptions`).
  bool get isInterruption => customExtras?['reason'] == 'interruption';

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
