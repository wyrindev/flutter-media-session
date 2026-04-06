package dev.wyrin.flutter_media_session

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * A Media3 MediaSessionService that manages the media session lifecycle and player state.
 * It uses a ForwardingPlayer to handle media control commands (play, pause, seek, etc.) 
 * and notifies the Flutter side via the plugin's event channel.
 */
@UnstableApi
class FlutterMediaSessionService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private lateinit var player: ForwardingPlayer

    companion object {
        /**
         * Singleton instance for the service, set during onCreate.
         */
        var instance: FlutterMediaSessionService? = null
            private set
    }

    private var isReceiverRegistered = false

    /**
     * BroadcastReceiver to handle ACTION_AUDIO_BECOMING_NOISY, which typically happens
     * when headphones are unplugged. It notifies the Flutter side to pause playback.
     */
    private val noisyReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context, intent: android.content.Intent) {
            if (android.media.AudioManager.ACTION_AUDIO_BECOMING_NOISY == intent.action) {
                // Notify Flutter side to pause playback
                FlutterMediaSessionPlugin.instance?.sendAction("pause")
            }
        }
    }

    override fun onCreate() {
        instance = this
        player = ForwardingPlayer()

        // Use the launch intent of the app for the session activity
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        // Build the session BEFORE super.onCreate() — Media3 may query
        // onGetSession() during initialization.
        mediaSession = MediaSession.Builder(this, player)
            .setSessionActivity(pendingIntent)
            .setCallback(CustomMediaSessionCallback())
            .build()

        super.onCreate()

        // Register the session with the service so Media3's
        // MediaNotificationManager creates its internal MediaController
        // and starts the notification pipeline.
        addSession(mediaSession!!)

        // Sync any data that was sent to the plugin before the service was ready
        FlutterMediaSessionPlugin.instance?.syncPendingData()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onDestroy() {
        instance = null
        if (isReceiverRegistered) {
            unregisterReceiver(noisyReceiver)
            isReceiverRegistered = false
        }
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        super.onDestroy()
    }

    /**
     * Updates the media metadata displayed in the system controls.
     */
    fun updateMetadata(title: String?, artist: String?, album: String?, artworkUri: String?, durationMs: Long) {
        player.updateMetadata(title, artist, album, artworkUri, durationMs)
    }

    /**
     * Updates the playback state (status, position, speed) in the system controls.
     */
    fun updatePlaybackState(status: String, positionMs: Long, speed: Float, bufferedPositionMs: Long) {
        player.updatePlaybackState(status, positionMs, speed, bufferedPositionMs)
    }

    /**
     * Updates which media actions are available in the system controls.
     * Pass null to enable all actions.
     */
    fun updateAvailableActions(actions: List<String>?) {
        player.updateAvailableActions(actions)
    }

    /**
     * Callback handler for MediaSession events.
     */
    inner class CustomMediaSessionCallback : MediaSession.Callback {
        override fun onConnect(
            session: MediaSession,
            controller: MediaSession.ControllerInfo
        ): MediaSession.ConnectionResult {
            return super.onConnect(session, controller)
        }
    }

    /**
     * Custom player implementation that forwards state changes to Media3 and commands to Flutter.
     */
    inner class ForwardingPlayer : androidx.media3.common.SimpleBasePlayer(mainLooper) {
        private var currentMetadata: MediaMetadata = MediaMetadata.EMPTY
        private var playbackStatus: String = "buffering"
        private var positionMs: Long = 0
        private var speed: Float = 1.0f
        private var bufferedPositionMs: Long = 0
        private var durationMs: Long = C.TIME_UNSET
        private var availableActions: List<String>? = null // null = all enabled

        /**
         * Updates the internal metadata state and triggers a state invalidation.
         */
        fun updateMetadata(title: String?, artist: String?, album: String?, artworkUri: String?, durationMs: Long) {
            currentMetadata = MediaMetadata.Builder()
                .setTitle(title)
                .setDisplayTitle(title)
                .setArtist(artist)
                .setSubtitle(artist)
                .setAlbumTitle(album)
                .setAlbumArtist(artist)
                .setArtworkUri(artworkUri?.let { android.net.Uri.parse(it) })
                .build()
            this.durationMs = if (durationMs > 0) durationMs else C.TIME_UNSET
            invalidateState()
        }

        /**
         * Updates the internal playback state and triggers a state invalidation.
         * Also manages the registration of the ACTION_AUDIO_BECOMING_NOISY receiver.
         */
        /**
         * Updates which actions are available. Pass null to enable all.
         */
        fun updateAvailableActions(actions: List<String>?) {
            this.availableActions = actions
            invalidateState()
        }

        fun updatePlaybackState(status: String, positionMs: Long, speed: Float, bufferedPositionMs: Long) {
            val isPlaying = status == "playing"

            this.playbackStatus = status
            this.positionMs = positionMs
            this.speed = speed
            this.bufferedPositionMs = bufferedPositionMs
            invalidateState()

            // Manage AudioBecomingNoisy receiver based on playback state
            if (isPlaying && !isReceiverRegistered) {
                registerReceiver(noisyReceiver, android.content.IntentFilter(android.media.AudioManager.ACTION_AUDIO_BECOMING_NOISY))
                isReceiverRegistered = true
            } else if (!isPlaying && isReceiverRegistered) {
                unregisterReceiver(noisyReceiver)
                isReceiverRegistered = false
            }
        }

        override fun getState(): State {
            val playerState = when (playbackStatus) {
                "playing", "paused" -> Player.STATE_READY
                "buffering" -> Player.STATE_BUFFERING
                "ended" -> Player.STATE_ENDED
                else -> Player.STATE_IDLE
            }
            val playWhenReady = playbackStatus == "playing"
            
            val commandsBuilder = Player.Commands.Builder()
            val actions = availableActions
            if (actions == null) {
                commandsBuilder.addAllCommands()
            } else {
                // Always allow basic commands
                commandsBuilder.add(Player.COMMAND_PLAY_PAUSE)
                commandsBuilder.add(Player.COMMAND_STOP)
                commandsBuilder.add(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)
                commandsBuilder.add(Player.COMMAND_GET_METADATA)
                commandsBuilder.add(Player.COMMAND_GET_TIMELINE)
                if (actions.contains("seekTo")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM)
                    commandsBuilder.add(Player.COMMAND_SEEK_BACK)
                    commandsBuilder.add(Player.COMMAND_SEEK_FORWARD)
                }
                if (actions.contains("skipToNext")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_NEXT)
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
                }
                if (actions.contains("skipToPrevious")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_PREVIOUS)
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
                }
                if (actions.contains("rewind")) commandsBuilder.add(Player.COMMAND_SEEK_BACK)
                if (actions.contains("fastForward")) commandsBuilder.add(Player.COMMAND_SEEK_FORWARD)
            }

            return State.Builder()
                .setAvailableCommands(commandsBuilder.build())
                .setPlayWhenReady(playWhenReady, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
                .setPlaybackState(playerState)
                .setCurrentMediaItemIndex(0)
                .setPlaylist(listOf(
                    MediaItemData.Builder(0)
                        .setMediaMetadata(currentMetadata)
                        .setDurationUs(if (durationMs != C.TIME_UNSET) durationMs * 1000 else C.TIME_UNSET)
                        .build()
                ))
                .setContentPositionMs { positionMs }
                .setContentBufferedPositionMs { bufferedPositionMs }
                .setPlaybackParameters(PlaybackParameters(speed))
                .build()
        }

        override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
            FlutterMediaSessionPlugin.instance?.sendAction(if (playWhenReady) "play" else "pause")
            return Futures.immediateVoidFuture()
        }

        override fun handleSeek(mediaItemIndex: Int, positionMs: Long, @Player.Command seekCommand: Int): ListenableFuture<*> {
            when (seekCommand) {
                Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM -> {
                    FlutterMediaSessionPlugin.instance?.sendAction("skipToNext")
                }
                Player.COMMAND_SEEK_TO_PREVIOUS, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> {
                    FlutterMediaSessionPlugin.instance?.sendAction("skipToPrevious")
                }
                else -> {
                    FlutterMediaSessionPlugin.instance?.sendAction("seekTo", positionMs)
                }
            }
            return Futures.immediateVoidFuture()
        }

        override fun handleStop(): ListenableFuture<*> {
            FlutterMediaSessionPlugin.instance?.sendAction("stop")
            return Futures.immediateVoidFuture()
        }

        override fun handlePrepare(): ListenableFuture<*> {
            return Futures.immediateVoidFuture()
        }

        override fun handleRelease(): ListenableFuture<*> {
            return Futures.immediateVoidFuture()
        }

        override fun handleSetRepeatMode(repeatMode: Int): ListenableFuture<*> {
            return Futures.immediateVoidFuture()
        }

        override fun handleSetShuffleModeEnabled(shuffleModeEnabled: Boolean): ListenableFuture<*> {
            return Futures.immediateVoidFuture()
        }
    }
}
