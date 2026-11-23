import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _localDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('d MMMM yyyy', 'id_ID');
  static final DateFormat _fullDateTimeFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
  static final DateFormat _timeOnlyFormat = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');

  /// Menghasilkan format YYYY-MM-DD untuk query database
  static String toLocalDateString(DateTime date) {
    return _localDateFormat.format(date);
  }

  /// Menghasilkan format tanggal Indonesia, contoh: "23 November 2026"
  static String formatDisplayDate(DateTime date) {
    return _displayDateFormat.format(date);
  }

  /// Menghasilkan format tanggal dan waktu, contoh: "23 Nov 2026, 12:45"
  static String formatFullDateTime(DateTime date) {
    return _fullDateTimeFormat.format(date);
  }

  /// Menghasilkan jam presisi dengan WIB, contoh: "12:45 WIB"
  static String formatTimeWithWIB(DateTime date) {
    return '${_timeOnlyFormat.format(date)} WIB';
  }

  /// Format Bulan dan Tahun, contoh: "November 2026"
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }
}
