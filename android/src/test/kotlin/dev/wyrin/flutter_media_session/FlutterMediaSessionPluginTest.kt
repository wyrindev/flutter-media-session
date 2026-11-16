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
}
