import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:input_language/input_language.dart';

void main() {
  group('isRtlLanguageTag', () {
    test('right-to-left languages', () {
      for (final tag in <String>[
        'ar',
        'ar-EG',
        'he',
        'he-IL',
        'iw',
        'fa',
        'fa_IR',
        'prs',
        'ur',
        'ur-PK',
        'ps',
        'sd',
        'ug',
        'yi',
        'dv',
        'ckb',
        'syr',
        'nqo',
        'ks',
        'AR',
        'ku-Arab',
        'pa-Arab',
        'az-Arab',
        'ms-Arab',
        'ff-Adlm',
      ]) {
        expect(isRtlLanguageTag(tag), isTrue, reason: tag);
      }
    });

    test('left-to-right languages', () {
      for (final tag in <String>[
        'en',
        'en-US',
        'fr',
        'hi',
        'zh-Hans',
        'ja',
        'ku',
        'pa',
        'az',
        'uz',
        'ur-Latn',
        'sd-Deva',
        'tr',
        '',
        '-',
        'ar-Latn',
      ]) {
        expect(isRtlLanguageTag(tag), isFalse, reason: tag);
      }
    });
  });

  group('canonicalizeLanguageTag / localeFromLanguageTag', () {
    test('normalises separators and case', () {
      expect(canonicalizeLanguageTag('en_us'), 'en-US');
      expect(canonicalizeLanguageTag('ZH_hant_tw'), 'zh-Hant-TW');
      expect(canonicalizeLanguageTag('es-419'), 'es-419');
      expect(canonicalizeLanguageTag('de_DE.UTF-8'), 'de-DE');
      expect(canonicalizeLanguageTag('iw_IL'), 'he-IL');
      expect(canonicalizeLanguageTag('in'), 'id');
      expect(canonicalizeLanguageTag('az_Latn'), 'az-Latn');
      expect(canonicalizeLanguageTag('en-US-x-Private'), 'en-US-x-private');
      expect(canonicalizeLanguageTag('  '), 'und');
    });

    test('builds Locale subtags', () {
      expect(
        localeFromLanguageTag('zh-Hant-TW'),
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      );
      expect(localeFromLanguageTag('ar'), const Locale('ar'));
      expect(localeFromLanguageTag('es_419'), const Locale('es', '419'));
    });
  });

  group('InputLanguage', () {
    test('fromMap decodes and derives isRtl', () {
      final language = InputLanguage.fromMap(<Object?, Object?>{
        'languageTag': 'fa_IR',
        'displayName': 'Persian',
        'inputSourceId': 'com.apple.keylayout.Persian',
        'source': 'keyboardLayout',
      })!;
      expect(language.languageTag, 'fa-IR');
      expect(language.locale, const Locale('fa', 'IR'));
      expect(language.languageCode, 'fa');
      expect(language.isRtl, isTrue);
      expect(language.displayName, 'Persian');
      expect(language.source, InputLanguageSource.keyboardLayout);
      expect(language.inputSourceId, 'com.apple.keylayout.Persian');
      expect(InputLanguage.fromMap(language.toMap()), language);
    });

    test('pseudo-languages and empty payloads are null', () {
      expect(InputLanguage.fromMap(null), isNull);
      expect(InputLanguage.fromMap(<Object?, Object?>{}), isNull);
      for (final tag in <String>['emoji', 'dictation', '', 'und']) {
        expect(
          InputLanguage.fromMap(<Object?, Object?>{'languageTag': tag}),
          isNull,
          reason: tag,
        );
      }
    });

    test('empty optional strings become null; equality and hashCode', () {
      final a = InputLanguage(
        languageTag: 'he',
        source: InputLanguageSource.inputMethod,
        displayName: '',
        inputSourceId: '',
      );
      final b = InputLanguage(
        languageTag: 'HE',
        source: InputLanguageSource.inputMethod,
      );
      expect(a.displayName, isNull);
      expect(a.inputSourceId, isNull);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('rtl'));
    });

    test('browser locale is a weak source', () {
      expect(InputLanguageSource.browserLocale.isStrong, isFalse);
      expect(InputLanguageSource.inputMethod.isStrong, isTrue);
      expect(InputLanguageSource.keyboardLayout.isStrong, isTrue);
    });
  });
}
