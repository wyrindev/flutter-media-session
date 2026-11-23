package dev.wyrin.flutter_media_session_example

import dev.wyrin.flutter_media_session.FlutterMediaSessionActivity

// Shares its Flutter engine with the media service, so Android Auto can start the app while it is
// closed (see the dev.wyrin.flutter_media_session.background_engine meta-data in the manifest).
class MainActivity : FlutterMediaSessionActivity()
