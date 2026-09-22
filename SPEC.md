# keyboard_language — functional specification

Written before any code. Solves [flutter/flutter#25841](https://github.com/flutter/flutter/issues/25841)
("detect the keyboard language / input language") and answers
[flutter/flutter#99606](https://github.com/flutter/flutter/issues/99606) ("change the keyboard
language from code") honestly per platform.

## 1. Purpose

A Flutter app cannot ask which keyboard / input language the user is typing with. Because of that it
cannot switch a text field to right-to-left when the user picks an Arabic or Hebrew keyboard, cannot
show a language badge, and cannot adapt spell-check, fonts or hints. This package:

1. reads the active keyboard / input-method language from the OS on every platform where the OS
   exposes it, as a BCP-47 tag with `Locale`, display name, `isRtl` and where the answer came from;
2. streams changes;
3. lists the keyboards the user has enabled, where the OS allows;
4. switches the keyboard language from code **only** where the OS allows it (macOS, Windows);
5. resolves a `TextDirection` for any `TextField` from the keyboard language, falling back to the first
   strong character of the typed text (Unicode Bidirectional Algorithm rule P2/P3, generated from the
   Unicode 16.0 character database).

## 2. Functional requirements

| ID | Requirement |
|----|-------------|
| FR1 | `KeyboardLanguage.current` returns `Future<InputLanguage?>`; `null` when the OS gives no answer (no focused field on iOS, emoji keyboard, unsupported desktop, …). |
| FR2 | `InputLanguage` carries `languageTag` (BCP-47, canonical `-` separators), `locale`, `displayName` (localised by the OS where available), `isRtl`, `source`, and the raw OS `inputSourceId`. |
| FR3 | `KeyboardLanguage.onChanged` is a broadcast `Stream<InputLanguage?>`; it emits only when the value actually changes; the native observer runs only while at least one Dart listener exists. |
| FR4 | `KeyboardLanguage.available()` lists enabled keyboards (iOS `activeInputModes`, Android enabled keyboard subtypes of every enabled IME (current IME first), macOS select-capable keyboard input sources, Windows `GetKeyboardLayoutList`, Linux GNOME `sources`, web `navigator.languages`). |
| FR5 | `KeyboardLanguage.setLanguage(tag)` selects a matching installed keyboard on macOS (`TISSelectInputSource`) and Windows (`ActivateKeyboardLayout`); returns `false` when no installed keyboard matches; throws `UnsupportedError` on every other platform. |
| FR6 | `KeyboardLanguage.capabilities()` tells the app, per platform, whether it can read, observe, set, and whether reading needs a focused text field. |
| FR7 | `detectTextDirection(text)` returns the direction of the first strong character (L → ltr, R/AL → rtl), skipping text inside isolates (LRI/RLI/FSI … PDI), or `null` when there is none. Correct for Hebrew, Arabic (incl. Persian/Urdu letters, Supplement, Extended-A/B/C, Presentation Forms), Syriac, Thaana, N'Ko, Samaritan, Mandaic, Adlam, Hanifi Rohingya, and RTL-default unassigned code points. Combining marks, digits, Arabic-Indic digits and punctuation are *not* strong. |
| FR8 | `isRtlLanguageTag(tag)` decides direction from the script subtag if present, else from the language's default script (ar, he/iw, fa, ur, ps, sd, ug, yi, dv, ckb, syr, nqo, ks, …). |
| FR9 | `KeyboardDirectionController` (a `ValueListenable<TextDirection>`) combines a `TextEditingController`, optional `FocusNode`, the keyboard stream and a configurable `AutoDirectionPolicy` (`keyboardThenText` default, `textThenKeyboard`, `keyboardOnly`, `textOnly`) plus a fallback direction. The keyboard is only consulted while the field is focused (configurable). A weak source (web browser locale) never overrides typed text. |
| FR10 | `AutoDirectionBuilder` rebuilds any `TextField`/`TextFormField` with the resolved direction; `AutoDirectionTextField` is a ready-made `TextField` with it wired in. |
| FR11 | Poll interval for platforms without a change notification (Android subtype changes, Linux IBus) is configurable (`KeyboardLanguage.pollInterval`, default 500 ms). |
| FR12 | Linux: best-effort read via GNOME `org.gnome.desktop.input-sources mru-sources` or the IBus `ibus engine` command; `null` when neither is available. |

## 3. Can / Cannot

| Platform | Can | Cannot |
|----------|-----|--------|
| iOS | Read `textInputMode.primaryLanguage` of the first responder (Flutter's hidden text-input view while a field is being edited); observe `currentInputModeDidChangeNotification` + keyboard show; list `activeInputModes`. | Read anything reliable while no text field is focused (returns `null`); report a language for the emoji keyboard (returns `null`); switch the keyboard (no public API — Apple only lets a custom `UIResponder` *suggest* a mode via `textInputMode`, which Flutter's engine owns). |
| Android | Read `InputMethodManager.currentInputMethodSubtype` (`languageTag`, or legacy `locale`); list enabled keyboard subtypes of enabled IMEs; detect IME switches (`ACTION_INPUT_METHOD_CHANGED`) and subtype switches (polling while listened). | Get a push notification for subtype changes (none exists for apps); get a correct answer from IMEs that do not publish subtypes or type several languages at once (e.g. multilingual SwiftKey/Gboard "multilingual typing" reports only the primary subtype); switch keyboard or subtype (requires being the IME / system). |
| macOS | Read the current keyboard input source (`TISCopyCurrentKeyboardInputSource`) incl. IME input modes; observe `kTISNotifySelectedKeyboardInputSourceChanged`; list select-capable sources; **select** one (`TISSelectInputSource`). | Select a source the user has not enabled in System Settings. |
| Windows | Read `GetKeyboardLayout` → LANGID → locale name; observe `WM_INPUTLANGCHANGE`; list `GetKeyboardLayoutList`; **activate** an installed layout (`ActivateKeyboardLayout`). | Activate a layout that is not installed; know the TSF IME *conversion mode* (only the language). |
| Linux | Best-effort: GNOME input-sources / IBus engine → language. | Anything on non-GNOME desktops without IBus (Fcitx, plain XKB on KDE, Wayland compositors without IBus) → `null`; set the language. |
| Web | Report `navigator.language` as a *weak* hint (`source: browserLocale`) and watch `languagechange`; typed-text detection works fully. | Know the real keyboard/IME language (browsers do not expose it); set it. |

## 4. Public API sketch

```dart
class KeyboardLanguage {
  static Future<InputLanguage?> get current;
  static Stream<InputLanguage?> get onChanged;
  static Future<List<InputLanguage>> available();
  static Future<bool> setLanguage(String languageTag); // macOS, Windows
  static Future<KeyboardLanguageCapabilities> capabilities();
  static Duration pollInterval;
}
class InputLanguage { String languageTag; Locale locale; String? displayName; bool isRtl;
  InputLanguageSource source; String? inputSourceId; }
enum InputLanguageSource { inputMethod, keyboardLayout, browserLocale }
TextDirection? detectTextDirection(String text);
bool isRtlLanguageTag(String languageTag);
TextDirection resolveTextDirection({String text, InputLanguage? keyboard, AutoDirectionPolicy policy, TextDirection fallback});
class KeyboardDirectionController extends ChangeNotifier implements ValueListenable<TextDirection>;
class AutoDirectionBuilder extends StatefulWidget;
class AutoDirectionTextField extends StatefulWidget;
```

## 5. Platform matrix

| | iOS | Android | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| current | yes (focused field) | yes | yes | yes | best-effort | weak hint |
| onChanged | notification | broadcast + poll | distributed notification | WM_INPUTLANGCHANGE | gsettings monitor / poll | languagechange |
| available | yes | yes (enabled IMEs) | yes | yes | GNOME sources | navigator.languages |
| setLanguage | no | no | yes | yes | no | no |
| text fallback | yes | yes | yes | yes | yes | yes |

Native channel: `MethodChannel('dev.manishpanday/keyboard_language')` with methods `getCurrent`,
`getAvailable`, `setLanguage`, `getCapabilities`; `EventChannel('dev.manishpanday/keyboard_language/events')`
with argument `{pollIntervalMs}`. Every language payload is a map
`{languageTag, displayName?, inputSourceId?, source}`.
