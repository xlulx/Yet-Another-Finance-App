import 'package:intl/intl.dart';

/// Formats an amount in minor units: 123456 -> "1.234,56 ₺".
String formatMoney(int cents, String symbol, {bool signed = false}) {
  final f = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: symbol,
    decimalDigits: 2,
  );
  final text = f.format(cents.abs() / 100);
  if (!signed || cents == 0) return cents < 0 ? '-$text' : text;
  return cents < 0 ? '-$text' : '+$text';
}

/// Parses user input into minor units. Accepts "1.234,5", "1234.50", "12"
/// and similar; returns null if invalid.
int? parseMoney(String input) {
  var s = input.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    // If both are present, the last one is the decimal separator.
    final decimal = lastComma > lastDot ? ',' : '.';
    final thousands = decimal == ',' ? '.' : ',';
    s = s.replaceAll(thousands, '').replaceAll(decimal, '.');
  } else if (lastComma >= 0) {
    s = s.replaceAll(',', '.');
  }
  // Several dots left (1.234.567): treat them as thousands separators.
  final parts = s.split('.');
  if (parts.length > 2) {
    final tail = parts.removeLast();
    s = parts.join() + (tail.length == 3 ? tail : '.$tail');
  }
  final value = double.tryParse(s);
  if (value == null || value.isNaN || value.isInfinite || value < 0) {
    return null;
  }
  return (value * 100).round();
}
