enum TimeCategory { pagi, siang, sore, malam }

class TimeCategoryHelper {
  /// Mengelompokkan waktu pengambilan:
  /// - PAGI: 05:00 - 10:59
  /// - SIANG: 11:00 - 14:59
  /// - SORE: 15:00 - 17:59
  /// - MALAM: 18:00 - 04:59
  static TimeCategory fromDateTime(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 5 && hour < 11) {
      return TimeCategory.pagi;
    } else if (hour >= 11 && hour < 15) {
      return TimeCategory.siang;
    } else if (hour >= 15 && hour < 18) {
      return TimeCategory.sore;
    } else {
      return TimeCategory.malam;
    }
  }

  static String toDbString(TimeCategory category) {
    switch (category) {
      case TimeCategory.pagi:
        return 'PAGI';
      case TimeCategory.siang:
        return 'SIANG';
      case TimeCategory.sore:
        return 'SORE';
      case TimeCategory.malam:
        return 'MALAM';
    }
  }

  static TimeCategory fromDbString(String str) {
    switch (str.toUpperCase()) {
      case 'PAGI':
        return TimeCategory.pagi;
      case 'SIANG':
        return TimeCategory.siang;
      case 'SORE':
        return TimeCategory.sore;
      case 'MALAM':
      default:
        return TimeCategory.malam;
    }
  }

  static String getLabel(TimeCategory category) {
    switch (category) {
      case TimeCategory.pagi:
        return 'Pagi';
      case TimeCategory.siang:
        return 'Siang';
      case TimeCategory.sore:
        return 'Sore';
      case TimeCategory.malam:
        return 'Malam';
    }
  }

  static String getEmoji(TimeCategory category) {
    switch (category) {
      case TimeCategory.pagi:
        return '🌅';
      case TimeCategory.siang:
        return '☀️';
      case TimeCategory.sore:
        return '🌇';
      case TimeCategory.malam:
        return '🌙';
    }
  }
}
