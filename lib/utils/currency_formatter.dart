import 'package:flutter/services.dart';
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

  /// Hitung jatah harian dengan pembulatan otomatis ke bawah (kelipatan Rp 500 atau Rp 1.000)
  /// agar tidak muncul pecahan ganjil seperti Rp 8.333/hari. Selisih pembulatan tetap utuh di saldo santri.
  static int hitungJatahHarianBulat(int nominalBersih, int durasiHari, {int kelipatan = 500}) {
    if (nominalBersih <= 0 || durasiHari <= 0) return 0;
    final step = kelipatan <= 0 ? 500 : kelipatan;
    final raw = nominalBersih ~/ durasiHari;
    final rounded = (raw ~/ step) * step;
    return rounded > 0 ? rounded : raw;
  }

  /// Hitung selisih pembulatan yang tetap tersimpan utuh di saldo santri
  static int hitungSelisihPembulatan(int nominalBersih, int durasiHari, int jatahBulat) {
    if (nominalBersih <= 0 || durasiHari <= 0) return 0;
    return (nominalBersih - (jatahBulat * durasiHari)).clamp(0, nominalBersih);
  }
}

/// TextInputFormatter untuk memformat pemisah ribuan titik otomatis saat mengetik (misal: 10.000)
class RibuanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(digitsOnly) ?? 0;
    final formatted = CurrencyFormatter.formatWithoutSymbol(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
