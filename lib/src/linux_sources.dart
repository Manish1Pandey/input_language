/// Pure parsing helpers for the Linux implementation (GNOME input sources and
/// IBus engine names). Kept free of `dart:io` so they are unit-testable
/// everywhere.
library;

import 'input_language.dart';

/// One GNOME input source, e.g. `('xkb', 'il')` or `('ibus', 'm17n:ar:kbd')`.
typedef GnomeInputSource = ({String type, String id});

final RegExp _tuple = RegExp(r"\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)");

/// Parses the output of `gsettings get org.gnome.desktop.input-sources
/// sources` / `mru-sources`, e.g. `[('xkb', 'us'), ('ibus', 'mozc-jp')]`.
List<GnomeInputSource> parseGnomeInputSources(String output) => [
  for (final match in _tuple.allMatches(output))
    (type: match.group(1)!, id: match.group(2)!),
];

/// Converts a GNOME input source to an [InputLanguage], or `null` when its
/// language cannot be determined.
InputLanguage? languageFromGnomeSource(GnomeInputSource source) {
  final String? tag;
  switch (source.type) {
    case 'xkb':
      tag = languageTagForXkbLayout(source.id);
    case 'ibus':
      tag = languageTagForIbusEngine(source.id);
    default:
      tag = null;
  }
  if (tag == null) return null;
  return InputLanguage(
    languageTag: tag,
    source: InputLanguageSource.keyboardLayout,
    inputSourceId: '${source.type}:${source.id}',
  );
}

/// Converts an IBus engine name (output of `ibus engine`) to an
/// [InputLanguage], or `null` when its language cannot be determined.
InputLanguage? languageFromIbusEngine(String engine) {
  final name = engine.trim();
  final tag = languageTagForIbusEngine(name);
  if (tag == null) return null;
  return InputLanguage(
    languageTag: tag,
    source: InputLanguageSource.keyboardLayout,
    inputSourceId: 'ibus:$name',
  );
}

/// Language tag for an IBus engine name:
///
/// * `xkb:<layout>:<variant>:<lang>[,<lang>]` — ISO 639 language field, else
///   the layout;
/// * `m17n:<lang>:<name>` — ISO 639-1 language field;
/// * well-known CJK / Vietnamese engines (`mozc-jp`, `anthy`, `kkc`, `hangul`,
///   `libpinyin`, `pinyin`, `rime`, `chewing`, `bopomofo`, `Unikey`, …).
String? languageTagForIbusEngine(String engine) {
  final name = engine.trim();
  if (name.isEmpty) return null;
  final parts = name.split(':');
  if (parts.first == 'xkb' && parts.length >= 2) {
    final layout = parts.length >= 3 && parts[2].isNotEmpty
        ? '${parts[1]}+${parts[2]}'
        : parts[1];
    final fromLayout = languageTagForXkbLayout(layout);
    if (parts.length >= 4 && parts[3].isNotEmpty) {
      final fromLang = languageTagForIso639(parts[3].split(',').first);
      if (fromLang != null) {
        // Keep the layout's region when it agrees on the language
        // (xkb:us::eng -> en-US rather than en).
        if (fromLayout != null && fromLayout.split('-').first == fromLang) {
          return fromLayout;
        }
        return fromLang;
      }
    }
    return fromLayout;
  }
  if (parts.first == 'm17n' && parts.length >= 2) {
    return languageTagForIso639(parts[1]);
  }
  if (parts.first == 'table' && parts.length >= 2) {
    return _tableEngines[parts[1].toLowerCase()];
  }
  return _namedEngines[name.toLowerCase()] ??
      _namedEngines[parts.first.toLowerCase()];
}

/// Language tag for an XKB layout such as `us`, `il`, `ara`, `ir`, `pk`,
/// `de+nodeadkeys`, or `null` for unknown layouts.
String? languageTagForXkbLayout(String layout) {
  final plus = layout.split('+');
  final base = plus.first.toLowerCase();
  final variant = plus.length > 1 ? plus[1].toLowerCase() : '';
  // Variants that change the language of a layout.
  if (base == 'iq' && variant.startsWith('ku')) return 'ckb';
  if (base == 'ir' && variant.startsWith('ku')) return 'ckb';
  if (base == 'tr' && variant.startsWith('ku')) return 'ku';
  if (base == 'pk' && variant == 'snd') return 'sd';
  if (base == 'pk' && variant == 'ara') return 'ar';
  if (base == 'in' && variant.isNotEmpty) {
    return _indiaVariants[variant] ?? _indiaVariants[variant.split('-').first];
  }
  if (base == 'rs' && variant.startsWith('latin')) return 'sr-Latn';
  if (base == 'ua' && variant == 'rstu_ru') return 'ru';
  if (base == 'cn' && variant == 'ug') return 'ug';
  return _xkbLayouts[base];
}

/// BCP-47 tag for an ISO 639-1, 639-2/B, 639-2/T or 639-3 code, or `null`.
String? languageTagForIso639(String code) {
  final lower = code.trim().toLowerCase();
  if (lower.isEmpty) return null;
  if (lower.length == 2 && _isLetters(lower)) return lower;
  final mapped = _iso639Three[lower];
  if (mapped != null) return mapped;
  // Three-letter codes with no two-letter equivalent are valid BCP-47.
  if (lower.length == 3 && _isLetters(lower)) return lower;
  return null;
}

bool _isLetters(String s) => s.codeUnits.every((u) => u >= 0x61 && u <= 0x7A);

const Map<String, String> _namedEngines = <String, String>{
  'mozc-jp': 'ja',
  'mozc-on': 'ja',
  'mozc': 'ja',
  'anthy': 'ja',
  'kkc': 'ja',
  'skk': 'ja',
  'hangul': 'ko',
  'libpinyin': 'zh-Hans',
  'pinyin': 'zh-Hans',
  'intelligent-pinyin': 'zh-Hans',
  'sunpinyin': 'zh-Hans',
  'googlepinyin': 'zh-Hans',
  'libzhuyin': 'zh-Hant',
  'chewing': 'zh-Hant',
  'bopomofo': 'zh-Hant',
  'rime': 'zh',
  'cangjie': 'zh-Hant',
  'quick': 'zh-Hant',
  'unikey': 'vi',
  'bamboo': 'vi',
  'libthai': 'th',
};

const Map<String, String> _tableEngines = <String, String>{
  'cangjie3': 'zh-Hant',
  'cangjie5': 'zh-Hant',
  'quick-classic': 'zh-Hant',
  'wubi-jidian86': 'zh-Hans',
  'wubi-haifeng86': 'zh-Hans',
  'erbi': 'zh-Hans',
  'zhengma': 'zh-Hans',
};

const Map<String, String> _indiaVariants = <String, String>{
  'ben': 'bn',
  'ben_probhat': 'bn',
  'guj': 'gu',
  'guru': 'pa',
  'jhelum': 'pa',
  'kan': 'kn',
  'mal': 'ml',
  'mal_lalitha': 'ml',
  'ori': 'or',
  'tam': 'ta',
  'tam_tamilnet': 'ta',
  'tel': 'te',
  'urd': 'ur',
  'urd-phonetic': 'ur',
  'urd-phonetic3': 'ur',
  'urd-winkeys': 'ur',
  'bolnagri': 'hi',
  'hin-wx': 'hi',
  'hin-kagapa': 'hi',
  'mar-kagapa': 'mr',
  'san-kagapa': 'sa',
  'eng': 'en-IN',
};

const Map<String, String> _xkbLayouts = <String, String>{
  'us': 'en-US',
  'gb': 'en-GB',
  'au': 'en-AU',
  'za': 'en-ZA',
  'ng': 'en-NG',
  'ie': 'ga',
  'ca': 'fr-CA',
  'de': 'de',
  'at': 'de-AT',
  'ch': 'de-CH',
  'fr': 'fr',
  'be': 'fr-BE',
  'es': 'es',
  'latam': 'es-419',
  'it': 'it',
  'pt': 'pt-PT',
  'br': 'pt-BR',
  'nl': 'nl',
  'dk': 'da',
  'se': 'sv',
  'no': 'nb',
  'fi': 'fi',
  'is': 'is',
  'ee': 'et',
  'lv': 'lv',
  'lt': 'lt',
  'pl': 'pl',
  'cz': 'cs',
  'sk': 'sk',
  'hu': 'hu',
  'ro': 'ro',
  'md': 'ro-MD',
  'si': 'sl',
  'hr': 'hr',
  'rs': 'sr',
  'ba': 'bs',
  'me': 'sr-ME',
  'mk': 'mk',
  'al': 'sq',
  'bg': 'bg',
  'gr': 'el',
  'tr': 'tr',
  'mt': 'mt',
  'ru': 'ru',
  'ua': 'uk',
  'by': 'be',
  'ge': 'ka',
  'am': 'hy',
  'az': 'az',
  'kz': 'kk',
  'uz': 'uz',
  'kg': 'ky',
  'tj': 'tg',
  'tm': 'tk',
  'mn': 'mn',
  'il': 'he',
  'ara': 'ar',
  'eg': 'ar-EG',
  'iq': 'ar-IQ',
  'sy': 'ar-SY',
  'ma': 'ar-MA',
  'ir': 'fa',
  'af': 'fa-AF',
  'pk': 'ur',
  'mv': 'dv',
  'in': 'hi',
  'bd': 'bn',
  'np': 'ne',
  'lk': 'si',
  'bt': 'dz',
  'th': 'th',
  'la': 'lo',
  'kh': 'km',
  'mm': 'my',
  'vn': 'vi',
  'id': 'id',
  'my': 'ms',
  'ph': 'fil',
  'jp': 'ja',
  'kr': 'ko',
  'cn': 'zh-CN',
  'tw': 'zh-TW',
  'et': 'am',
  'ke': 'sw',
  'tz': 'sw-TZ',
  'epo': 'eo',
};

const Map<String, String> _iso639Three = <String, String>{
  'eng': 'en',
  'ara': 'ar',
  'heb': 'he',
  'per': 'fa',
  'fas': 'fa',
  'urd': 'ur',
  'pus': 'ps',
  'snd': 'sd',
  'uig': 'ug',
  'yid': 'yi',
  'div': 'dv',
  'kur': 'ku',
  'ger': 'de',
  'deu': 'de',
  'fre': 'fr',
  'fra': 'fr',
  'spa': 'es',
  'ita': 'it',
  'por': 'pt',
  'dut': 'nl',
  'nld': 'nl',
  'dan': 'da',
  'swe': 'sv',
  'nor': 'no',
  'nob': 'nb',
  'nno': 'nn',
  'fin': 'fi',
  'ice': 'is',
  'isl': 'is',
  'est': 'et',
  'lav': 'lv',
  'lit': 'lt',
  'pol': 'pl',
  'cze': 'cs',
  'ces': 'cs',
  'slo': 'sk',
  'slk': 'sk',
  'hun': 'hu',
  'rum': 'ro',
  'ron': 'ro',
  'slv': 'sl',
  'hrv': 'hr',
  'srp': 'sr',
  'bos': 'bs',
  'mac': 'mk',
  'mkd': 'mk',
  'alb': 'sq',
  'sqi': 'sq',
  'bul': 'bg',
  'gre': 'el',
  'ell': 'el',
  'tur': 'tr',
  'mlt': 'mt',
  'rus': 'ru',
  'ukr': 'uk',
  'bel': 'be',
  'geo': 'ka',
  'kat': 'ka',
  'arm': 'hy',
  'hye': 'hy',
  'aze': 'az',
  'kaz': 'kk',
  'uzb': 'uz',
  'kir': 'ky',
  'tgk': 'tg',
  'tuk': 'tk',
  'mon': 'mn',
  'hin': 'hi',
  'ben': 'bn',
  'pan': 'pa',
  'guj': 'gu',
  'ori': 'or',
  'tam': 'ta',
  'tel': 'te',
  'kan': 'kn',
  'mal': 'ml',
  'mar': 'mr',
  'nep': 'ne',
  'sin': 'si',
  'san': 'sa',
  'tha': 'th',
  'lao': 'lo',
  'khm': 'km',
  'bur': 'my',
  'mya': 'my',
  'vie': 'vi',
  'ind': 'id',
  'may': 'ms',
  'msa': 'ms',
  'tgl': 'tl',
  'jpn': 'ja',
  'kor': 'ko',
  'chi': 'zh',
  'zho': 'zh',
  'tib': 'bo',
  'bod': 'bo',
  'dzo': 'dz',
  'amh': 'am',
  'tir': 'ti',
  'som': 'so',
  'swa': 'sw',
  'hau': 'ha',
  'yor': 'yo',
  'ibo': 'ig',
  'zul': 'zu',
  'xho': 'xh',
  'afr': 'af',
  'gle': 'ga',
  'wel': 'cy',
  'cym': 'cy',
  'baq': 'eu',
  'eus': 'eu',
  'cat': 'ca',
  'glg': 'gl',
  'epo': 'eo',
  'lat': 'la',
  'bre': 'br',
  'fao': 'fo',
  'ltz': 'lb',
  'tat': 'tt',
  'bak': 'ba',
  'chv': 'cv',
  'oss': 'os',
  'kas': 'ks',
};
