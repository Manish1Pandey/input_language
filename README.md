# keyboard_language

Find out which **keyboard / input language** the user is typing with, get notified when they
switch, and make any `TextField` flip to right-to-left automatically, with a correct Unicode
first-strong-character fallback for when the OS can't tell you.

Solves [flutter/flutter#25841](https://github.com/flutter/flutter/issues/25841) ("detect the
keyboard language"). Also answers
[flutter/flutter#99606](https://github.com/flutter/flutter/issues/99606) ("change the keyboard
language from code"): it works on macOS and Windows, and on the other platforms the OS doesn't
allow it (see below).

<img src="https://raw.githubusercontent.com/Manish1Pandey/keyboard_language/main/screenshots/ios_hebrew_rtl.png" width="300" alt="Example app on the iOS simulator: Hebrew keyboard detected, text field switched to right-to-left">

*Example app on the iOS 18.6 simulator: the Hebrew keyboard is detected (`he-IL · RTL`) and the
auto-direction field has switched to right-to-left.*

## Why

Flutter has no API for the active input language. An app therefore can't set `textDirection` to
RTL when the user picks an Arabic or Hebrew keyboard, and can't show a language badge or adapt the
UI. This package reads the language from each OS's native API and resolves a `TextDirection` from
it.

## Install

```yaml
dependencies:
  keyboard_language: ^0.1.0
```

## Usage

### Read and observe

```dart
import 'package:keyboard_language/keyboard_language.dart';

final InputLanguage? language = await KeyboardLanguage.current;
print(language?.languageTag);  // "ar", "he-IL", "en-US", "zh-Hans" …
print(language?.isRtl);        // true for Arabic, Hebrew, Persian, Urdu, …
print(language?.locale);       // Locale('he', 'IL')
print(language?.displayName);  // "Hebrew – QWERTY" (OS-provided, localised)
print(language?.source);       // inputMethod | keyboardLayout | browserLocale

final sub = KeyboardLanguage.onChanged.listen((InputLanguage? l) {
  // Fires when the user switches keyboards. null = no language-bearing keyboard is known.
});

final enabled = await KeyboardLanguage.available();      // the user's enabled keyboards
final caps = await KeyboardLanguage.capabilities();      // what this platform can do
```

### Auto-direction text field

```dart
AutoDirectionTextField(
  decoration: const InputDecoration(labelText: 'Message'),
  policy: AutoDirectionPolicy.keyboardThenText, // default
)
```

Or wrap any field (`TextFormField`, `CupertinoTextField`, …):

```dart
AutoDirectionBuilder(
  controller: controller,
  builder: (context, direction, focusNode) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    textDirection: direction,
  ),
)
```

For full control, use `KeyboardDirectionController` (a `ValueListenable<TextDirection>`) or the
pure function `resolveTextDirection(text:, keyboard:, policy:, fallback:)`.

| Policy | Behaviour |
|---|---|
| `keyboardThenText` (default) | Keyboard language when known, else the first strong character of the text, else the fallback. |
| `textThenKeyboard` | Text first. Good for message bodies: an Arabic paragraph stays RTL even if the user switches to an English keyboard to type one word. |
| `keyboardOnly` / `textOnly` | Only the keyboard / only the text. `textOnly` needs no platform support. |

The keyboard is only consulted while the field is focused (`keyboardOnlyWhileFocused: true`). The
web's weak browser-locale hint never overrides typed text.

### Bidi detection

```dart
detectTextDirection('123 - שלום');          // TextDirection.rtl
detectTextDirection('Flutter و دارت');      // TextDirection.ltr
detectTextDirection('٣٤٥ 😀');              // null (no strong character)
isRtlLanguageTag('ur-PK');                  // true
isRtlLanguageTag('pa-Arab');                // true, 'pa' alone → false
```

`detectTextDirection` implements UAX #9 rules P2/P3: it returns the direction of the first strong
character (L, or R/AL) and skips text inside isolates (LRI/RLI/FSI…PDI). It uses a table generated
from the **Unicode 16.0** character database (`tool/generate_bidi_table.py`), so combining marks
(harakat, niqqud, Syriac and Thaana vowels, N'Ko tones), Arabic-Indic digits and punctuation are
correctly *not* strong. It covers Hebrew, Arabic (Persian and Urdu letters, Supplement,
Extended-A/B/C, Presentation Forms), Syriac, Thaana, N'Ko, Samaritan, Mandaic, Adlam and Hanifi
Rohingya, and the RTL defaults for unassigned code points in those blocks.

### Switching the keyboard (macOS, Windows)

```dart
try {
  final ok = await KeyboardLanguage.setLanguage('ar'); // false if no Arabic keyboard is installed
} on UnsupportedError {
  // iOS, Android, Linux, web
}
```

## Platform support

| | iOS | Android | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| `current` | ✅ while a field is focused | ✅ | ✅ | ✅ | ⚠️ GNOME / IBus | ⚠️ browser locale only |
| `onChanged` | ✅ notification | ✅ poll + IME broadcast | ✅ distributed notification | ✅ `WM_INPUTLANGCHANGE` | ⚠️ `gsettings monitor` / poll | ⚠️ `languagechange` |
| `available()` | ✅ `activeInputModes` | ✅ enabled subtypes | ✅ | ✅ | ⚠️ GNOME sources | ⚠️ `navigator.languages` |
| `setLanguage` | ❌ | ❌ | ✅ `TISSelectInputSource` | ✅ `ActivateKeyboardLayout` | ❌ | ❌ |
| Typed-text fallback | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### How each platform works, and its limits

- **iOS**: reads `textInputMode.primaryLanguage` of the first responder and observes
  `UITextInputMode.currentInputModeDidChangeNotification` and keyboard show/hide. While a Flutter
  text field is being edited, the first responder is the engine's hidden text input view. **So the
  value is only reliable while a text field is focused**; otherwise `current` is `null`. The emoji
  keyboard and dictation report `null`. Apps can't change the keyboard (no public API).
- **Android**: reads `InputMethodManager.getCurrentInputMethodSubtype()` (`languageTag`, falling
  back to the legacy `locale`). Android has no broadcast for subtype changes, so while
  `onChanged` has listeners the plugin polls the subtype (a cheap call, every
  `KeyboardLanguage.pollInterval`, default 500 ms) and also listens for
  `ACTION_INPUT_METHOD_CHANGED` (IME switches). **Gboard** publishes one subtype per enabled
  language and normally updates the current subtype when the user switches language with the globe
  key or a space-bar swipe. With Gboard's *multilingual typing* (two languages on one layout), or
  IMEs such as SwiftKey that type several languages at once, only the primary subtype is reported.
  Some IMEs publish no subtypes at all (`null`). Test on the IMEs your users actually have. Apps
  can't switch the IME or its subtype.
- **macOS**: Text Input Sources: `TISCopyCurrentKeyboardInputSource` (layouts and IME input
  modes), the `kTISNotifySelectedKeyboardInputSourceChanged` distributed notification, and
  `TISSelectInputSource` for `setLanguage`. It can only select sources the user has enabled.
- **Windows**: `GetKeyboardLayout` → LANGID → `LCIDToLocaleName`, `WM_INPUTLANGCHANGE` (and
  `WM_ACTIVATE`) on the top-level window, `GetKeyboardLayoutList`, and `ActivateKeyboardLayout` for
  `setLanguage`. It reports the language, not the IME's conversion mode. It can only activate
  installed layouts.
- **Linux** (best effort): GNOME `org.gnome.desktop.input-sources` (`mru-sources`, with
  `gsettings monitor` for changes), otherwise the IBus `ibus engine` command (polled). XKB layouts
  and IBus engine names are mapped to languages. Fcitx, KDE without IBus and other setups return
  `null`. Setting the language isn't supported.
- **Web**: browsers don't expose the keyboard or IME language. `current` returns
  `navigator.language` marked `source: browserLocale` (`capabilities().isWeakHint == true`), and
  `AutoDirectionTextField` lets typed text override it.

## Limitations

- iOS needs a focused text field; Linux coverage depends on the desktop; the web only gives a hint.
- Android multilingual IMEs report a single (primary) language.
- `detectTextDirection` looks at the first paragraph only, the same way a text field applies one
  direction to its content.
- Unassigned code points outside the right-to-left default blocks are treated as L, as
  `DerivedBidiClass.txt` specifies. Noncharacters and default-ignorables are neutral.

## Verified on a device

On the iOS 18.6 simulator, `example/integration_test/keyboard_runtime_test.dart` passed with the
Hebrew keyboard and with the Arabic keyboard: after a field was focused, `current` returned
`he-IL` / `ar` (RTL), `onChanged` emitted `null` and then the language as the keyboard appeared,
and `AutoDirectionTextField` switched to right-to-left. Blurring and refocusing emitted `null`
and then the language again. The test can't switch the simulator keyboard while an app is running
(there's no API for that, and changed preferences only apply on the next launch), so a live switch
while the field has focus still has to be checked by hand.

## Example

`example/` shows every feature: current language, change log, enabled keyboards with tap-to-switch,
capabilities, the auto-direction field with each policy, the builder, and the bidi playground.
`flutter test integration_test -d macos` exercises the real native code.

## License

MIT © 2026 Manish Kumar Panday
