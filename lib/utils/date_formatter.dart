import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _localDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('d MMMM yyyy', 'id_ID');
  static final DateFormat _fullDateTimeFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
  static final DateFormat _timeOnlyFormat = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');

  /// Menghasilkan format YYYY-MM-DD murni waktu lokal perangkat (anti-geser UTC)
  static String toLocalDateString(DateTime date) {
    final local = date.toLocal();
    return _localDateFormat.format(DateTime(local.year, local.month, local.day));
  }

  /// Parse YYYY-MM-DD menjadi DateTime tengah malam lokal
  static DateTime parseLocalDate(String ymd) {
    final parts = ymd.trim().split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(ymd)?.toLocal() ?? DateTime.now();
  }

  /// Menghasilkan format periode YYYY-MM berdasarkan waktu lokal perangkat
  static String formatPeriodeBulan(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}';
  }

  /// Menghitung Tahun Ajaran Masehi akurat untuk periode YYYY-MM
  /// (Juli–Desember = Y/(Y+1), Januari–Juni = (Y-1)/Y)
  static String formatAcademicYearForPeriode(
    String ym, {
    String? configuredTa,
  }) {
    final parts = ym.trim().split('-');
    final now = DateTime.now();
    final y = parts.length == 2 ? (int.tryParse(parts[0]) ?? now.year) : now.year;
    final m = parts.length == 2 ? (int.tryParse(parts[1]) ?? now.month).clamp(1, 12) : now.month;

    final startYear = m >= 7 ? y : y - 1;
    final endYear = startYear + 1;
    final span = '$startYear/$endYear';

    final trimmedTa = configuredTa?.trim() ?? '';
    if (trimmedTa.isNotEmpty && trimmedTa.contains(span)) {
      return trimmedTa;
    }
    if (trimmedTa.isNotEmpty) {
      final replaced = trimmedTa.replaceFirst(RegExp(r'\d{4}/\d{4}'), span);
      if (replaced != trimmedTa) return replaced;
    }
    return '$span M';
  }

  /// Menghasilkan format tanggal Indonesia, contoh: "23 November 2026"
  static String formatDisplayDate(DateTime date) {
    return _displayDateFormat.format(date.toLocal());
  }

  /// Menghasilkan format tanggal dan waktu lokal, contoh: "23 Nov 2026, 12:45"
  static String formatFullDateTime(DateTime date) {
    return _fullDateTimeFormat.format(date.toLocal());
  }

  /// Menghasilkan jam presisi lokal dengan WIB, contoh: "12:45 WIB"
  static String formatTimeWithWIB(DateTime date) {
    return '${_timeOnlyFormat.format(date.toLocal())} WIB';
  }

  /// Format Bulan dan Tahun lokal, contoh: "November 2026"
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date.toLocal());
  }
}
