/// The primary library for controlling system media sessions and player integration.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'src/models/media_action.dart';
import 'src/models/action_slot_layout.dart';
import 'src/models/media_library_item.dart';
import 'src/adapters/media_session_adapter.dart';
import 'flutter_media_session_platform_interface.dart';

export 'src/models/media_metadata.dart';
export 'src/models/playback_state.dart';
export 'src/models/media_action.dart';
export 'src/models/action_slot_layout.dart';
export 'src/models/media_library_item.dart';
export 'src/adapters/media_session_adapter.dart';
export 'flutter_media_session_platform_interface.dart';

/// The main entry point for the Flutter Media Session plugin.
///
/// This class provides a singleton interface to interact with the system media session.
/// The recommended modern workflow is to bind an player adapter using [bind].
class FlutterMediaSession {
  static final FlutterMediaSession _instance = FlutterMediaSession._internal();

  /// Factory constructor to return the singleton instance.
  factory FlutterMediaSession() => _instance;

  FlutterMediaSession._internal();

  MediaSessionAdapter? _activeAdapter;
  StreamSubscription<MediaAction>? _actionHandlerSubscription;

  /// Binds a [MediaSessionAdapter] to this media session instance.
  ///
  /// This automatically unbinds any currently active adapter before binding the new one.
  ///
  /// Example:
  /// ```dart
  /// final session = FlutterMediaSession();
  /// final adapter = JustAudioAdapter(myPlayer);
  /// session.bind(adapter);
  /// ```
  void bind(MediaSessionAdapter adapter) {
    unbind();
    _activeAdapter = adapter;
    adapter.bind(this);
  }

  /// Unbinds the currently active adapter, if any, and releases its resources.
  void unbind() {
    _activeAdapter?.unbind();
    _activeAdapter = null;
  }

  /// Sets high-level callbacks to handle system media actions without manually listening to streams.
  ///
  /// This is an alternative to using player adapters.
  void setActionHandler({
    VoidCallback? onPlay,
    VoidCallback? onPause,
    VoidCallback? onSkipToNext,
    VoidCallback? onSkipToPrevious,
    VoidCallback? onStop,
    void Function(Duration)? onSeekTo,
    VoidCallback? onRewind,
    VoidCallback? onFastForward,
    VoidCallback? onShuffle,
    VoidCallback? onRepeat,
    void Function(String mediaId)? onPlayFromMediaId,
    void Function(String query)? onPlayFromSearch,
  }) {
    _actionHandlerSubscription?.cancel();
    _actionHandlerSubscription =
        FlutterMediaSessionPlatform.instance.onMediaAction.listen((action) {
      switch (action.name) {
        case 'play':
          onPlay?.call();
          break;
        case 'pause':
          onPause?.call();
          break;
        case 'skipToNext':
          onSkipToNext?.call();
          break;
        case 'skipToPrevious':
          onSkipToPrevious?.call();
          break;
        case 'stop':
          onStop?.call();
          break;
        case 'seekTo':
          if (action.seekPosition != null) {
            onSeekTo?.call(action.seekPosition!);
          }
          break;
        case 'rewind':
          onRewind?.call();
          break;
        case 'fastForward':
          onFastForward?.call();
          break;
        case 'shuffle':
          onShuffle?.call();
          break;
        case 'repeat':
          onRepeat?.call();
          break;
        case 'playFromMediaId':
          final mediaId = action.mediaId;
          if (mediaId != null) onPlayFromMediaId?.call(mediaId);
          break;
        case 'playFromSearch':
          onPlayFromSearch?.call(action.query ?? '');
          break;
      }
    });
  }

  /// Clears the active action handler, if any.
  void clearActionHandler() {
    _actionHandlerSubscription?.cancel();
    _actionHandlerSubscription = null;
  }

  /// Activates the media session on the current platform.
  ///
  /// On Android, this starts the foreground media service and automatically
  /// requests notification permissions if required.
  /// On Windows and Web, it initializes the system media transport controls.
  Future<void> activate() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Unify lifecycle by automatically requesting permissions when activating on Android
      try {
        await FlutterMediaSessionPlatform.instance
            .requestNotificationPermission();
      } on PlatformException {
        // No screen to ask from: the app was started in the background (a media browser such as
        // Android Auto, see FlutterMediaSessionEngine). Activate anyway; it is asked next time.
      }
    }
    return FlutterMediaSessionPlatform.instance.activate();
  }

  /// Deactivates the media session and releases platform resources.
  Future<void> deactivate() {
    clearActionHandler();
    return FlutterMediaSessionPlatform.instance.deactivate();
  }

  /// Sets the application identity (App ID / AUMID / DesktopEntry) for the current process.
  ///
  /// On Windows, this sets the AppUserModelID (AUMID) and can create a Start Menu shortcut
  /// with [displayName] and [iconPath] for unpackaged/portable apps.
  /// On Linux, this sets the MPRIS `DesktopEntry` (to associate with `.desktop` files)
  /// and `Identity` (with [displayName]).
  Future<void> setAppId(String id, {String? displayName, String? iconPath}) {
    return FlutterMediaSessionPlatform.instance
        .setAppId(id, displayName: displayName, iconPath: iconPath);
  }

  /// Sets the AppUserModelID for the current process on Windows.
  ///
  /// This is used by Windows to identify the application in the system media center.
  /// If not set, the application might show up as "Unknown Application".
  ///
  /// Provide [displayName] (and optionally [iconPath]) to dynamically create a
  /// Start Menu shortcut. This is highly recommended for unpackaged/portable apps.
  /// If your app is packaged via MSIX or uses an installer to create shortcuts,
  /// you should **omit** [displayName] to avoid creating duplicate shortcuts.
  ///
  /// This method is only effective on Windows.
  @Deprecated('Use setAppId instead. Deprecated starting in v4.0.0-pre.1.')
  Future<void> setWindowsAppUserModelId(String id,
      {String? displayName, String? iconPath}) {
    return setAppId(id, displayName: displayName, iconPath: iconPath);
  }

  /// Sets the preferred skip intervals for rewind (backward) and fast-forward (forward) commands.
  ///
  /// This is currently supported on iOS and macOS.
  Future<void> setSkipIntervals(
      {int forwardSeconds = 10, int backwardSeconds = 10}) {
    return FlutterMediaSessionPlatform.instance.setSkipIntervals(
      forwardSeconds: forwardSeconds,
      backwardSeconds: backwardSeconds,
    );
  }

  /// Opts the plugin into handling system audio interruptions
  /// (calls, navigation prompts, other apps grabbing audio).
  ///
  /// When enabled, the plugin requests audio focus on Android while
  /// playback is `playing` and forwards focus events through
  /// [FlutterMediaSessionPlatform.onMediaAction] (`pause` on focus loss, `play` when transient
  /// focus returns). Defaults to `false`.
  ///
  /// Leave this off if your audio player already manages focus
  /// (such as `audioplayers` or `just_audio`). Turn it on for players
  /// that do not manage focus themselves (such as `fvp` or `video_player`).
  Future<void> setAutoHandleInterruptions(bool enabled) {
    return FlutterMediaSessionPlatform.instance
        .setAutoHandleInterruptions(enabled);
  }

  /// Opts the session into a background keep-alive. Defaults to `false`.
  ///
  /// While enabled, the platform holds available keep-alive primitives
  /// (wake lock on Android, prevent-sleep on macOS/Windows, screen wake lock on Web)
  /// for the lifetime of the session.
  ///
  /// Use this to keep a backgrounded session alive when audio is rendered off-device,
  /// such as a Chromecast or DLNA socket on the local network.
  Future<void> setBackgroundKeepAlive(bool enabled) {
    return FlutterMediaSessionPlatform.instance.setBackgroundKeepAlive(enabled);
  }

  /// Whether a media browser (Android Auto) started the app in the background while it was closed,
  /// through the shared engine (see the Android Auto section of the usage guide), rather than the
  /// user opening it.
  ///
  /// An app started this way should set up its media library and action handlers, but not
  /// [activate] the session or start playing until it is asked to (an item picked, a voice request):
  /// an active session makes it the app Android Auto resumes, taking over from whatever was playing.
  /// Android only; `false` elsewhere.
  Future<bool> wasStartedInBackground() {
    return FlutterMediaSessionPlatform.instance.wasStartedInBackground();
  }

  /// For spoken-word content (podcasts, audiobooks, text to speech): when another app speaks
  /// briefly and would only lower this app's volume (a navigation prompt), pause instead, and
  /// resume when it's done. Lowered speech under another voice can't be followed. Defaults to
  /// `false` (the system lowers the volume, which suits music).
  ///
  /// Needs [setAutoHandleInterruptions] enabled. The pause and the resume arrive as `pause` and
  /// `play` actions with [MediaAction.isInterruption] set, so an app can step back a little when
  /// it resumes. Android only; no effect elsewhere.
  Future<void> setPauseWhenDucked(bool enabled) {
    return FlutterMediaSessionPlatform.instance.setPauseWhenDucked(enabled);
  }

  /// Opts into a browsable media library, shown by media browsers such as Android Auto.
  ///
  /// [getChildren] is asked for the children of a library node: first [MediaLibraryItem.rootId]
  /// (the top level), then any item that is browsable. Picking a playable item arrives as a
  /// [MediaAction.playFromMediaId] action (`onPlayFromMediaId` in [setActionHandler]); a voice
  /// request (`play X on <app>`) as [MediaAction.playFromSearch] (`onPlayFromSearch`).
  ///
  /// To be listed in Android Auto, the app must also declare itself a media app in its own
  /// manifest (see the Android Auto section of the usage guide). Until this is called, browse
  /// requests are refused, as before. Android only; no effect elsewhere.
  Future<void> setMediaLibrary(
      {required MediaLibraryChildrenProvider getChildren}) {
    return FlutterMediaSessionPlatform.instance.setMediaLibrary(getChildren);
  }

  /// Turns the media library off again (see [setMediaLibrary]).
  Future<void> clearMediaLibrary() {
    return FlutterMediaSessionPlatform.instance.setMediaLibrary(null);
  }

  /// Sets the customizable action slot layout for system media controls.
  ///
  /// On Android, this arranges the action positions in the system notification
  /// and media controls card, and configures which actions are visible in compact view.
  /// On other platforms, this has no effect as native system media controls do not
  /// support slot reordering (use [updateAvailableActions] via the platform instance instead).
  Future<void> setActionLayout(ActionSlotLayout layout) {
    return FlutterMediaSessionPlatform.instance.setActionLayout(layout);
  }
}
