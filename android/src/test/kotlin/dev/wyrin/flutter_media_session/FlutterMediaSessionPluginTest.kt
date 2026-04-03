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
}
