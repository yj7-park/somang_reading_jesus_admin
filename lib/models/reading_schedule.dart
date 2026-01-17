import 'package:cloud_firestore/cloud_firestore.dart';

class ReadingSchedule {
  final String year;
  final DateTime? startDate;
  final List<ScheduleDateRange> holidays;

  ReadingSchedule({required this.year, this.startDate, required this.holidays});

  factory ReadingSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse holidays safely
    List<ScheduleDateRange> parsedHolidays = [];
    final holidaysData = data['holidays'];
    if (holidaysData is List) {
      for (var item in holidaysData) {
        if (item is Map) {
          DateTime? start;
          DateTime? end;
          String? description;

          final s = item['start'];
          if (s is Timestamp) start = s.toDate();

          final e = item['end'];
          if (e is Timestamp) end = e.toDate();

          final d = item['description'];
          if (d is String) description = d;

          if (start != null && end != null) {
            parsedHolidays.add(
              ScheduleDateRange(
                start: start,
                end: end,
                description: description,
              ),
            );
          }
        }
      }
    }

    DateTime? startDate;
    final sd = data['startDate'];
    if (sd is Timestamp) {
      startDate = sd.toDate();
    }

    return ReadingSchedule(
      year: doc.id,
      startDate: startDate,
      holidays: parsedHolidays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'holidays': holidays
          .map(
            (range) => {
              'start': Timestamp.fromDate(range.start),
              'end': Timestamp.fromDate(range.end),
              'description': range.description,
            },
          )
          .toList(),
    };
  }
}

class ScheduleDateRange {
  final DateTime start;
  final DateTime end;
  final String? description;

  ScheduleDateRange({required this.start, required this.end, this.description});
}
