import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _compactFormatter = NumberFormat.compactCurrency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format angka integer ke string Rupiah, contoh: 10000 -> "Rp 10.000"
  static String format(int amount) {
    return _formatter.format(amount);
  }

  /// Format tanpa prefix Rp, contoh: 10000 -> "10.000"
  static String formatWithoutSymbol(int amount) {
    final formatNumber = NumberFormat('#,###', 'id_ID');
    return formatNumber.format(amount);
  }

  /// Format ringkas, contoh: 1500000 -> "Rp 1,5 jt"
  static String formatCompact(int amount) {
    return _compactFormatter.format(amount);
  }

  /// Parsing input string angka dengan pemisah titik menjadi integer murni
  static int parse(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return 0;
    return int.tryParse(cleanText) ?? 0;
  }
}
