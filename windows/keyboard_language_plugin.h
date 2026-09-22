#ifndef FLUTTER_PLUGIN_KEYBOARD_LANGUAGE_PLUGIN_H_
#define FLUTTER_PLUGIN_KEYBOARD_LANGUAGE_PLUGIN_H_

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>
#include <string>

namespace keyboard_language {

// Windows implementation of keyboard_language.
//
// Reads the active keyboard layout of the UI thread (GetKeyboardLayout), maps
// its LANGID to a BCP-47 locale name (LCIDToLocaleName), observes
// WM_INPUTLANGCHANGE / WM_ACTIVATE on the top-level window, lists installed
// layouts (GetKeyboardLayoutList) and activates one (ActivateKeyboardLayout).
class KeyboardLanguagePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit KeyboardLanguagePlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~KeyboardLanguagePlugin();

  KeyboardLanguagePlugin(const KeyboardLanguagePlugin&) = delete;
  KeyboardLanguagePlugin& operator=(const KeyboardLanguagePlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void StartListening(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  void StopListening();

 private:
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam);
  void EmitIfChanged();
  bool SelectLanguage(const std::string& language_tag);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  int window_proc_id_ = -1;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  bool has_sent_ = false;
  flutter::EncodableValue last_sent_;
};

}  // namespace keyboard_language

#endif  // FLUTTER_PLUGIN_KEYBOARD_LANGUAGE_PLUGIN_H_
