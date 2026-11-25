package dev.wyrin.flutter_media_session

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * A [FlutterActivity] that uses the engine shared with the media service ([FlutterMediaSessionEngine]),
 * so the app's screen and a media browser started while the app was closed (Android Auto) use one
 * engine, and the engine keeps running when the screen closes.
 *
 * Use it as the base class of the app's `MainActivity` together with the
 * `dev.wyrin.flutter_media_session.background_engine` manifest meta-data.
 */
open class FlutterMediaSessionActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        // The app's screen is here now: whatever started the engine, it is no longer in the background only.
        FlutterMediaSessionEngine.startedInBackground = false
        return FlutterMediaSessionEngine.provide(context)
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false
}

/**
 * A [FlutterFragmentActivity] that uses the engine shared with the media service ([FlutterMediaSessionEngine]),
 * for apps that require a fragment activity (e.g. for biometric authentication).
 */
open class FlutterMediaSessionFragmentActivity : FlutterFragmentActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        FlutterMediaSessionEngine.startedInBackground = false
        return FlutterMediaSessionEngine.provide(context)
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
