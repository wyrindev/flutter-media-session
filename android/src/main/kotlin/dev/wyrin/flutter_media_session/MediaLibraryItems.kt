package dev.wyrin.flutter_media_session

import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata

/**
 * A browsable media library entry as sent from Dart (`MediaLibraryItem.toJson()`).
 *
 * Parsing is kept apart from building the Media3 [MediaItem] so it can be unit tested
 * without Android framework classes.
 */
internal data class LibraryItemData(
    val id: String,
    val title: String,
    val subtitle: String?,
    val artworkUri: String?,
    val isBrowsable: Boolean,
    val isPlayable: Boolean,
) {
    /** The Media3 item a media browser (such as Android Auto) shows for this entry. */
    fun toMediaItem(): MediaItem {
        val metadata = MediaMetadata.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setArtist(subtitle)
            .setIsBrowsable(isBrowsable)
            .setIsPlayable(isPlayable)
            .setMediaType(if (isBrowsable) MediaMetadata.MEDIA_TYPE_FOLDER_MIXED else MediaMetadata.MEDIA_TYPE_MIXED)
        artworkUri?.let { metadata.setArtworkUri(Uri.parse(it)) }
        return MediaItem.Builder()
            .setMediaId(id)
            .setMediaMetadata(metadata.build())
            .build()
    }

    companion object {
        /** The id of the library's root, which browsers ask for first. */
        const val ROOT_ID = "root"

        /** The root of the library: browsable, not playable, not shown to the user. */
        val root = LibraryItemData(ROOT_ID, "Root", null, null, isBrowsable = true, isPlayable = false)

        /** Parses one entry; null when it has no id or no title. */
        fun fromMap(map: Map<*, *>): LibraryItemData? {
            val id = (map["id"] as? String)?.takeIf { it.isNotEmpty() } ?: return null
            val title = map["title"] as? String ?: return null
            return LibraryItemData(
                id = id,
                title = title,
                subtitle = map["subtitle"] as? String,
                artworkUri = (map["artworkUri"] as? String)?.takeIf { it.isNotEmpty() },
                isBrowsable = map["isBrowsable"] as? Boolean ?: false,
                isPlayable = map["isPlayable"] as? Boolean ?: true,
            )
        }

        /** Parses a list of entries from Dart, skipping malformed ones. */
        fun listFrom(value: Any?): List<LibraryItemData> =
            (value as? List<*>)?.mapNotNull { (it as? Map<*, *>)?.let(::fromMap) } ?: emptyList()
    }
}
