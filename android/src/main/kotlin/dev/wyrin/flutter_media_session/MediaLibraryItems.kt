package dev.wyrin.flutter_media_session

import android.content.Context
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata

/**
 * Whether the app offers a media library, saved so the service knows after a cold start (Android
 * Auto can start the service without the app's Flutter side running). Written whenever the app turns
 * its library on or off.
 */
internal object MediaLibraryPrefs {
    private const val FILE = "flutter_media_session"
    private const val KEY = "media_library_enabled"

    /** The saved flag, read once per process. */
    @Volatile
    private var savedFlag: Boolean? = null

    fun saved(context: Context): Boolean =
        savedFlag ?: context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(KEY, false)
            .also { savedFlag = it }

    fun save(context: Context, enabled: Boolean) {
        savedFlag = enabled
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean(KEY, enabled).apply()
    }

    private const val RESUME_ITEM = "resumption_item"
    private const val RESUME_POSITION = "resumption_position_ms"

    fun hasResumptionItem(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).contains(RESUME_ITEM)

    /** Saves what to resume (or clears it with null), kept while the app is closed. */
    fun saveResumption(context: Context, item: Map<*, *>?, positionMs: Long) {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
        if (item == null || LibraryItemData.fromMap(item) == null) {
            prefs.remove(RESUME_ITEM).remove(RESUME_POSITION)
        } else {
            prefs.putString(RESUME_ITEM, org.json.JSONObject(item.mapKeys { it.key.toString() }).toString())
                .putLong(RESUME_POSITION, positionMs.coerceAtLeast(0))
        }
        prefs.apply()
    }

    /** Marks a resumed item (in its request extras), so the player can tell it from a pick. */
    const val RESUMED_EXTRA = "dev.wyrin.flutter_media_session.RESUMED"

    /** The saved item to resume and its position, or null. */
    fun resumption(context: Context): Pair<LibraryItemData, Long>? {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(RESUME_ITEM, null) ?: return null
        val map = try {
            val o = org.json.JSONObject(json)
            o.keys().asSequence().associateWith { k -> o.get(k).takeIf { it != org.json.JSONObject.NULL } }
        } catch (e: Exception) {
            return null
        }
        val item = LibraryItemData.fromMap(map) ?: return null
        return item to prefs.getLong(RESUME_POSITION, 0)
    }
}

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

/** What the app is asked for when a controller sets a media item on the player. */
internal object PlayRequest {
    /**
     * A voice request (a search query), a library pick (a media id) or a resumed item (a media id
     * with `resumed` and, when past the start, `positionMs`); null when the item asks for nothing.
     */
    fun of(mediaId: String, searchQuery: String?, resumed: Boolean, startPositionMs: Long): Pair<String, Map<String, Any>>? {
        if (searchQuery != null) return "playFromSearch" to mapOf("query" to searchQuery)
        if (mediaId.isEmpty()) return null
        val args = mutableMapOf<String, Any>("mediaId" to mediaId)
        if (resumed) {
            args["resumed"] = true
            if (startPositionMs > 0) args["positionMs"] = startPositionMs
        }
        return "playFromMediaId" to args
    }
}
