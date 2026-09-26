package dev.wyrin.flutter_media_session

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.media3.session.MediaSession

/**
 * Compatibility handler for media button routing on Android 11 (API <= 30) and older versions.
 *
 * Configures legacy session flags, registers an initial silent AudioTrack for system audio policy
 * tracking, and intercepts media button events before they reach Media3's legacy stub.
 */
internal object MediaButtonRoutingCompat {

    private const val TAG = "FlutterMediaSession"

    private const val FLAG_HANDLES_MEDIA_BUTTONS = 1
    private const val FLAG_HANDLES_TRANSPORT_CONTROLS = 2

    fun setupLegacyRouting(context: Context, mediaSession: MediaSession?) {
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.R || mediaSession == null) {
            return
        }

        configureSessionCompat(context, mediaSession)
        ensureAudioPlaybackRegistration()
    }

    private var persistentSilentTrack: android.media.AudioTrack? = null

    fun onSessionDestroy() {
        try {
            persistentSilentTrack?.stop()
            persistentSilentTrack?.release()
            persistentSilentTrack = null
        } catch (_: Exception) {}
    }

    private fun ensureAudioPlaybackRegistration() {
        if (persistentSilentTrack != null) return
        try {
            val sampleRate = 8000
            val minBuf = android.media.AudioTrack.getMinBufferSize(
                sampleRate,
                android.media.AudioFormat.CHANNEL_OUT_MONO,
                android.media.AudioFormat.ENCODING_PCM_16BIT
            )
            val audioAttributes = android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val audioFormat = android.media.AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO)
                .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                .build()
            val track = android.media.AudioTrack(
                audioAttributes,
                audioFormat,
                minBuf,
                android.media.AudioTrack.MODE_STREAM,
                android.media.AudioManager.AUDIO_SESSION_ID_GENERATE
            )
            track.play()
            val silentBytes = ByteArray(minBuf)
            track.write(silentBytes, 0, minBuf)
            track.pause()
            persistentSilentTrack = track
            Log.d(TAG, "MediaButtonRoutingCompat: Registered silent AudioTrack for UID tracking")
        } catch (e: Exception) {
            Log.w(TAG, "MediaButtonRoutingCompat: Failed to register AudioTrack: ${e.message}")
        }
    }

    private fun configureSessionCompat(context: Context, mediaSession: MediaSession) {
        try {
            val sessionCompat = findSessionCompat(mediaSession)
            if (sessionCompat != null) {
                val flags = FLAG_HANDLES_MEDIA_BUTTONS or FLAG_HANDLES_TRANSPORT_CONTROLS
                invokeMethod(sessionCompat, "setFlags", arrayOf(Int::class.javaPrimitiveType ?: java.lang.Integer.TYPE), arrayOf(flags))
                invokeMethod(sessionCompat, "setActive", arrayOf(Boolean::class.javaPrimitiveType ?: java.lang.Boolean.TYPE), arrayOf(true))

                var c: Class<*>? = sessionCompat.javaClass
                var impl: Any? = null
                while (c != null && c != Any::class.java) {
                    try {
                        val f = c.getDeclaredField("mImpl").apply { isAccessible = true }
                        impl = f.get(sessionCompat)
                        break
                    } catch (_: NoSuchFieldException) {}
                    c = c.superclass
                }
                if (impl != null) {
                    var implClass: Class<*>? = impl.javaClass
                    while (implClass != null && implClass != Any::class.java) {
                        try {
                            val f = implClass.getDeclaredField("mSessionFwk").apply { isAccessible = true }
                            val sessionFwk = f.get(impl) as? android.media.session.MediaSession
                            if (sessionFwk != null) {
                                sessionFwk.setFlags(flags)
                                sessionFwk.isActive = true
                            }
                            break
                        } catch (_: NoSuchFieldException) {}
                        implClass = implClass.superclass
                    }
                }

                hookCallbackMessageHandler(context, sessionCompat)
            }
        } catch (e: Exception) {
            Log.w(TAG, "MediaButtonRoutingCompat: Could not configure sessionCompat: ${e.message}")
        }
    }

    private fun hookCallbackMessageHandler(context: Context, sessionCompat: Any) {
        try {
            var c: Class<*>? = sessionCompat.javaClass
            var impl: Any? = null
            while (c != null && c != Any::class.java) {
                try {
                    val f = c.getDeclaredField("mImpl").apply { isAccessible = true }
                    impl = f.get(sessionCompat)
                    break
                } catch (_: NoSuchFieldException) {}
                c = c.superclass
            }

            if (impl != null) {
                var implClass: Class<*>? = impl.javaClass
                while (implClass != null && implClass != Any::class.java) {
                    try {
                        val sessionFwkField = implClass.getDeclaredField("mSessionFwk").apply { isAccessible = true }
                        val sessionFwk = sessionFwkField.get(impl) as? android.media.session.MediaSession
                        if (sessionFwk != null) {
                            var fwkClass: Class<*>? = sessionFwk.javaClass
                            while (fwkClass != null && fwkClass != Any::class.java) {
                                try {
                                    val cbField = fwkClass.getDeclaredField("mCallback").apply { isAccessible = true }
                                    val originalHandler = cbField.get(sessionFwk) as? android.os.Handler
                                    if (originalHandler != null) {
                                        val mCallbackField = android.os.Handler::class.java.getDeclaredField("mCallback").apply { isAccessible = true }
                                        val existingCallback = mCallbackField.get(originalHandler) as? android.os.Handler.Callback
                                        mCallbackField.set(originalHandler, android.os.Handler.Callback { msg ->
                                            try {
                                                var intent = msg.obj as? Intent
                                                if (intent == null && msg.obj != null) {
                                                    val objClass = msg.obj.javaClass
                                                    if (objClass.name == "android.util.Pair") {
                                                        try {
                                                            val secondField = objClass.getField("second")
                                                            intent = secondField.get(msg.obj) as? Intent
                                                        } catch (_: Exception) {}
                                                    }
                                                }
                                                val keyEvent = intent?.getParcelableExtra<android.view.KeyEvent>(Intent.EXTRA_KEY_EVENT)
                                                if (keyEvent != null || msg.what == 2) {
                                                    if (keyEvent != null) {
                                                        FlutterMediaSessionService.instance?.handleMediaKeyEvent(keyEvent)
                                                        return@Callback true
                                                    }
                                                }
                                                return@Callback existingCallback?.handleMessage(msg) ?: false
                                            } catch (t: Throwable) {
                                                Log.w(TAG, "MediaButtonRoutingCompat: Error handling media button event: ${t.message}")
                                                return@Callback true
                                            }
                                        })
                                    }
                                    break
                                } catch (_: NoSuchFieldException) {}
                                fwkClass = fwkClass.superclass
                            }
                        }
                        break
                    } catch (_: NoSuchFieldException) {}
                    implClass = implClass.superclass
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "MediaButtonRoutingCompat: hookCallbackMessageHandler failed: ${e.message}")
        }
    }

    private fun findSessionCompat(obj: Any?): Any? {
        if (obj == null) return null
        try {
            val implField = obj.javaClass.getDeclaredField("impl").apply { isAccessible = true }
            val impl = implField.get(obj)
            if (impl != null) {
                var curr: Class<*>? = impl.javaClass
                while (curr != null && curr != Any::class.java) {
                    try {
                        val sessionCompatField = curr.getDeclaredField("sessionCompat").apply { isAccessible = true }
                        val sessionCompat = sessionCompatField.get(impl)
                        if (sessionCompat != null) return sessionCompat
                    } catch (_: NoSuchFieldException) {}
                    curr = curr.superclass
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "MediaButtonRoutingCompat: Direct sessionCompat lookup failed: ${e.message}")
        }

        fun search(currObj: Any?, depth: Int): Any? {
            if (currObj == null || depth > 3) return null
            var c: Class<*>? = currObj.javaClass
            while (c != null && c != Any::class.java) {
                for (f in c.declaredFields) {
                    try {
                        f.isAccessible = true
                        val v = f.get(currObj) ?: continue
                        if (v.javaClass.name.contains("MediaSessionCompat") || f.type.name.contains("MediaSessionCompat")) {
                            return v
                        }
                        if (depth < 2 && !f.type.isPrimitive && !f.type.name.startsWith("java.") && !f.type.name.startsWith("android.")) {
                            val found = search(v, depth + 1)
                            if (found != null) return found
                        }
                    } catch (_: Exception) {}
                }
                c = c.superclass
            }
            return null
        }
        return search(obj, 0)
    }

    private fun invokeMethod(target: Any, methodName: String, paramTypes: Array<Class<*>>, args: Array<Any?>): Boolean {
        var c: Class<*>? = target.javaClass
        while (c != null && c != Any::class.java) {
            try {
                val method = c.getMethod(methodName, *paramTypes)
                method.invoke(target, *args)
                return true
            } catch (_: NoSuchMethodException) {
                c = c.superclass
            } catch (e: Exception) {
                Log.w(TAG, "MediaButtonRoutingCompat: Invoking $methodName failed: ${e.message}")
                return false
            }
        }
        return false
    }
}
