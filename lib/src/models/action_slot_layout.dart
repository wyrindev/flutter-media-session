import 'package:flutter/foundation.dart';
import 'media_action.dart';

/// Represents a customizable action slot layout for system media controls.
///
/// Controls the order and placement of media buttons (such as in Android
/// notification and media card controls), as well as which actions appear in
/// compact view.
@immutable
class ActionSlotLayout {
  /// The ordered list of action slots (up to 5 actions).
  final List<MediaAction> slots;

  /// The indices of actions from [slots] to display in compact mode
  /// (e.g., collapsed Android notification).
  ///
  /// Maximum of 3 indices. If omitted or null, default indices are inferred.
  final List<int>? compactActionIndices;

  /// Creates a new [ActionSlotLayout] with the specified [slots] list.
  const ActionSlotLayout(
    this.slots, {
    this.compactActionIndices,
  });

  /// Creates an [ActionSlotLayout] from a map of slot indices to [MediaAction].
  factory ActionSlotLayout.fromMap(
    Map<int, MediaAction> map, {
    List<int>? compactActionIndices,
  }) {
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ActionSlotLayout(
      sortedEntries.map((e) => e.value).toList(),
      compactActionIndices: compactActionIndices,
    );
  }

  /// Preset for modern symmetrical layout:
  /// `[left (custom1), skipPrevious, playPause, skipNext, right (custom2)]`.
  ///
  /// Default compact indices are the center controls `[1, 2, 3]`.
  factory ActionSlotLayout.symmetrical({
    MediaAction? left,
    MediaAction skipPrevious = MediaAction.skipToPrevious,
    MediaAction playPause = MediaAction.play,
    MediaAction skipNext = MediaAction.skipToNext,
    MediaAction? right,
    List<int>? compactActionIndices,
  }) {
    final list = <MediaAction>[
      if (left != null) left,
      skipPrevious,
      playPause,
      skipNext,
      if (right != null) right,
    ];

    List<int>? defaultCompact;
    if (compactActionIndices == null) {
      final prevIndex = list.indexOf(skipPrevious);
      final playIndex = list.indexOf(playPause);
      final nextIndex = list.indexOf(skipNext);
      defaultCompact = [
        if (prevIndex != -1) prevIndex,
        if (playIndex != -1) playIndex,
        if (nextIndex != -1) nextIndex,
      ];
    }

    return ActionSlotLayout(
      list,
      compactActionIndices: compactActionIndices ?? defaultCompact,
    );
  }

  /// Preset for legacy sequential layout:
  /// `[skipPrevious, playPause, skipNext, custom1, custom2]`.
  ///
  /// Default compact indices are `[0, 1, 2]`.
  factory ActionSlotLayout.sequential({
    MediaAction skipPrevious = MediaAction.skipToPrevious,
    MediaAction playPause = MediaAction.play,
    MediaAction skipNext = MediaAction.skipToNext,
    MediaAction? custom1,
    MediaAction? custom2,
    List<int>? compactActionIndices,
  }) {
    final list = <MediaAction>[
      skipPrevious,
      playPause,
      skipNext,
      if (custom1 != null) custom1,
      if (custom2 != null) custom2,
    ];

    List<int>? defaultCompact;
    if (compactActionIndices == null) {
      final prevIndex = list.indexOf(skipPrevious);
      final playIndex = list.indexOf(playPause);
      final nextIndex = list.indexOf(skipNext);
      defaultCompact = [
        if (prevIndex != -1) prevIndex,
        if (playIndex != -1) playIndex,
        if (nextIndex != -1) nextIndex,
      ];
    }

    return ActionSlotLayout(
      list,
      compactActionIndices: compactActionIndices ?? defaultCompact,
    );
  }

  /// Converts the slot layout to a [Map] of slot index to [MediaAction].
  Map<int, MediaAction> toMap() => slots.asMap();

  /// Returns the set of unique [MediaAction]s contained in the slots.
  Set<MediaAction> get allActions => slots.toSet();

  /// Serializes this layout for platform channel transmission.
  Map<String, dynamic> toJson() {
    return {
      'slots': slots.map((a) => a.toJson()).toList(),
      if (compactActionIndices != null) 'compactIndices': compactActionIndices,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionSlotLayout &&
          runtimeType == other.runtimeType &&
          listEquals(slots, other.slots) &&
          listEquals(compactActionIndices, other.compactActionIndices);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(slots),
        compactActionIndices != null
            ? Object.hashAll(compactActionIndices!)
            : null,
      );

  @override
  String toString() =>
      'ActionSlotLayout(slots: $slots, compactActionIndices: $compactActionIndices)';
}
