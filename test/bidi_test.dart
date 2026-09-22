import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:input_language/input_language.dart';

void main() {
  group('strongDirectionOf', () {
    const rtl = StrongDirection.rightToLeft;
    const ltr = StrongDirection.leftToRight;

    final cases = <String, (int, StrongDirection?)>{
      'Latin a': (0x61, ltr),
      'Cyrillic ж': (0x0436, ltr),
      'CJK 中': (0x4E2D, ltr),
      'Devanagari क': (0x0915, ltr),
      'Hebrew alef': (0x05D0, rtl),
      'Hebrew maqaf (R, not a letter)': (0x05BE, rtl),
      'Hebrew yod triangle U+05EF': (0x05EF, rtl),
      'Arabic alef': (0x0627, rtl),
      'Arabic ALM U+061C': (0x061C, rtl),
      'Persian pe پ': (0x067E, rtl),
      'Persian gaf گ': (0x06AF, rtl),
      'Persian zhe ژ': (0x0698, rtl),
      'Urdu tteh ٹ': (0x0679, rtl),
      'Urdu noon ghunna ں': (0x06BA, rtl),
      'Urdu yeh barree ے': (0x06D2, rtl),
      'Arabic Supplement U+0750': (0x0750, rtl),
      'Arabic Extended-A U+08A0': (0x08A0, rtl),
      'Arabic Extended-B U+0870': (0x0870, rtl),
      'Arabic Presentation Forms-A U+FB50': (0xFB50, rtl),
      'Arabic Presentation Forms-B U+FE70': (0xFE70, rtl),
      'Syriac alaph U+0710': (0x0710, rtl),
      'Syriac letter U+0728': (0x0728, rtl),
      'Thaana haa U+0780': (0x0780, rtl),
      'Thaana sukun U+07B0 is NSM': (0x07B0, null),
      'Thaana unassigned U+07BF defaults to AL': (0x07BF, rtl),
      "N'Ko a U+07CA": (0x07CA, rtl),
      "N'Ko digit zero U+07C0 is R": (0x07C0, rtl),
      "N'Ko combining tone U+07EB is NSM": (0x07EB, null),
      'Samaritan U+0800': (0x0800, rtl),
      'Mandaic U+0840': (0x0840, rtl),
      'Adlam U+1E900': (0x1E900, rtl),
      'Hanifi Rohingya U+10D00': (0x10D00, rtl),
      'Hebrew unassigned U+05FF defaults to R': (0x05FF, rtl),
      'RLM': (0x200F, rtl),
      'LRM': (0x200E, ltr),
      'Hebrew point sheva U+05B0 is NSM': (0x05B0, null),
      'Arabic fatha U+064E is NSM': (0x064E, null),
      'Arabic superscript alef U+0670 is NSM': (0x0670, null),
      'Syriac pthaha U+0730 is NSM': (0x0730, null),
      'Arabic-Indic digit U+0660 is AN': (0x0660, null),
      'Extended Arabic-Indic digit U+06F0 is EN': (0x06F0, null),
      'Arabic comma U+060C is CS': (0x060C, null),
      'Arabic percent U+066A is ET': (0x066A, null),
      'ASCII digit': (0x31, null),
      'space': (0x20, null),
      'emoji': (0x1F600, null),
      'Devanagari vowel sign U U+0941 is NSM': (0x0941, null),
    };
    cases.forEach((name, expectation) {
      test(name, () {
        expect(strongDirectionOf(expectation.$1), expectation.$2);
      });
    });

    test('table was generated from a recent Unicode version', () {
      expect(int.parse(kBidiUnicodeVersion.split('.').first), greaterThan(14));
    });
  });

  group('detectTextDirection', () {
    test('empty and neutral-only text has no direction', () {
      expect(detectTextDirection(''), isNull);
      expect(detectTextDirection('   123 !? 😀'), isNull);
      expect(detectTextDirection('٣٤٥ ۱۲۳'), isNull);
    });

    test('Latin text is ltr', () {
      expect(detectTextDirection('Hello'), TextDirection.ltr);
    });

    test('Hebrew, Arabic, Persian, Urdu, Syriac, Thaana, NKo are rtl', () {
      for (final text in <String>[
        'שלום',
        'مرحبا',
        'سلام، چطوری؟',
        'آپ کیسے ہیں',
        'ܫܠܡܐ',
        'ދ\u07A8ވ\u07ACހ\u07A8',
        'ߒߞߏ',
      ]) {
        expect(detectTextDirection(text), TextDirection.rtl, reason: text);
      }
    });

    test('leading neutrals and marks are skipped', () {
      expect(detectTextDirection('123 - שלום'), TextDirection.rtl);
      expect(detectTextDirection('"(!) hello مرحبا'), TextDirection.ltr);
      expect(detectTextDirection('\u064E\u0650abc'), TextDirection.ltr);
      expect(detectTextDirection('😀 مرحبا'), TextDirection.rtl);
    });

    test('first strong character wins in mixed text', () {
      expect(detectTextDirection('Flutter و دارت'), TextDirection.ltr);
      expect(detectTextDirection('دارت and Flutter'), TextDirection.rtl);
    });

    test('isolates are skipped (UAX #9 P2)', () {
      expect(
        detectTextDirection('\u2067English inside RLI\u2069 שלום'),
        TextDirection.rtl,
      );
      expect(
        detectTextDirection('\u2066\u2068שלום\u2069 still inside\u2069 abc'),
        TextDirection.ltr,
      );
      // Unterminated isolate: nothing outside it.
      expect(detectTextDirection('\u2068abc'), isNull);
    });

    test('marks decide when nothing else does', () {
      expect(detectTextDirection('\u200F123'), TextDirection.rtl);
      expect(detectTextDirection('\u200E١٢٣'), TextDirection.ltr);
    });

    test('only the first paragraph is examined', () {
      expect(detectTextDirection('123\nשלום'), isNull);
      expect(detectTextDirection('abc שלום'), TextDirection.ltr);
    });

    test('supplementary-plane letters are handled as runes', () {
      expect(detectTextDirection('\u{1E900}'), TextDirection.rtl);
      expect(detectTextDirection('\u{1D400}'), TextDirection.ltr);
    });
  });
}
