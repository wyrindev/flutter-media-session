package dev.wyrin.flutter_media_session

import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build

/**
 * Flutter plugin for managing system media sessions on Android.
 * Integrates with Media3 to provide system-level media controls, metadata, and playback state synchronization.
 */
@UnstableApi
class FlutterMediaSessionPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private var activity: Activity? = null
    private var pendingPermissionResult: Result? = null

    private var pendingMetadata: Map<String, Any?>? = null
    private var pendingPlaybackState: Map<String, Any?>? = null
    var pendingAvailableActions: List<Any>? = null
    private var pendingActivateResult: Result? = null
    /**
     * When true, the service requests audio focus while playing and forwards
     * focus events as media actions. Mirrors the user-facing
     * `setHandlesInterruptions` API; defaults to false so we don't fight other
     * audio plugins (audioplayers, just_audio) that already manage focus.
     * Persisted across service restarts so the setting survives deactivate.
     */
    var handlesInterruptions: Boolean = false
        private set

    /**
     * When true, the service holds a partial wake lock + high-perf Wi-Fi lock
     * for the lifetime of the session so a backgrounded off-device session
     * (e.g. casting) is not reaped by Doze. Mirrors the user-facing
     * `setBackgroundKeepAlive` API; defaults to false. Persisted across service
     * restarts so the setting survives a service recreate.
     */
    var backgroundKeepAlive: Boolean = false
        private set

    companion object {
        private const val REQUEST_NOTIFICATION_PERMISSION = 1101
        
        /**
         * Singleton instance for access from the media service.
         */
        var instance: FlutterMediaSessionPlugin? = null
            private set
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_media_session")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_media_session_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private var serviceConnection: android.content.ServiceConnection? = null

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "activate" -> {
                val service = FlutterMediaSessionService.instance
                if (service != null) {
                    syncPendingData()
                    result.success(null)
                } else {
                    pendingActivateResult = result
                    val intent = Intent(context, FlutterMediaSessionService::class.java)
                    serviceConnection = object : android.content.ServiceConnection {
                        override fun onServiceConnected(name: android.content.ComponentName?, service: android.os.IBinder?) {}
                        override fun onServiceDisconnected(name: android.content.ComponentName?) {
                            serviceConnection = null
                        }
                    }
                    try {
                        try {
                            context.startService(intent)
                        } catch (e: Exception) {
                            android.util.Log.w("FlutterMediaSession", "startService failed, falling back to bindService only", e)
                        }
                        context.bindService(intent, serviceConnection!!, Context.BIND_AUTO_CREATE)
                    } catch (e: Exception) {
                        pendingActivateResult?.error("SERVICE_ERROR", "Failed to start or bind service: ${e.message}", null)
                        pendingActivateResult = null
                    }
                }
            }
            "deactivate" -> {
                FlutterMediaSessionService.instance?.deactivate()
                val intent = Intent(context, FlutterMediaSessionService::class.java)
                serviceConnection?.let {
                    try { context.unbindService(it) } catch (e: Exception) {}
                    serviceConnection = null
                }
                context.stopService(intent)
                result.success(null)
            }
            "updateMetadata" -> {
                val arguments = call.arguments as? Map<String, Any?>
                if (FlutterMediaSessionService.instance != null) {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val album = call.argument<String>("album")
                    val artworkUri = call.argument<String>("artworkUri")
                    val durationMs = (call.argument<Number>("durationMs"))?.toLong() ?: 0L
                    FlutterMediaSessionService.instance?.updateMetadata(title, artist, album, artworkUri, durationMs)
                } else {
                    pendingMetadata = arguments
                }
                result.success(null)
            }
            "updatePlaybackState" -> {
                val arguments = call.arguments as? Map<String, Any?>
                if (FlutterMediaSessionService.instance != null) {
                    val status = call.argument<String>("status") ?: "idle"
                    val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    val speed = (call.argument<Number>("speed"))?.toFloat() ?: 1.0f
                    val bufferedPositionMs = (call.argument<Number>("bufferedPositionMs"))?.toLong() ?: 0L
                    val repeatMode = (call.argument<Number>("repeatMode"))?.toInt() ?: 0
                    val shuffleModeEnabled = call.argument<Boolean>("shuffleModeEnabled") ?: false
                    FlutterMediaSessionService.instance?.updatePlaybackState(status, positionMs, speed, bufferedPositionMs, repeatMode, shuffleModeEnabled)
                } else {
                    pendingPlaybackState = arguments
                }
                result.success(null)
            }
            "updateAvailableActions" -> {
                @Suppress("UNCHECKED_CAST")
                val actions = call.arguments as? List<Any>
                if (FlutterMediaSessionService.instance != null) {
                    FlutterMediaSessionService.instance?.updateAvailableActions(actions)
                } else {
                    pendingAvailableActions = actions
                }
                result.success(null)
            }
            "requestNotificationPermission" -> {
                requestNotificationPermission(result)
            }
            "setHandlesInterruptions", "setAutoHandleInterruptions" -> {
                val enabled = call.arguments as? Boolean ?: false
                handlesInterruptions = enabled
                FlutterMediaSessionService.instance?.onHandlesInterruptionsChanged(enabled)
                result.success(null)
            }
            "setBackgroundKeepAlive" -> {
                val enabled = call.arguments as? Boolean ?: false
                backgroundKeepAlive = enabled
                FlutterMediaSessionService.instance?.applyBackgroundKeepAlive(enabled)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestNotificationPermission(result: Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(true)
            return
        }

        if (ContextCompat.checkSelfPermission(context, "android.permission.POST_NOTIFICATIONS") == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        pendingPermissionResult = result
        activity?.requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), REQUEST_NOTIFICATION_PERMISSION)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return true
        }
        return false
    }

    private var originalWindowCallback: android.view.Window.Callback? = null

    private fun attachWindowCallback(act: Activity) {
        val window = act.window ?: return
        val currentCallback = window.callback
        if (currentCallback is MediaWindowCallback) return
        originalWindowCallback = currentCallback
        window.callback = MediaWindowCallback(currentCallback)
    }

    private fun detachWindowCallback(act: Activity?) {
        val window = act?.window ?: return
        if (window.callback is MediaWindowCallback) {
            window.callback = originalWindowCallback
        }
        originalWindowCallback = null
    }

    private inner class MediaWindowCallback(
        private val localOriginalCallback: android.view.Window.Callback?
    ) : android.view.Window.Callback by (localOriginalCallback ?: DummyWindowCallback()) {
        override fun dispatchKeyEvent(event: android.view.KeyEvent?): Boolean {
            if (event != null) {
                when (event.keyCode) {
                    android.view.KeyEvent.KEYCODE_MEDIA_PLAY,
                    android.view.KeyEvent.KEYCODE_MEDIA_PAUSE,
                    android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                    android.view.KeyEvent.KEYCODE_HEADSETHOOK,
                    android.view.KeyEvent.KEYCODE_MEDIA_NEXT,
                    android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS,
                    android.view.KeyEvent.KEYCODE_MEDIA_STOP,
                    android.view.KeyEvent.KEYCODE_MEDIA_FAST_FORWARD,
                    android.view.KeyEvent.KEYCODE_MEDIA_REWIND -> {
                        val handled = FlutterMediaSessionService.instance?.handleMediaKeyEvent(event) ?: false
                        if (handled) {
                            return true
                        }
                    }
                }
            }
            return localOriginalCallback?.dispatchKeyEvent(event) ?: false
        }
    }

    private class DummyWindowCallback : android.view.Window.Callback {
        override fun dispatchKeyEvent(event: android.view.KeyEvent?): Boolean = false
        override fun dispatchKeyShortcutEvent(event: android.view.KeyEvent?): Boolean = false
        override fun dispatchTouchEvent(event: android.view.MotionEvent?): Boolean = false
        override fun dispatchTrackballEvent(event: android.view.MotionEvent?): Boolean = false
        override fun dispatchGenericMotionEvent(event: android.view.MotionEvent?): Boolean = false
        override fun dispatchPopulateAccessibilityEvent(event: android.view.accessibility.AccessibilityEvent?): Boolean = false
        override fun onCreatePanelView(featureId: Int): android.view.View? = null
        override fun onCreatePanelMenu(featureId: Int, menu: android.view.Menu): Boolean = false
        override fun onPreparePanel(featureId: Int, view: android.view.View?, menu: android.view.Menu): Boolean = false
        override fun onMenuOpened(featureId: Int, menu: android.view.Menu): Boolean = false
        override fun onMenuItemSelected(featureId: Int, item: android.view.MenuItem): Boolean = false
        override fun onWindowAttributesChanged(attrs: android.view.WindowManager.LayoutParams?) {}
        override fun onContentChanged() {}
        override fun onWindowFocusChanged(hasFocus: Boolean) {}
        override fun onAttachedToWindow() {}
        override fun onDetachedFromWindow() {}
        override fun onPanelClosed(featureId: Int, menu: android.view.Menu) {}
        override fun onSearchRequested(): Boolean = false
        override fun onSearchRequested(searchEvent: android.view.SearchEvent?): Boolean = false
        override fun onWindowStartingActionMode(callback: android.view.ActionMode.Callback?): android.view.ActionMode? = null
        override fun onWindowStartingActionMode(callback: android.view.ActionMode.Callback?, type: Int): android.view.ActionMode? = null
        override fun onActionModeStarted(mode: android.view.ActionMode?) {}
        override fun onActionModeFinished(mode: android.view.ActionMode?) {}
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        attachWindowCallback(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachWindowCallback(activity)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        attachWindowCallback(binding.activity)
    }

    override fun onDetachedFromActivity() {
        detachWindowCallback(activity)
        activity = null
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        FlutterMediaSessionService.instance?.deactivate()
        serviceConnection?.let {
            try { context.unbindService(it) } catch (e: Exception) {}
            serviceConnection = null
        }
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        instance = null
    }

    /**
     * Sends a media action event back to the Flutter side.
     * @param action The name of the action (e.g., "play", "pause").
     * @param args Optional arguments for the action (e.g., seek position).
     */
    fun sendAction(action: String, args: Any? = null) {
        android.util.Log.i("FlutterMediaSession", "sendAction: action=$action, args=$args, eventSink=${eventSink != null}")
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            if (args != null) {
                eventSink?.success(mapOf("action" to action, "args" to args))
            } else {
                eventSink?.success(action)
            }
        }
    }

    /**
     * Called when the MediaSessionService has finished creating and is ready.
     */
    fun onServiceCreated() {
        syncPendingData()
        pendingActivateResult?.success(null)
        pendingActivateResult = null
        // Re-apply the keep-alive setting in case the service was recreated
        // while it was enabled.
        if (backgroundKeepAlive) {
            FlutterMediaSessionService.instance?.applyBackgroundKeepAlive(true)
        }
    }

    /**
     * Synchronizes metadata and playback state that were received before the service was fully initialized.
     */
    fun syncPendingData() {
        val service = FlutterMediaSessionService.instance ?: return
        
        pendingMetadata?.let {
            val title = it["title"] as? String
            val artist = it["artist"] as? String
            val album = it["album"] as? String
            val artworkUri = it["artworkUri"] as? String
            val durationMs = (it["durationMs"] as? Number)?.toLong() ?: 0L
            service.updateMetadata(title, artist, album, artworkUri, durationMs)
            pendingMetadata = null
        }
        
        pendingPlaybackState?.let {
            val status = it["status"] as? String ?: "idle"
            val positionMs = (it["positionMs"] as? Number)?.toLong() ?: 0L
            val speed = (it["speed"] as? Number)?.toFloat() ?: 1.0f
            val bufferedPositionMs = (it["bufferedPositionMs"] as? Number)?.toLong() ?: 0L
            val repeatMode = (it["repeatMode"] as? Number)?.toInt() ?: 0
            val shuffleModeEnabled = it["shuffleModeEnabled"] as? Boolean ?: false
            service.updatePlaybackState(status, positionMs, speed, bufferedPositionMs, repeatMode, shuffleModeEnabled)
            pendingPlaybackState = null
        }

        pendingAvailableActions?.let {
            service.updateAvailableActions(it)
            pendingAvailableActions = null
        }
    }
}
