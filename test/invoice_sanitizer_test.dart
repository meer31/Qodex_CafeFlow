import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/services/invoice_service.dart';

void main() {
  group('InvoiceService.sanitizeForThermal tests', () {
    test('removes emoticons and smileys', () {
      final input = 'Thank you for visiting! 😊😀🥰 Have a great day!';
      final result = InvoiceService.sanitizeForThermal(input);
      expect(result, equals('Thank you for visiting! Have a great day!'));
    });

    test('removes food and misc symbols (coffee, heart, stars)', () {
      final input = 'Enjoy your coffee ☕ and burger 🍔! Best wishes ❤️ ⭐';
      final result = InvoiceService.sanitizeForThermal(input);
      expect(result, equals('Enjoy your coffee and burger! Best wishes'));
    });

    test('replaces non-ASCII dashes and bullets with safe ASCII', () {
      final input = 'QODEX SOFTWARE — CODE THE FUTURE • Ph: 123 – 456';
      final result = InvoiceService.sanitizeForThermal(input);
      expect(result, equals('QODEX SOFTWARE - CODE THE FUTURE | Ph: 123 - 456'));
    });

    test('replaces smart quotes', () {
      final input = '“Welcome” and ‘Thanks’';
      final result = InvoiceService.sanitizeForThermal(input);
      expect(result, equals('"Welcome" and \'Thanks\''));
    });

    test('replaces trademark and copyright symbols', () {
      final input = 'Cafe Indus™ © 2026';
      final result = InvoiceService.sanitizeForThermal(input);
      expect(result, equals('Cafe IndusTM (C) 2026'));
    });

    test('handles empty and whitespace strings', () {
      expect(InvoiceService.sanitizeForThermal(''), equals(''));
      expect(InvoiceService.sanitizeForThermal('   '), equals(''));
    });

    test('removes flags and complex multi-codepoint emojis', () {
      final input = 'Special offer! 🇵🇰 🎉 👍';
      final result = InvoiceService.sanitizeForThermal(input);
      expect(result, equals('Special offer!'));
    });
  });
}
