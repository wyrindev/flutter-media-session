#if os(iOS)
import Flutter
import UIKit
import AVFoundation
#elseif os(macOS)
import FlutterMacOS
import AppKit
#endif

public class FlutterMediaSessionPlugin: NSObject, FlutterPlugin {
    private var eventSink: FlutterEventSink?
    private var manager: MediaSessionManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #elseif os(macOS)
        let messenger = registrar.messenger
        #endif

        let methodChannel = FlutterMethodChannel(
            name: "flutter_media_session",
            binaryMessenger: messenger
        )
        let eventChannel = FlutterEventChannel(
            name: "flutter_media_session_events",
            binaryMessenger: messenger
        )

        let instance = FlutterMediaSessionPlugin()
        methodChannel.setMethodCallHandler(instance.handle)
        eventChannel.setStreamHandler(instance)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "activate":
            if manager == nil {
                manager = MediaSessionManager(eventSink: { [weak self] event in
                    self?.eventSink?(event)
                })
            }
            manager?.activate()
            result(nil)

        case "deactivate":
            manager?.deactivate()
            manager = nil
            result(nil)

        case "updateMetadata":
            guard let args = call.arguments as? [String: Any?] else {
                result(nil)
                return
            }
            manager?.updateMetadata(
                title: args["title"] as? String,
                artist: args["artist"] as? String,
                album: args["album"] as? String,
                artworkUri: args["artworkUri"] as? String,
                durationMs: (args["durationMs"] as? NSNumber)?.int64Value
            )
            result(nil)

        case "updatePlaybackState":
            guard let args = call.arguments as? [String: Any?] else {
                result(nil)
                return
            }
            let status = args["status"] as? String ?? "idle"
            let positionMs = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
            let speed = (args["speed"] as? NSNumber)?.doubleValue ?? 1.0
            manager?.updatePlaybackState(status: status, positionMs: positionMs, speed: speed)
            result(nil)

        case "updateAvailableActions":
            let actions = call.arguments as? [String]
            manager?.updateAvailableActions(actions)
            result(nil)

        case "requestNotificationPermission":
            #if os(iOS)
            let success = configureAudioSession()
            result(success)
            #else
            result(true)
            #endif

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    #if os(iOS)
    private func configureAudioSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }
    #endif
}

// MARK: - FlutterStreamHandler

extension FlutterMediaSessionPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
