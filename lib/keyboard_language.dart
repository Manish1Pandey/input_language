/// Detect, observe and (on macOS / Windows) switch the active keyboard / input
/// language, and resolve a text field's direction from it with a Unicode
/// bidi first-strong-character fallback.
///
/// Solves flutter/flutter#25841. Start with `KeyboardLanguage` and
/// `AutoDirectionTextField`.
library;

export 'src/bidi.dart'
    show StrongDirection, detectTextDirection, strongDirectionOf;
export 'src/bidi_table.g.dart' show kBidiUnicodeVersion;
export 'src/capabilities.dart';
export 'src/direction.dart';
export 'src/input_language.dart';
export 'src/keyboard_language.dart';
export 'src/method_channel.dart';
export 'src/platform_interface.dart';
export 'src/rtl.dart';
export 'src/widgets.dart';
