import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'bidi.dart';
import 'input_language.dart';
import 'keyboard_language.dart';

/// How [resolveTextDirection] combines the keyboard language with the typed
/// text.
enum AutoDirectionPolicy {
  /// Use the keyboard language when it is known (and strong); otherwise the
  /// first strong character of the text; otherwise the fallback. Best for
  /// short fields where the keyboard signals intent (search, names, chat
  /// composers while empty). Default.
  keyboardThenText,

  /// Use the first strong character of the text when there is one; otherwise
  /// the keyboard language; otherwise the fallback. Best for message bodies,
  /// where a paragraph written in Arabic should stay right-to-left even if the
  /// user switches to an English keyboard to type one word.
  textThenKeyboard,

  /// Use only the keyboard language, else the fallback.
  keyboardOnly,

  /// Use only the typed text (first strong character), else the fallback.
  /// Needs no platform support at all.
  textOnly,
}

/// Resolves the [TextDirection] for a text field whose content is [text]
/// while the user types with [keyboard].
///
/// A weak keyboard value (web's browser locale, see
/// [InputLanguageSource.isStrong]) never overrides a strong character in
/// [text], whatever the [policy].
TextDirection resolveTextDirection({
  required String text,
  InputLanguage? keyboard,
  AutoDirectionPolicy policy = AutoDirectionPolicy.keyboardThenText,
  TextDirection fallback = TextDirection.ltr,
}) {
  final fromKeyboard = keyboard == null
      ? null
      : (keyboard.isRtl ? TextDirection.rtl : TextDirection.ltr);
  final strongKeyboard = keyboard?.source.isStrong ?? false;
  switch (policy) {
    case AutoDirectionPolicy.keyboardThenText:
      if (fromKeyboard != null && strongKeyboard) return fromKeyboard;
      return detectTextDirection(text) ?? fromKeyboard ?? fallback;
    case AutoDirectionPolicy.textThenKeyboard:
      return detectTextDirection(text) ?? fromKeyboard ?? fallback;
    case AutoDirectionPolicy.keyboardOnly:
      return fromKeyboard ?? fallback;
    case AutoDirectionPolicy.textOnly:
      return detectTextDirection(text) ?? fallback;
  }
}

/// Keeps a [TextDirection] in sync with a text field's content, focus and the
/// active keyboard language. Pass [value] to any `TextField.textDirection`, or
/// use `AutoDirectionBuilder` / `AutoDirectionTextField`.
class KeyboardDirectionController extends ChangeNotifier
    implements ValueListenable<TextDirection> {
  /// Creates a controller that listens to [textController], [focusNode] and
  /// `KeyboardLanguage.onChanged`.
  ///
  /// When [keyboardOnlyWhileFocused] is true (default) and a [focusNode] is
  /// given, the keyboard language is only consulted while that node has focus:
  /// an unfocused field is laid out from its text alone, since the keyboard is
  /// then typing into something else. Without a [focusNode] the keyboard is
  /// always consulted.
  KeyboardDirectionController({
    required this.textController,
    this.focusNode,
    AutoDirectionPolicy policy = AutoDirectionPolicy.keyboardThenText,
    TextDirection fallback = TextDirection.ltr,
    this.keyboardOnlyWhileFocused = true,
  }) : _policy = policy,
       _fallback = fallback {
    textController.addListener(_recompute);
    focusNode?.addListener(_onFocusChanged);
    _direction = _resolve();
    if (_policy != AutoDirectionPolicy.textOnly) {
      _subscription = KeyboardLanguage.onChanged.listen(
        _onKeyboard,
        onError: (Object _) {},
      );
      _refreshKeyboard();
    }
  }

  /// Delay after focus is gained before the keyboard language is read a
  /// second time: iOS makes Flutter's text input view first responder, and
  /// Android binds the IME, only after the focus change has been delivered.
  static const Duration refocusReadDelay = Duration(milliseconds: 300);

  /// The text field's controller.
  final TextEditingController textController;

  /// The text field's focus node, if any.
  final FocusNode? focusNode;

  /// See the constructor.
  final bool keyboardOnlyWhileFocused;

  AutoDirectionPolicy _policy;
  TextDirection _fallback;
  late TextDirection _direction;
  InputLanguage? _keyboard;
  StreamSubscription<InputLanguage?>? _subscription;
  Timer? _refocusTimer;
  bool _disposed = false;

  /// The resolved direction.
  @override
  TextDirection get value => _direction;

  /// The last keyboard language received from the platform, or `null`.
  InputLanguage? get keyboardLanguage => _keyboard;

  /// The direction of the text alone (first strong character), or `null`.
  TextDirection? get textDirectionFromText =>
      detectTextDirection(textController.text);

  /// The combination rule in use.
  AutoDirectionPolicy get policy => _policy;
  set policy(AutoDirectionPolicy value) {
    if (_policy == value) return;
    final wasTextOnly = _policy == AutoDirectionPolicy.textOnly;
    _policy = value;
    if (wasTextOnly && value != AutoDirectionPolicy.textOnly) {
      _subscription ??= KeyboardLanguage.onChanged.listen(
        _onKeyboard,
        onError: (Object _) {},
      );
      _refreshKeyboard();
    }
    _recompute();
  }

  /// Direction used when neither the keyboard nor the text decides.
  TextDirection get fallback => _fallback;
  set fallback(TextDirection value) {
    if (_fallback == value) return;
    _fallback = value;
    _recompute();
  }

  bool get _keyboardRelevant =>
      !keyboardOnlyWhileFocused || focusNode == null || focusNode!.hasFocus;

  TextDirection _resolve() => resolveTextDirection(
    text: textController.text,
    keyboard: _keyboardRelevant ? _keyboard : null,
    policy: _policy,
    fallback: _fallback,
  );

  void _recompute() {
    if (_disposed) return;
    final next = _resolve();
    if (next != _direction) {
      _direction = next;
      notifyListeners();
    }
  }

  void _onKeyboard(InputLanguage? language) {
    if (_disposed) return;
    _keyboard = language;
    _recompute();
  }

  void _onFocusChanged() {
    if (focusNode?.hasFocus ?? false) {
      _refreshKeyboard();
      _refocusTimer?.cancel();
      _refocusTimer = Timer(refocusReadDelay, _refreshKeyboard);
    }
    _recompute();
  }

  /// Reads `KeyboardLanguage.current` now and applies it.
  Future<void> refreshKeyboardLanguage() => _refreshKeyboard();

  Future<void> _refreshKeyboard() async {
    if (_policy == AutoDirectionPolicy.textOnly) return;
    try {
      final language = await KeyboardLanguage.current;
      // A null read (e.g. iOS before the text view became first responder)
      // must not erase a value the change stream already delivered.
      if (language != null) _onKeyboard(language);
    } on Object {
      // Reading is best-effort; the typed text still decides.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refocusTimer?.cancel();
    _subscription?.cancel();
    textController.removeListener(_recompute);
    focusNode?.removeListener(_onFocusChanged);
    super.dispose();
  }
}
