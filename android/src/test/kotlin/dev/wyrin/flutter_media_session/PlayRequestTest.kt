package dev.wyrin.flutter_media_session

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class PlayRequestTest {
    @Test
    fun `a search query is a voice request`() {
        assertEquals(
            "playFromSearch" to mapOf("query" to "song 3"),
            PlayRequest.of(mediaId = "", searchQuery = "song 3", resumed = false, startPositionMs = 0),
        )
    }

    @Test
    fun `a media id is a pick, without a position`() {
        assertEquals(
            "playFromMediaId" to mapOf<String, Any>("mediaId" to "track-2"),
            PlayRequest.of(mediaId = "track-2", searchQuery = null, resumed = false, startPositionMs = 5000),
        )
    }

    @Test
    fun `a resumed item carries the flag and its position`() {
        assertEquals(
            "playFromMediaId" to mapOf<String, Any>("mediaId" to "track-2", "resumed" to true, "positionMs" to 177958L),
            PlayRequest.of(mediaId = "track-2", searchQuery = null, resumed = true, startPositionMs = 177958),
        )
    }

    @Test
    fun `a resumed item at the start has no position`() {
        assertEquals(
            "playFromMediaId" to mapOf<String, Any>("mediaId" to "track-2", "resumed" to true),
            PlayRequest.of(mediaId = "track-2", searchQuery = null, resumed = true, startPositionMs = 0),
        )
    }

    @Test
    fun `an item with neither asks for nothing`() {
        assertNull(PlayRequest.of(mediaId = "", searchQuery = null, resumed = false, startPositionMs = 0))
    }
}
