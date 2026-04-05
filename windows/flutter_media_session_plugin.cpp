#include "flutter_media_session_plugin.h"

#include <windows.h>
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <systemmediatransportcontrolsinterop.h>

#include <winrt/Windows.Storage.Streams.h>

using namespace winrt::Windows::Media;
using namespace winrt::Windows::Media::Playback;
using namespace winrt::Windows::Media::Core;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Storage::Streams;

namespace flutter_media_session {

/**
 * Windows implementation of the Flutter Media Session plugin.
 * Uses System Media Transport Controls (SMTC) to integrate with Windows media controls.
 */

static const UINT WM_MEDIA_ACTION = RegisterWindowMessageW(L"FlutterMediaSessionPlugin_MediaAction");

/**
 * Internal IDs for media actions to be posted to the main thread.
 */
enum MediaActionId {
  Play = 1,
  Pause,
  SkipToNext,
  SkipToPrevious,
};

// static
void FlutterMediaSessionPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_media_session",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterMediaSessionPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  plugin->RegisterEventChannel();

  registrar->AddPlugin(std::move(plugin));
}

/**
 * Registers the event channel for sending media actions back to Dart.
 */
void FlutterMediaSessionPlugin::RegisterEventChannel() {
  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar_->messenger(), "flutter_media_session_events",
          &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
           -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        this->event_sink_ = std::move(events);
        return nullptr;
      },
      [this](const flutter::EncodableValue* arguments)
           -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        this->event_sink_ = nullptr;
        return nullptr;
      });

  event_channel->SetStreamHandler(std::move(handler));
}

FlutterMediaSessionPlugin::FlutterMediaSessionPlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar), window_proc_id_(-1) {
    try {
        winrt::init_apartment();
    } catch (...) {
        // Apartment may already be initialized by the Flutter engine or another plugin.
    }

    if (registrar_->GetView()) {
        window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
            [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
                return HandleWindowProc(hwnd, message, wparam, lparam);
            });
    }
}

FlutterMediaSessionPlugin::~FlutterMediaSessionPlugin() {
    DisposeSmtc();
    if (window_proc_id_ != -1 && registrar_->GetView()) {
        registrar_->UnregisterTopLevelWindowProcDelegate(static_cast<int32_t>(window_proc_id_));
    }
}

/**
 * Initializes the System Media Transport Controls for the application window.
 */
void FlutterMediaSessionPlugin::InitSmtc() {
    if (smtc_ != nullptr || !registrar_->GetView()) return;
    try {
        HWND hwnd = registrar_->GetView()->GetNativeWindow();
        HWND root_hwnd = GetAncestor(hwnd, GA_ROOT);
        if (!root_hwnd) root_hwnd = hwnd;

        auto interop = winrt::get_activation_factory<winrt::Windows::Media::SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
        winrt::check_hresult(interop->GetForWindow(root_hwnd, winrt::guid_of<winrt::Windows::Media::SystemMediaTransportControls>(), winrt::put_abi(smtc_)));

        // Enable standard playback controls
        smtc_.IsPlayEnabled(true);
        smtc_.IsPauseEnabled(true);
        smtc_.IsNextEnabled(true);
        smtc_.IsPreviousEnabled(true);
        smtc_.IsEnabled(true);
        
        button_pressed_token_ = smtc_.ButtonPressed([this, root_hwnd](SystemMediaTransportControls const&, SystemMediaTransportControlsButtonPressedEventArgs const& args) {
            auto button = args.Button();
            MediaActionId action_id = (MediaActionId)0;

            switch (button) {
                case SystemMediaTransportControlsButton::Play: action_id = MediaActionId::Play; break;
                case SystemMediaTransportControlsButton::Pause: action_id = MediaActionId::Pause; break;
                case SystemMediaTransportControlsButton::Next: action_id = MediaActionId::SkipToNext; break;
                case SystemMediaTransportControlsButton::Previous: action_id = MediaActionId::SkipToPrevious; break;
                default: break;
            }

            // Media session commands from WinRT threads must be dispatched to the main thread via WindowProc.
            if (action_id != 0 && root_hwnd) {
                PostMessage(root_hwnd, WM_MEDIA_ACTION, (WPARAM)action_id, 0);
            }
        });
        
    } catch (winrt::hresult_error const& ex) {
        OutputDebugStringW((L"InitSmtc HRESULT error: " + ex.message() + L"\n").c_str());
        smtc_ = nullptr;
    } catch (std::exception const& ex) {
        OutputDebugStringA(("InitSmtc exception: " + std::string(ex.what()) + "\n").c_str());
        smtc_ = nullptr;
    }
}

/**
 * Releases the System Media Transport Controls and unsubscribes from events.
 */
void FlutterMediaSessionPlugin::DisposeSmtc() {
    if (smtc_) {
        smtc_.IsEnabled(false);
        smtc_.ButtonPressed(button_pressed_token_);
        smtc_ = nullptr;
    }
}

/**
 * Processes window messages, specifically targeting media action messages dispatched from the WinRT callback.
 */
std::optional<LRESULT> FlutterMediaSessionPlugin::HandleWindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    if (message == WM_MEDIA_ACTION) {
        std::string actionStr = "";
        MediaActionId id = (MediaActionId)wparam;
        switch (id) {
            case MediaActionId::Play: actionStr = "play"; break;
            case MediaActionId::Pause: actionStr = "pause"; break;
            case MediaActionId::SkipToNext: actionStr = "skipToNext"; break;
            case MediaActionId::SkipToPrevious: actionStr = "skipToPrevious"; break;
            default: break;
        }

        if (!actionStr.empty() && event_sink_) {
            event_sink_->Success(flutter::EncodableValue(actionStr));
        }
        return 0; // Handled
    }
    return std::nullopt; // Unhandled
}

void FlutterMediaSessionPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const std::string& method_name = method_call.method_name();

  if (method_name == "activate") {
      InitSmtc();
      result->Success();
  } else if (method_name == "deactivate") {
      DisposeSmtc();
      result->Success();
  } else if (method_name == "updateMetadata") {
      if (smtc_) {
          auto updater = smtc_.DisplayUpdater();
          updater.Type(MediaPlaybackType::Music);
          auto prop = updater.MusicProperties();

          const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
          if (args) {
              auto itTitle = args->find(flutter::EncodableValue("title"));
              if (itTitle != args->end() && !itTitle->second.IsNull()) {
                  if (auto title = std::get_if<std::string>(&itTitle->second)) {
                      prop.Title(winrt::to_hstring(*title));
                  }
              }

              auto itArtist = args->find(flutter::EncodableValue("artist"));
              if (itArtist != args->end() && !itArtist->second.IsNull()) {
                  if (auto artist = std::get_if<std::string>(&itArtist->second)) {
                      prop.Artist(winrt::to_hstring(*artist));
                  }
              }

              auto itAlbum = args->find(flutter::EncodableValue("album"));
              if (itAlbum != args->end() && !itAlbum->second.IsNull()) {
                  if (auto album = std::get_if<std::string>(&itAlbum->second)) {
                      prop.AlbumTitle(winrt::to_hstring(*album));
                  }
              }

              auto itArtwork = args->find(flutter::EncodableValue("artworkUri"));
              if (itArtwork != args->end() && !itArtwork->second.IsNull()) {
                  if (auto artwork = std::get_if<std::string>(&itArtwork->second)) {
                      try {
                          auto uri = winrt::Windows::Foundation::Uri(winrt::to_hstring(*artwork));
                          auto streamRef = winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromUri(uri);
                          updater.Thumbnail(streamRef);
                      } catch (...) {
                          OutputDebugStringA("Failed to set artwork URI in SMTC updater.\n");
                      }
                  }
              }
          }
          try {
              updater.Update();
          } catch (winrt::hresult_error const& ex) {
              OutputDebugStringW((L"SMTC Metadata Update error: " + ex.message() + L"\n").c_str());
          }
      }
      result->Success();
  } else if (method_name == "updatePlaybackState") {
      if (smtc_) {
          const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
          if (args) {
              auto itStatus = args->find(flutter::EncodableValue("status"));
              if (itStatus != args->end() && !itStatus->second.IsNull()) {
                  if (auto status = std::get_if<std::string>(&itStatus->second)) {
                      MediaPlaybackStatus smtcStatus = MediaPlaybackStatus::Closed;
                      if (*status == "playing") smtcStatus = MediaPlaybackStatus::Playing;
                      else if (*status == "paused") smtcStatus = MediaPlaybackStatus::Paused;
                      else if (*status == "buffering") smtcStatus = MediaPlaybackStatus::Changing;
                      else if (*status == "idle" || *status == "ended" || *status == "error") smtcStatus = MediaPlaybackStatus::Stopped;

                      try {
                          smtc_.PlaybackStatus(smtcStatus);
                      } catch (winrt::hresult_error const& ex) {
                          OutputDebugStringW((L"SMTC PlaybackStatus update error: " + ex.message() + L"\n").c_str());
                      }
                  }
              }
          }
      }
      result->Success();
  } else if (method_name == "updateAvailableActions") {
      if (smtc_) {
          const auto* actions = std::get_if<flutter::EncodableList>(method_call.arguments());
          if (actions) {
              // Check which actions are in the list
              bool hasPlay = false, hasPause = false, hasNext = false, hasPrevious = false;
              for (const auto& action : *actions) {
                  if (auto str = std::get_if<std::string>(&action)) {
                      if (*str == "play") hasPlay = true;
                      else if (*str == "pause") hasPause = true;
                      else if (*str == "skipToNext") hasNext = true;
                      else if (*str == "skipToPrevious") hasPrevious = true;
                  }
              }
              try {
                  smtc_.IsPlayEnabled(hasPlay);
                  smtc_.IsPauseEnabled(hasPause);
                  smtc_.IsNextEnabled(hasNext);
                  smtc_.IsPreviousEnabled(hasPrevious);
              } catch (winrt::hresult_error const& ex) {
                  OutputDebugStringW((L"SMTC updateAvailableActions error: " + ex.message() + L"\n").c_str());
              }
          } else {
              // null = enable all
              try {
                  smtc_.IsPlayEnabled(true);
                  smtc_.IsPauseEnabled(true);
                  smtc_.IsNextEnabled(true);
                  smtc_.IsPreviousEnabled(true);
              } catch (...) {}
          }
      }
      result->Success();
  } else {
      result->NotImplemented();
  }
}

}  // namespace flutter_media_session
