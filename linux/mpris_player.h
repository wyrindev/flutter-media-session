#ifndef FLUTTER_PLUGIN_MPRIS_PLAYER_H_
#define FLUTTER_PLUGIN_MPRIS_PLAYER_H_

#include <gio/gio.h>
#include <glib.h>
#include <string>
#include <functional>
#include <unordered_set>
#include <vector>

namespace flutter_media_session {

// Callback function type when an MPRIS command/action is invoked
using ActionCallback = std::function<void(const std::string& action, int64_t seek_position_ms)>;

class MprisPlayer {
 public:
  explicit MprisPlayer(ActionCallback callback);
  ~MprisPlayer();

  bool Activate();
  void Deactivate();

  void SetDesktopEntry(const std::string& desktop_entry);
  void SetIdentity(const std::string& identity);

  void UpdateMetadata(GVariant* metadata_dict);
  void UpdatePlaybackState(const std::string& status,
                           int64_t position_ms,
                           double speed,
                           const std::string& repeat_mode,
                           bool shuffle_enabled);
  void UpdateAvailableActions(const std::unordered_set<std::string>& actions);

  bool IsActive() const { return is_active_; }

  static void HandleMethodCall(GDBusConnection* connection,
                               const gchar* sender,
                               const gchar* object_path,
                               const gchar* interface_name,
                               const gchar* method_name,
                               GVariant* parameters,
                               GDBusMethodInvocation* invocation,
                               gpointer user_data);

  static GVariant* HandleGetProperty(GDBusConnection* connection,
                                     const gchar* sender,
                                     const gchar* object_path,
                                     const gchar* interface_name,
                                     const gchar* property_name,
                                     GError** error,
                                     gpointer user_data);

  static gboolean HandleSetProperty(GDBusConnection* connection,
                                     const gchar* sender,
                                     const gchar* object_path,
                                     const gchar* interface_name,
                                     const gchar* property_name,
                                     GVariant* value,
                                     GError** error,
                                     gpointer user_data);

 private:
  static void OnBusAcquired(GDBusConnection* connection,
                            const gchar* name,
                            gpointer user_data);
  static void OnNameAcquired(GDBusConnection* connection,
                             const gchar* name,
                             gpointer user_data);
  static void OnNameLost(GDBusConnection* connection,
                         const gchar* name,
                         gpointer user_data);

  void EmitPropertiesChanged(const gchar* interface_name,
                             GVariantBuilder* changed_properties);

  ActionCallback action_callback_;
  bool is_active_ = false;
  guint owner_id_ = 0;
  guint registration_id_root_ = 0;
  guint registration_id_player_ = 0;
  GDBusConnection* connection_ = nullptr;
  GDBusNodeInfo* introspection_data_ = nullptr;

  // MPRIS Properties State
  std::string identity_ = "Flutter Media Session";
  std::string desktop_entry_ = "";
  std::string playback_status_ = "Stopped";  // Playing, Paused, Stopped
  std::string loop_status_ = "None";         // None, Track, Playlist
  double rate_ = 1.0;
  bool shuffle_ = false;
  int64_t position_us_ = 0;                  // Microseconds in MPRIS
  GVariant* metadata_ = nullptr;             // a{sv}

  // Capability flags
  bool can_control_ = true;
  bool can_play_ = true;
  bool can_pause_ = true;
  bool can_seek_ = true;
  bool can_go_next_ = false;
  bool can_go_previous_ = false;
};

}  // namespace flutter_media_session

#endif  // FLUTTER_PLUGIN_MPRIS_PLAYER_H_
