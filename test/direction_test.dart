import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_language/keyboard_language.dart';

import 'fake_platform.dart';

void main() {
  final arabic = lang('ar');
  final english = lang('en-US');
  final webHebrew = lang('he', source: InputLanguageSource.browserLocale);

  group('resolveTextDirection', () {
    test('keyboardThenText prefers a strong keyboard', () {
      expect(
        resolveTextDirection(text: 'hello', keyboard: arabic),
        TextDirection.rtl,
      );
      expect(
        resolveTextDirection(text: 'שלום', keyboard: english),
        TextDirection.ltr,
      );
      expect(resolveTextDirection(text: 'שלום'), TextDirection.rtl);
      expect(
        resolveTextDirection(text: '123', fallback: TextDirection.rtl),
        TextDirection.rtl,
      );
    });

    test('textThenKeyboard prefers typed text', () {
      const policy = AutoDirectionPolicy.textThenKeyboard;
      expect(
        resolveTextDirection(text: 'مرحبا', keyboard: english, policy: policy),
        TextDirection.rtl,
      );
      expect(
        resolveTextDirection(text: '', keyboard: arabic, policy: policy),
        TextDirection.rtl,
      );
    });

    test('keyboardOnly and textOnly', () {
      expect(
        resolveTextDirection(
          text: 'hello',
          keyboard: arabic,
          policy: AutoDirectionPolicy.keyboardOnly,
        ),
        TextDirection.rtl,
      );
      expect(
        resolveTextDirection(
          text: 'שלום',
          policy: AutoDirectionPolicy.keyboardOnly,
        ),
        TextDirection.ltr,
      );
      expect(
        resolveTextDirection(
          text: 'hello',
          keyboard: arabic,
          policy: AutoDirectionPolicy.textOnly,
        ),
        TextDirection.ltr,
      );
    });

    test('a weak (browser locale) keyboard never beats typed text', () {
      expect(
        resolveTextDirection(text: 'hello', keyboard: webHebrew),
        TextDirection.ltr,
      );
      expect(
        resolveTextDirection(text: '', keyboard: webHebrew),
        TextDirection.rtl,
      );
    });
  });
}
