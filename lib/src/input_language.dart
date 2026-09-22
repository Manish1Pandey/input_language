import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import 'rtl.dart';

/// Where an [InputLanguage] value came from.
enum InputLanguageSource {
  /// The software keyboard / input method reported it (iOS
  /// `UITextInputMode.primaryLanguage`, Android `InputMethodSubtype`).
  inputMethod,

  /// The active hardware keyboard layout or input source reported it (macOS
  /// Text Input Sources, Windows keyboard layout, Linux GNOME / IBus).
  keyboardLayout,

  /// Only the browser's preferred UI language is known (web). This is a weak
  /// hint, not the real keyboard language.
  browserLocale;

  /// Whether this source really reflects the keyboard the user types with.
  bool get isStrong => this != InputLanguageSource.browserLocale;

  static InputLanguageSource _parse(Object? raw) {
    for (final value in InputLanguageSource.values) {
      if (value.name == raw) return value;
    }
    return InputLanguageSource.inputMethod;
  }
}

/// A keyboard / input language reported by the platform.
@immutable
class InputLanguage {
  /// Creates an input language from a BCP-47 [languageTag].
  ///
  /// The tag is canonicalised (`_` → `-`, `en_us` → `en-US`, legacy `iw` →
  /// `he`); [isRtl] defaults to [isRtlLanguageTag] of the canonical tag.
  factory InputLanguage({
    required String languageTag,
    required InputLanguageSource source,
    String? displayName,
    String? inputSourceId,
    bool? isRtl,
  }) {
    final canonical = canonicalizeLanguageTag(languageTag);
    return InputLanguage._(
      languageTag: canonical,
      locale: localeFromLanguageTag(canonical),
      source: source,
      displayName: (displayName == null || displayName.isEmpty)
          ? null
          : displayName,
      inputSourceId: (inputSourceId == null || inputSourceId.isEmpty)
          ? null
          : inputSourceId,
      isRtl: isRtl ?? isRtlLanguageTag(canonical),
    );
  }

  const InputLanguage._({
    required this.languageTag,
    required this.locale,
    required this.source,
    required this.displayName,
    required this.inputSourceId,
    required this.isRtl,
  });

  /// Decodes the map sent over the platform channel, or returns `null` when
  /// the map is `null` or carries no usable language (emoji keyboard,
  /// dictation, empty tag).
  static InputLanguage? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final tag = map['languageTag'];
    if (tag is! String || !isLanguageBearingTag(tag)) return null;
    return InputLanguage(
      languageTag: tag,
      source: InputLanguageSource._parse(map['source']),
      displayName: map['displayName'] as String?,
      inputSourceId: map['inputSourceId'] as String?,
    );
  }

  /// Canonical BCP-47 language tag, e.g. `ar`, `he-IL`, `zh-Hans`, `fa-IR`.
  final String languageTag;

  /// [languageTag] as a Flutter [Locale] (language, script and region).
  final Locale locale;

  /// Human-readable name as provided by the OS (e.g. `Arabic`, `ABC`,
  /// `Hebrew - QWERTY`), or `null` when the OS gives none.
  final String? displayName;

  /// Whether text in this language is written right-to-left.
  final bool isRtl;

  /// Where the value came from; see [InputLanguageSource].
  final InputLanguageSource source;

  /// Raw OS identifier of the keyboard: macOS input source ID
  /// (`com.apple.keylayout.Arabic`), Windows KLID (`00000401`), Android IME id
  /// and subtype, iOS input-mode identifier, Linux GNOME/IBus source id.
  final String? inputSourceId;

  /// Primary language subtag, e.g. `ar` for `ar-EG`.
  String get languageCode => locale.languageCode;

  /// Encodes this value as the platform-channel map (inverse of [fromMap]).
  Map<String, Object?> toMap() => <String, Object?>{
    'languageTag': languageTag,
    'displayName': displayName,
    'inputSourceId': inputSourceId,
    'source': source.name,
  };

  @override
  bool operator ==(Object other) =>
      other is InputLanguage &&
      other.languageTag == languageTag &&
      other.source == source &&
      other.displayName == displayName &&
      other.inputSourceId == inputSourceId &&
      other.isRtl == isRtl;

  @override
  int get hashCode =>
      Object.hash(languageTag, source, displayName, inputSourceId, isRtl);

  @override
  String toString() =>
      'InputLanguage($languageTag, ${isRtl ? 'rtl' : 'ltr'}, ${source.name}'
      '${displayName == null ? '' : ', "$displayName"'}'
      '${inputSourceId == null ? '' : ', $inputSourceId'})';
}

const Set<String> _nonLanguageTags = <String>{
  'emoji',
  'dictation',
  'und',
  'mul',
  'zxx',
};

/// Whether [tag] names a real language (not the iOS `emoji` / `dictation`
/// pseudo-modes or an undetermined / empty tag).
bool isLanguageBearingTag(String tag) {
  final trimmed = tag.trim().toLowerCase();
  if (trimmed.isEmpty) return false;
  final primary = trimmed.replaceAll('_', '-').split('-').first;
  return primary.isNotEmpty && !_nonLanguageTags.contains(primary);
}

const Map<String, String> _legacyLanguages = <String, String>{
  'iw': 'he',
  'ji': 'yi',
  'in': 'id',
};

/// Canonicalises a BCP-47 or POSIX/Java-style locale string: `_` becomes `-`,
/// the language is lower-cased, a 4-letter script is title-cased, a 2-letter
/// region is upper-cased, legacy codes (`iw`, `ji`, `in`) are replaced, and a
/// POSIX suffix (`.UTF-8`, `@euro`) is dropped.
String canonicalizeLanguageTag(String tag) {
  var cleaned = tag.trim();
  final dot = cleaned.indexOf('.');
  if (dot >= 0) cleaned = cleaned.substring(0, dot);
  final at = cleaned.indexOf('@');
  if (at >= 0) cleaned = cleaned.substring(0, at);
  final parts = cleaned
      .replaceAll('_', '-')
      .split('-')
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'und';
  final out = <String>[];
  final language = parts.first.toLowerCase();
  out.add(_legacyLanguages[language] ?? language);
  var singleton = false;
  for (final part in parts.skip(1)) {
    if (singleton) {
      out.add(part.toLowerCase());
    } else if (part.length == 1) {
      singleton = true;
      out.add(part.toLowerCase());
    } else if (part.length == 4 && !_isDigit(part.codeUnitAt(0))) {
      out.add(part[0].toUpperCase() + part.substring(1).toLowerCase());
    } else if (part.length == 2 || (part.length == 3 && _allDigits(part))) {
      out.add(part.toUpperCase());
    } else {
      out.add(part.toLowerCase());
    }
  }
  return out.join('-');
}

/// Converts a canonical BCP-47 tag to a [Locale] with language, optional
/// script and optional region.
Locale localeFromLanguageTag(String tag) {
  final parts = canonicalizeLanguageTag(tag).split('-');
  String? script;
  String? region;
  for (final part in parts.skip(1)) {
    if (part.length == 1) break;
    if (script == null &&
        region == null &&
        part.length == 4 &&
        !_isDigit(part.codeUnitAt(0))) {
      script = part;
    } else if (region == null &&
        (part.length == 2 || (part.length == 3 && _allDigits(part)))) {
      region = part;
    }
  }
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: script,
    countryCode: region,
  );
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

bool _allDigits(String s) => s.codeUnits.every(_isDigit);
