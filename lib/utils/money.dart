import 'package:intl/intl.dart';

/// Kuruş cinsinden tutarı biçimlendirir: 123456 -> "1.234,56 ₺".
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

/// Kullanıcının yazdığı tutarı kuruşa çevirir. "1.234,5", "1234.50", "12"
/// gibi girdileri kabul eder; geçersizse null döner.
int? parseMoney(String input) {
  var s = input.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    // İkisi de varsa sondaki ondalık ayırıcıdır.
    final decimal = lastComma > lastDot ? ',' : '.';
    final thousands = decimal == ',' ? '.' : ',';
    s = s.replaceAll(thousands, '').replaceAll(decimal, '.');
  } else if (lastComma >= 0) {
    s = s.replaceAll(',', '.');
  }
  // Birden fazla nokta kaldıysa (1.234.567) sonuncusu hariç binlik say.
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
