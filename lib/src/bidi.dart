import 'package:flutter/painting.dart';

import 'bidi_table.g.dart';

/// Strong bidirectional class of a single code point, as far as paragraph
/// direction detection is concerned.
enum StrongDirection {
  /// Bidi_Class L (Latin, Cyrillic, CJK, Indic, LRM, …).
  leftToRight,

  /// Bidi_Class R or AL (Hebrew, Arabic, Persian, Urdu, Syriac, Thaana, N'Ko,
  /// RLM, ALM, …).
  rightToLeft,
}

/// Returns the strong direction of [codePoint], or `null` when the code point
/// is not strong (digits, Arabic-Indic digits, punctuation, spaces, combining
/// marks such as Arabic harakat or Hebrew niqqud, emoji, controls).
///
/// Backed by a table generated from the Unicode character database (see
/// [kBidiUnicodeVersion]), including the right-to-left defaults Unicode assigns
/// to still-unassigned code points in the Hebrew, Arabic, Syriac, Thaana, N'Ko
/// and other right-to-left blocks.
StrongDirection? strongDirectionOf(int codePoint) {
  const table = kStrongDirectionRanges;
  var low = 0;
  var high = table.length ~/ 3 - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    final start = table[mid * 3];
    final end = table[mid * 3 + 1];
    if (codePoint < start) {
      high = mid - 1;
    } else if (codePoint > end) {
      low = mid + 1;
    } else {
      return table[mid * 3 + 2] == 0
          ? StrongDirection.leftToRight
          : StrongDirection.rightToLeft;
    }
  }
  return null;
}

const int _lri = 0x2066;
const int _rli = 0x2067;
const int _fsi = 0x2068;
const int _pdi = 0x2069;

/// Detects the paragraph direction of [text] from its first strong character,
/// following rules P2 and P3 of the Unicode Bidirectional Algorithm (UAX #9).
///
/// * Characters of class L give [TextDirection.ltr]; R and AL give
///   [TextDirection.rtl].
/// * Characters between an isolate initiator (LRI, RLI, FSI) and its matching
///   PDI are skipped, as P2 requires.
/// * Only the first paragraph is examined (text up to the first paragraph
///   separator: LF, CR, U+001C–U+001E, U+0085, U+2029), matching how a text
///   field applies a single direction.
///
/// Returns `null` when the (first paragraph of the) text has no strong
/// character, e.g. it is empty or contains only digits, spaces, punctuation or
/// emoji.
TextDirection? detectTextDirection(String text) {
  var isolateDepth = 0;
  for (final rune in text.runes) {
    if (_isParagraphSeparator(rune)) break;
    if (rune == _lri || rune == _rli || rune == _fsi) {
      isolateDepth++;
      continue;
    }
    if (rune == _pdi) {
      if (isolateDepth > 0) isolateDepth--;
      continue;
    }
    if (isolateDepth > 0) continue;
    final strong = strongDirectionOf(rune);
    if (strong == null) continue;
    return strong == StrongDirection.leftToRight
        ? TextDirection.ltr
        : TextDirection.rtl;
  }
  return null;
}

bool _isParagraphSeparator(int rune) =>
    rune == 0x0A ||
    rune == 0x0D ||
    (rune >= 0x1C && rune <= 0x1E) ||
    rune == 0x85 ||
    rune == 0x2029;
