import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yafa/utils/money.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  group('parseMoney', () {
    test('accepted formats', () {
      expect(parseMoney('12'), 1200);
      expect(parseMoney('12,5'), 1250);
      expect(parseMoney('12.50'), 1250);
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('1,234.56'), 123456);
      expect(parseMoney('1.234.567'), 123456700);
      expect(parseMoney(' 0,01 '), 1);
      expect(parseMoney('0.1'), 10);
    });

    test('invalid input', () {
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('-5'), isNull);
    });
  });

  test('formatMoney follows the locale', () {
    expect(formatMoney(123456, '₺', locale: 'tr'), contains('1.234,56'));
    expect(formatMoney(123456, r'$', locale: 'en'), r'$1,234.56');
    expect(formatMoney(-500, '₺', locale: 'tr'), startsWith('-'));
    expect(formatMoney(500, '₺', signed: true, locale: 'tr'), startsWith('+'));
  });
}
