package dev.wyrin.flutter_media_session

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.KeyEvent

/**
 * Custom BroadcastReceiver for handling MEDIA_BUTTON actions.
 * Avoids background ForegroundServiceStartNotAllowedException on Android 12+ (API 31+)
 * by dispatching directly to the active FlutterMediaSessionService in memory.
 */
class MediaButtonReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null || Intent.ACTION_MEDIA_BUTTON != intent.action) {
            return
        }

        var keyEvent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT) as? KeyEvent
        }

        if (keyEvent == null) {
            // Fallback for intent extras sent as integer or string (e.g. adb broadcast or OEM proxies)
            val keyCodeInt = intent.getIntExtra(Intent.EXTRA_KEY_EVENT, -1).takeIf { it != -1 }
                ?: intent.getStringExtra(Intent.EXTRA_KEY_EVENT)?.toIntOrNull()
            if (keyCodeInt != null) {
                keyEvent = KeyEvent(KeyEvent.ACTION_DOWN, keyCodeInt)
            }
        }

        if (keyEvent != null) {
            Log.i("FlutterMediaSession", "MediaButtonReceiver received: keyCode=${keyEvent.keyCode}, action=${keyEvent.action}")
            val service = FlutterMediaSessionService.instance
            if (service != null) {
                if (service.handleMediaKeyEvent(keyEvent)) {
                    if (isOrderedBroadcast) {
                        abortBroadcast()
                    }
                    return
                }
            } else {
                Log.w("FlutterMediaSession", "MediaButtonReceiver: FlutterMediaSessionService is not running")
            }
        }
    }
}
