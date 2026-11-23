package dev.wyrin.flutter_media_session

import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The Flutter engine shared by the app's screen and the media service, so a media browser such as
 * Android Auto can use the app while it isn't running (a cold start).
 *
 * Opt-in: the app declares the `dev.wyrin.flutter_media_session.background_engine` meta-data in its
 * manifest and makes its `MainActivity` extend [FlutterMediaSessionActivity] (or override
 * `provideFlutterEngine` with [provide] and `shouldDestroyEngineWithHost` to return false). The
 * service then starts the app's Dart code (its normal `main()`) without a screen when a browser needs
 * it, and the screen attaches to that same engine when the app is opened, so there is only ever one.
 */
object FlutterMediaSessionEngine {
    /** The id of the shared engine in [FlutterEngineCache]. */
    const val ENGINE_ID = "flutter_media_session_engine"

    private const val META_DATA = "dev.wyrin.flutter_media_session.background_engine"

    /**
     * The shared engine was started by the media service (a media browser needed the app while it
     * was closed), not by the app's screen. Cleared when the screen attaches to it.
     */
    @Volatile
    var startedInBackground = false
        internal set

    /** Whether the app opted into the shared engine (the manifest meta-data). */
    fun isEnabled(context: Context): Boolean = try {
        val info = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        info.metaData?.getBoolean(META_DATA, false) ?: false
    } catch (e: Exception) {
        false
    }

    /**
     * The shared engine, created and started (running the app's `main()`) if it doesn't exist yet.
     * Must be called on the main thread.
     */
    fun provide(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val appContext = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(appContext)
        loader.ensureInitializationComplete(appContext, null)
        // Plugins are registered automatically (GeneratedPluginRegistrant), this one included.
        val engine = FlutterEngine(appContext)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    /** Whether the shared engine exists (the app uses it and it was started). */
    fun isRunning(): Boolean = FlutterEngineCache.getInstance().get(ENGINE_ID) != null

    /** Ends the shared engine (the app was swiped away); the next one starts afresh. */
    fun shutDown() {
        val engine = FlutterEngineCache.getInstance().get(ENGINE_ID) ?: return
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        startedInBackground = false
        engine.destroy()
    }

    /**
     * Starts the shared engine for the media service when the app opted in and no Flutter side is
     * attached to the plugin yet. Returns whether one is now starting or running.
     */
    fun startForService(context: Context): Boolean {
        if (FlutterMediaSessionPlugin.instance != null) return true
        if (!isEnabled(context)) return false
        val start = {
            if (FlutterEngineCache.getInstance().get(ENGINE_ID) == null) startedInBackground = true
            provide(context)
        }
        if (Looper.myLooper() == Looper.getMainLooper()) start() else Handler(Looper.getMainLooper()).post { start() }
        return true
    }
}
