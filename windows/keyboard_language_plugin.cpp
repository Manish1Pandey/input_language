#include "keyboard_language_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cwctype>
#include <memory>
#include <string>
#include <vector>

namespace keyboard_language {

namespace {

constexpr char kMethodChannel[] = "dev.manishpanday/keyboard_language";
constexpr char kEventChannel[] = "dev.manishpanday/keyboard_language/events";

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::string Utf8FromWide(const std::wstring& wide) {
  if (wide.empty()) return std::string();
  const int size = ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                         static_cast<int>(wide.size()), nullptr,
                                         0, nullptr, nullptr);
  if (size <= 0) return std::string();
  std::string utf8(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                        static_cast<int>(wide.size()), utf8.data(), size,
                        nullptr, nullptr);
  return utf8;
}

std::wstring WideFromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int size = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring wide(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                        static_cast<int>(utf8.size()), wide.data(), size);
  return wide;
}

std::wstring Lower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  std::replace(value.begin(), value.end(), L'_', L'-');
  return value;
}

std::wstring PrimarySubtag(const std::wstring& tag) {
  const size_t dash = tag.find(L'-');
  return dash == std::wstring::npos ? tag : tag.substr(0, dash);
}

// BCP-47 locale name of the language of a keyboard layout handle.
std::wstring LocaleNameOfLayout(HKL layout) {
  const LANGID lang_id =
      static_cast<LANGID>(reinterpret_cast<UINT_PTR>(layout) & 0xFFFF);
  wchar_t name[LOCALE_NAME_MAX_LENGTH] = {0};
  if (::LCIDToLocaleName(MAKELCID(lang_id, SORT_DEFAULT), name,
                         LOCALE_NAME_MAX_LENGTH, 0) == 0) {
    return std::wstring();
  }
  return std::wstring(name);
}

std::string LayoutId(HKL layout) {
  wchar_t buffer[32] = {0};
  swprintf_s(buffer, L"%08llX",
             static_cast<unsigned long long>(
                 reinterpret_cast<UINT_PTR>(layout) & 0xFFFFFFFFull));
  return Utf8FromWide(buffer);
}

EncodableValue PayloadForLayout(HKL layout) {
  if (layout == nullptr) return EncodableValue();
  const std::wstring locale_name = LocaleNameOfLayout(layout);
  if (locale_name.empty()) return EncodableValue();
  EncodableMap map;
  map[EncodableValue("languageTag")] = EncodableValue(Utf8FromWide(locale_name));
  map[EncodableValue("inputSourceId")] = EncodableValue(LayoutId(layout));
  map[EncodableValue("source")] = EncodableValue("keyboardLayout");
  wchar_t display[LOCALE_NAME_MAX_LENGTH * 4] = {0};
  if (::GetLocaleInfoEx(locale_name.c_str(), LOCALE_SLOCALIZEDDISPLAYNAME,
                        display, LOCALE_NAME_MAX_LENGTH * 4) > 0) {
    map[EncodableValue("displayName")] = EncodableValue(Utf8FromWide(display));
  }
  return EncodableValue(map);
}

std::vector<HKL> InstalledLayouts() {
  const int count = ::GetKeyboardLayoutList(0, nullptr);
  if (count <= 0) return {};
  std::vector<HKL> layouts(static_cast<size_t>(count));
  const int filled = ::GetKeyboardLayoutList(count, layouts.data());
  layouts.resize(filled > 0 ? static_cast<size_t>(filled) : 0u);
  return layouts;
}

EncodableMap Capabilities() {
  EncodableMap map;
  map[EncodableValue("canReadCurrent")] = EncodableValue(true);
  map[EncodableValue("canObserveChanges")] = EncodableValue(true);
  map[EncodableValue("canListAvailable")] = EncodableValue(true);
  map[EncodableValue("canSetLanguage")] = EncodableValue(true);
  map[EncodableValue("requiresFocusedTextField")] = EncodableValue(false);
  map[EncodableValue("isWeakHint")] = EncodableValue(false);
  return map;
}

}  // namespace

// static
void KeyboardLanguagePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<KeyboardLanguagePlugin>(registrar);
  KeyboardLanguagePlugin* plugin_pointer = plugin.get();

  auto method_channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), kMethodChannel,
          &flutter::StandardMethodCodec::GetInstance());
  method_channel->SetMethodCallHandler(
      [plugin_pointer](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto event_channel = std::make_unique<flutter::EventChannel<EncodableValue>>(
      registrar->messenger(), kEventChannel,
      &flutter::StandardMethodCodec::GetInstance());
  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [plugin_pointer](
              const EncodableValue* /*arguments*/,
              std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            plugin_pointer->StartListening(std::move(events));
            return nullptr;
          },
          [plugin_pointer](const EncodableValue* /*arguments*/)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            plugin_pointer->StopListening();
            return nullptr;
          }));

  plugin->method_channel_ = std::move(method_channel);
  plugin->event_channel_ = std::move(event_channel);
  registrar->AddPlugin(std::move(plugin));
}

KeyboardLanguagePlugin::KeyboardLanguagePlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
}

KeyboardLanguagePlugin::~KeyboardLanguagePlugin() {
  if (window_proc_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

void KeyboardLanguagePlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  if (method == "getCurrent") {
    result->Success(PayloadForLayout(::GetKeyboardLayout(0)));
  } else if (method == "getAvailable") {
    EncodableList list;
    for (HKL layout : InstalledLayouts()) {
      EncodableValue payload = PayloadForLayout(layout);
      if (!payload.IsNull()) list.push_back(payload);
    }
    result->Success(EncodableValue(list));
  } else if (method == "setLanguage") {
    const auto* args = std::get_if<EncodableMap>(method_call.arguments());
    std::string tag;
    if (args != nullptr) {
      auto it = args->find(EncodableValue("languageTag"));
      if (it != args->end()) {
        if (const auto* value = std::get_if<std::string>(&it->second)) {
          tag = *value;
        }
      }
    }
    if (tag.empty()) {
      result->Error("bad_args", "languageTag is required");
      return;
    }
    result->Success(EncodableValue(SelectLanguage(tag)));
  } else if (method == "getCapabilities") {
    result->Success(EncodableValue(Capabilities()));
  } else {
    result->NotImplemented();
  }
}

bool KeyboardLanguagePlugin::SelectLanguage(const std::string& language_tag) {
  const std::wstring wanted = Lower(WideFromUtf8(language_tag));
  const std::wstring wanted_primary = PrimarySubtag(wanted);
  const std::vector<HKL> layouts = InstalledLayouts();
  HKL match = nullptr;
  for (HKL layout : layouts) {
    if (Lower(LocaleNameOfLayout(layout)) == wanted) {
      match = layout;
      break;
    }
  }
  if (match == nullptr) {
    for (HKL layout : layouts) {
      if (PrimarySubtag(Lower(LocaleNameOfLayout(layout))) == wanted_primary) {
        match = layout;
        break;
      }
    }
  }
  if (match == nullptr) return false;
  if (::ActivateKeyboardLayout(match, KLF_SETFORPROCESS) == nullptr) {
    return false;
  }
  EmitIfChanged();
  return true;
}

void KeyboardLanguagePlugin::StartListening(
    std::unique_ptr<flutter::EventSink<EncodableValue>> sink) {
  sink_ = std::move(sink);
  has_sent_ = false;
  last_sent_ = EncodableValue();
  EmitIfChanged();
}

void KeyboardLanguagePlugin::StopListening() { sink_.reset(); }

std::optional<LRESULT> KeyboardLanguagePlugin::HandleWindowProc(
    HWND /*hwnd*/, UINT message, WPARAM /*wparam*/, LPARAM /*lparam*/) {
  // WM_INPUTLANGCHANGE reaches the top-level window after the user switches
  // the input language; WM_ACTIVATE covers switches made in another app while
  // Windows keeps a per-app layout. Never consume the message.
  if (message == WM_INPUTLANGCHANGE || message == WM_ACTIVATE) {
    EmitIfChanged();
  }
  return std::nullopt;
}

void KeyboardLanguagePlugin::EmitIfChanged() {
  if (!sink_) return;
  EncodableValue current = PayloadForLayout(::GetKeyboardLayout(0));
  if (has_sent_ && current == last_sent_) return;
  has_sent_ = true;
  last_sent_ = current;
  sink_->Success(current);
}

}  // namespace keyboard_language
