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
