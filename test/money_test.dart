import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yafa/utils/money.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('parseMoney', () {
    test('kabul edilen biçimler', () {
      expect(parseMoney('12'), 1200);
      expect(parseMoney('12,5'), 1250);
      expect(parseMoney('12.50'), 1250);
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('1,234.56'), 123456);
      expect(parseMoney('1.234.567'), 123456700);
      expect(parseMoney(' 0,01 '), 1);
      expect(parseMoney('0.1'), 10);
    });

    test('geçersiz girdiler', () {
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('-5'), isNull);
    });
  });

  test('formatMoney', () {
    expect(formatMoney(123456, '₺'), contains('1.234,56'));
    expect(formatMoney(-500, '₺'), startsWith('-'));
    expect(formatMoney(500, '₺', signed: true), startsWith('+'));
  });
}
