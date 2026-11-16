cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "flutter_media_session")
project(${PROJECT_NAME} LANGUAGES CXX C)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_media_session_plugin")

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(GLIB REQUIRED IMPORTED_TARGET glib-2.0 gio-2.0 gio-unix-2.0)

add_library(${PLUGIN_NAME} SHARED
  "flutter_media_session_plugin.cc"
  "mpris_player.cc"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET "hidden"
  VISIBILITY_INLINES_HIDDEN 1
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  PkgConfig::GTK
  PkgConfig::GLIB
)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build system.
set(flutter_media_session_bundled_libraries
  ""
  PARENT_SCOPE
)
