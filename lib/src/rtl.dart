/// Script subtags (ISO 15924) whose text is written right-to-left.
const Set<String> kRtlScripts = <String>{
  'adlm', // Adlam
  'arab', // Arabic (incl. Persian, Urdu, Pashto, Sindhi, Uyghur, Kurdish Sorani)
  'aran', // Arabic Nastaliq
  'armi', // Imperial Aramaic
  'avst', // Avestan
  'chrs', // Chorasmian
  'cprt', // Cypriot
  'elym', // Elymaic
  'hatr', // Hatran
  'hebr', // Hebrew (incl. Yiddish)
  'hung', // Old Hungarian
  'khar', // Kharoshthi
  'lydi', // Lydian
  'mand', // Mandaic
  'mani', // Manichaean
  'mend', // Mende Kikakui
  'nbat', // Nabataean
  'narb', // Old North Arabian
  'nkoo', // N'Ko
  'orkh', // Old Turkic
  'ougr', // Old Uyghur
  'palm', // Palmyrene
  'phli', // Inscriptional Pahlavi
  'phlp', // Psalter Pahlavi
  'phnx', // Phoenician
  'prti', // Inscriptional Parthian
  'rohg', // Hanifi Rohingya
  'samr', // Samaritan
  'sarb', // Old South Arabian
  'sogd', // Sogdian
  'sogo', // Old Sogdian
  'syrc', // Syriac
  'syre', // Syriac (Estrangelo)
  'syrj', // Syriac (Western)
  'syrn', // Syriac (Eastern)
  'thaa', // Thaana (Dhivehi)
  'todr', // Todhri
  'yezi', // Yezidi
};

/// Languages whose *default* script is right-to-left, used when a tag has no
/// script subtag. Languages that are commonly written in several scripts
/// (e.g. `ku` Kurmanji, `pa` Punjabi, `az` Azerbaijani, `uz` Uzbek) default to
/// their most common Latin / Indic script and are therefore not listed; tag
/// them with a script (`ku-Arab`, `pa-Arab`) to get right-to-left.
const Set<String> kRtlLanguages = <String>{
  'ar', 'ara', // Arabic
  'arc', // Aramaic
  'arz', 'apc', 'acm', 'ary', 'aeb', 'ajp', 'afb', 'ayl', // Arabic varieties
  'bal', // Baluchi
  'bqi', // Bakhtiari
  'ckb', // Central Kurdish (Sorani)
  'dv', 'div', // Dhivehi (Thaana)
  'fa', 'fas', 'per', 'prs', 'pes', // Persian, Dari
  'glk', // Gilaki
  'he', 'heb', 'iw', // Hebrew (iw = legacy Java/Android code)
  'ks', 'kas', // Kashmiri
  'lrc', 'luz', // Luri
  'mzn', // Mazanderani
  'nqo', // N'Ko
  'ps', 'pus', 'pbt', 'pst', // Pashto
  'sd', 'snd', // Sindhi
  'skr', // Saraiki
  'syr', 'aii', 'cld', // Syriac, Assyrian and Chaldean Neo-Aramaic
  'ug', 'uig', // Uyghur
  'ur', 'urd', // Urdu
  'yi', 'yid', 'ji', // Yiddish (ji = legacy code)
  'sam', // Samaritan Aramaic
  'mid', // Mandaic
  'rhg', // Rohingya
};

/// Whether text in the language identified by [languageTag] is written
/// right-to-left.
///
/// The script subtag decides when present (`az-Arab` → true, `ur-Latn` →
/// false); otherwise the language's default script decides (`ar`, `he`, `fa`,
/// `ur`, `ps`, `sd`, `ug`, `yi`, `dv`, `ckb`, `syr`, `nqo`, … → true).
/// Accepts `-` or `_` separators and is case-insensitive. Returns false for an
/// empty or unparsable tag.
bool isRtlLanguageTag(String languageTag) {
  final subtags = languageTag
      .trim()
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-')
      .where((s) => s.isNotEmpty)
      .toList();
  if (subtags.isEmpty) return false;
  for (final subtag in subtags.skip(1)) {
    if (subtag.length == 4 && _isAlpha(subtag)) {
      return kRtlScripts.contains(subtag);
    }
    // Stop at the first extension / private-use singleton.
    if (subtag.length == 1) break;
  }
  return kRtlLanguages.contains(subtags.first);
}

bool _isAlpha(String s) {
  for (final unit in s.codeUnits) {
    if (unit < 0x61 || unit > 0x7A) return false;
  }
  return true;
}
