package dev.wyrin.flutter_media_session

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class FlutterMediaSessionPluginTest {
    @Test
    fun onMethodCall_unknownMethod_notImplemented() {
        val plugin = FlutterMediaSessionPlugin()

        val call = MethodCall("unknown", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).notImplemented()
    }

    @Test
    fun onMethodCall_setActionLayout_cachesPendingLayout() {
        val plugin = FlutterMediaSessionPlugin()

        val layoutData = mapOf(
            "slots" to listOf(
                mapOf("name" to "shuffle", "customLabel" to "Shuffle", "customIconResource" to "ic_shuffle_on"),
                mapOf("name" to "play")
            ),
            "compactIndices" to listOf(1)
        )
        val call = MethodCall("setActionLayout", layoutData)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(null)
        kotlin.test.assertEquals(layoutData, plugin.pendingActionLayout)
    }

    @Test
    fun onMethodCall_setMediaLibraryEnabled_togglesTheLibrary() {
        val plugin = FlutterMediaSessionPlugin()
        kotlin.test.assertFalse(plugin.mediaLibraryEnabled, "off until the app opts in")

        val on: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("setMediaLibraryEnabled", true), on)
        Mockito.verify(on).success(null)
        kotlin.test.assertTrue(plugin.mediaLibraryEnabled)

        val off: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("setMediaLibraryEnabled", false), off)
        Mockito.verify(off).success(null)
        kotlin.test.assertFalse(plugin.mediaLibraryEnabled)
    }

    @Test
    fun onMethodCall_setPauseWhenDucked_togglesPausingInsteadOfDucking() {
        val plugin = FlutterMediaSessionPlugin()
        kotlin.test.assertFalse(plugin.pauseWhenDucked, "off by default: the system ducks")

        val on: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("setPauseWhenDucked", true), on)
        Mockito.verify(on).success(null)
        kotlin.test.assertTrue(plugin.pauseWhenDucked)

        val off: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("setPauseWhenDucked", false), off)
        Mockito.verify(off).success(null)
        kotlin.test.assertFalse(plugin.pauseWhenDucked)
    }
}
