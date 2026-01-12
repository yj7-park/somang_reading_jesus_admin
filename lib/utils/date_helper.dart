import '../models/reading_schedule.dart';

class ReadingPosition {
  final int year;
  final int week;
  final int day;

  ReadingPosition({required this.year, required this.week, required this.day});

  String get docId => "${year}_${week}_$day";
}

class DateHelper {
  /// Calculate the exact year, week, and day position for a given date based on the schedule.
  static ReadingPosition? getReadingPosition(
    DateTime targetDate,
    ReadingSchedule schedule,
  ) {
    int index = getReadingIndex(targetDate, schedule);
    if (index < 0) return null;

    int week = (index ~/ 6) + 1;
    int day = (index % 6) + 1;
    int year = int.tryParse(schedule.year) ?? targetDate.year;

    return ReadingPosition(year: year, week: week, day: day);
  }

  /// Calculate the current reading index (0-based) based on the schedule, skipping weekends and holidays.
  static int getReadingIndex(DateTime targetDate, ReadingSchedule schedule) {
    DateTime startDate = schedule.startDate;
    if (targetDate.isBefore(startDate)) return -1;

    int readingDays = 0;
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedTarget = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    while (!current.isAfter(normalizedTarget)) {
      // Mon~Sat (1~6) are reading days
      bool isReadingDay =
          current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.saturday;

      if (isReadingDay) {
        // Check if it's a holiday
        bool isHoliday = false;
        for (final holiday in schedule.holidays) {
          if ((current.isAfter(holiday.start) ||
                  isSameDay(current, holiday.start)) &&
              (current.isBefore(holiday.end) ||
                  isSameDay(current, holiday.end))) {
            isHoliday = true;
            break;
          }
        }

        if (!isHoliday) {
          readingDays++;
        }
      }
      current = current.add(const Duration(days: 1));
      if (current.year > (normalizedTarget.year + 2)) break; // Safety break
    }

    return readingDays - 1; // 0-based index
  }

  /// Calculate the end date of the 270-day reading plan.
  static DateTime getEndDate(ReadingSchedule schedule) {
    int readingDays = 0;
    DateTime current = schedule.startDate;

    while (readingDays < 270) {
      bool isReadingDay =
          current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.saturday;

      if (isReadingDay) {
        bool isHoliday = false;
        for (final holiday in schedule.holidays) {
          if ((current.isAfter(holiday.start) ||
                  isSameDay(current, holiday.start)) &&
              (current.isBefore(holiday.end) ||
                  isSameDay(current, holiday.end))) {
            isHoliday = true;
            break;
          }
        }

        if (!isHoliday) {
          readingDays++;
          if (readingDays == 270) return current;
        }
      }
      current = current.add(const Duration(days: 1));
      // Safety break to prevent infinite loop
      if (current.year > (schedule.startDate.year + 2)) break;
    }

    return current;
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
