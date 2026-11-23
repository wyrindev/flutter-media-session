/// An entry in the browsable media library that media browsers such as Android Auto show.
///
/// A library is a tree: the browser first asks for the children of [MediaLibraryItem.rootId],
/// then for the children of any item that [isBrowsable]. Picking an item that [isPlayable]
/// arrives as a [MediaAction.playFromMediaId] action carrying its [id].
class MediaLibraryItem {
  /// The id the browser asks for first; its children are the library's top level.
  static const rootId = 'root';

  /// Unique within the library. Passed back in [MediaAction.playFromMediaId] and in requests for
  /// this item's children.
  final String id;

  /// The main line shown for the item.
  final String title;

  /// An optional second line (for example an artist, or a chapter).
  final String? subtitle;

  /// Optional artwork, as a `content://`, `file://` or `https://` URI.
  final String? artworkUri;

  /// Whether the item has children to browse (a folder).
  final bool isBrowsable;

  /// Whether picking the item starts playback.
  final bool isPlayable;

  /// Creates a library entry. By default it is a playable item, not a folder.
  const MediaLibraryItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.artworkUri,
    this.isBrowsable = false,
    this.isPlayable = true,
  });

  /// Converts this item to a JSON map for the platform side.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (artworkUri != null) 'artworkUri': artworkUri,
      'isBrowsable': isBrowsable,
      'isPlayable': isPlayable,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaLibraryItem &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          artworkUri == other.artworkUri &&
          isBrowsable == other.isBrowsable &&
          isPlayable == other.isPlayable;

  @override
  int get hashCode =>
      Object.hash(id, title, subtitle, artworkUri, isBrowsable, isPlayable);

  @override
  String toString() => 'MediaLibraryItem($id, $title)';
}

/// Gives the children of the library node [parentId] ([MediaLibraryItem.rootId] for the top level).
typedef MediaLibraryChildrenProvider = Future<List<MediaLibraryItem>> Function(
    String parentId);
