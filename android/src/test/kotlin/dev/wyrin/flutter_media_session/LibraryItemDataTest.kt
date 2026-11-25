package dev.wyrin.flutter_media_session

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class LibraryItemDataTest {
    @Test
    fun fromMap_fullEntry() {
        val item = LibraryItemData.fromMap(
            mapOf(
                "id" to "n1",
                "title" to "Novel",
                "subtitle" to "Chapter 3",
                "artworkUri" to "https://example.com/c.png",
                "isBrowsable" to false,
                "isPlayable" to true,
            )
        )
        assertEquals(LibraryItemData("n1", "Novel", "Chapter 3", "https://example.com/c.png", isBrowsable = false, isPlayable = true), item)
    }

    @Test
    fun fromMap_defaultsToPlayableAndDropsEmptyArtwork() {
        val item = LibraryItemData.fromMap(mapOf("id" to "n1", "title" to "Novel", "artworkUri" to ""))
        assertEquals(LibraryItemData("n1", "Novel", null, null, isBrowsable = false, isPlayable = true), item)
    }

    @Test
    fun fromMap_needsIdAndTitle() {
        assertNull(LibraryItemData.fromMap(mapOf("title" to "No id")))
        assertNull(LibraryItemData.fromMap(mapOf("id" to "", "title" to "Empty id")))
        assertNull(LibraryItemData.fromMap(mapOf("id" to "x")))
    }

    @Test
    fun listFrom_skipsMalformedEntries() {
        val items = LibraryItemData.listFrom(
            listOf(
                mapOf("id" to "a", "title" to "A", "isBrowsable" to true, "isPlayable" to false),
                "not a map",
                mapOf("title" to "no id"),
                mapOf("id" to "b", "title" to "B"),
            )
        )
        assertEquals(listOf("a", "b"), items.map { it.id })
        assertEquals(true, items[0].isBrowsable)
        assertEquals(false, items[0].isPlayable)
    }

    @Test
    fun listFrom_notAList_isEmpty() {
        assertEquals(emptyList(), LibraryItemData.listFrom(null))
        assertEquals(emptyList(), LibraryItemData.listFrom("junk"))
    }

    @Test
    fun root_isBrowsableAndNotPlayable() {
        assertEquals(LibraryItemData.ROOT_ID, LibraryItemData.root.id)
        assertEquals(true, LibraryItemData.root.isBrowsable)
        assertEquals(false, LibraryItemData.root.isPlayable)
    }
}
