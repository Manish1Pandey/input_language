## 0.1.1

* Docs: the README now explains Bidi (bidirectional text) detection in full: the
  first-strong-character rule, which characters count, worked examples, isolates, and
  when to use `detectTextDirection` vs `isRtlLanguageTag`.
* Package homepage now points to https://flutterdev.in/packages/input_language/.

## 0.1.0

* Initial release.
* `KeyboardLanguage.current`, `onChanged`, `available()`, `capabilities()` on iOS
  (UITextInputMode), Android (InputMethodSubtype), macOS (Text Input Sources),
  Windows (keyboard layouts), Linux (GNOME input sources / IBus, best effort) and
  web (browser locale as a weak hint).
* `KeyboardLanguage.setLanguage` on macOS (`TISSelectInputSource`) and Windows
  (`ActivateKeyboardLayout`); `UnsupportedError` elsewhere.
* `detectTextDirection` / `strongDirectionOf`: UAX #9 first-strong detection from a
  table generated from Unicode 16.0 (Hebrew, Arabic, Persian, Urdu, Syriac, Thaana,
  N'Ko, Samaritan, Mandaic, Adlam, Hanifi Rohingya, …), isolate-aware.
* `isRtlLanguageTag`, `resolveTextDirection`, `KeyboardDirectionController`,
  `AutoDirectionBuilder`, `AutoDirectionTextField` with four `AutoDirectionPolicy`
  modes.
