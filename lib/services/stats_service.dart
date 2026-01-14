import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/reading_schedule.dart';
import '../utils/date_helper.dart';

class StatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get Total Users count
  Future<int> getTotalUsers() async {
    final countQuery = await _db.collection('users').count().get();
    return countQuery.count ?? 0;
  }

  // Get Count of users who read today (Collection Group Query on 'summary')
  // We assume 'stats/summary' doc has 'lastReadDate'
  Future<int> getTodayReadersCount() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    final countQuery = await _db
        .collectionGroup('stats')
        .where('last_completed_date', isGreaterThanOrEqualTo: todayStart)
        .count()
        .get();

    return countQuery.count ?? 0;
  }

  // Calculate Average Progress Percentage relative to today's target
  Future<Map<String, dynamic>> getProgressStats() async {
    final userCountQuery = await _db.collection('users').count().get();
    final userCount = userCountQuery.count ?? 0;
    if (userCount == 0) return {'avgProgressPercent': 0.0};

    // Get current year schedule to find target index
    final now = DateTime.now();
    final year = now.year.toString();
    final scheduleDoc = await _db
        .collection('config')
        .doc('schedule')
        .collection('years')
        .doc(year)
        .get();

    int targetIndex = 0;
    if (scheduleDoc.exists) {
      final schedule = ReadingSchedule.fromFirestore(scheduleDoc);
      targetIndex =
          DateHelper.getReadingIndex(now, schedule) +
          1; // 1-based current target days
    }

    if (targetIndex <= 0) return {'avgProgressPercent': 0.0};

    double totalCompletionRatio = 0.0;
    final statsSnap = await _db.collectionGroup('stats').get();

    for (var doc in statsSnap.docs) {
      final data = doc.data();
      if (data['total_days_completed'] != null) {
        double completed = (data['total_days_completed'] as num).toDouble();
        double ratio = (completed / targetIndex).clamp(0.0, 1.0);
        totalCompletionRatio += ratio;
      }
    }

    double avgProgressPercent = (totalCompletionRatio / userCount) * 100;
    return {'avgProgressPercent': avgProgressPercent};
  }

  // Get Age Distribution with total and caught-up counts
  Future<Map<String, Map<String, int>>> getDetailedAgeStats() async {
    final now = DateTime.now();
    final year = now.year.toString();
    final scheduleDoc = await _db
        .collection('config')
        .doc('schedule')
        .collection('years')
        .doc(year)
        .get();

    int targetIndex = 0;
    if (scheduleDoc.exists) {
      final schedule = ReadingSchedule.fromFirestore(scheduleDoc);
      targetIndex = DateHelper.getReadingIndex(now, schedule) + 1;
    }

    final usersSnap = await _db.collection('users').get();
    final statsSnap = await _db.collectionGroup('stats').get();

    Map<String, int> userProgressMap = {};
    for (var doc in statsSnap.docs) {
      final parentDoc = doc.reference.parent.parent;
      if (parentDoc != null) {
        userProgressMap[parentDoc.id] =
            (doc.data()['total_days_completed'] as num? ?? 0).toInt();
      }
    }

    Map<String, Map<String, int>> distribution = {
      '10s': {'total': 0, 'completed': 0},
      '20s': {'total': 0, 'completed': 0},
      '30s': {'total': 0, 'completed': 0},
      '40s': {'total': 0, 'completed': 0},
      '50s': {'total': 0, 'completed': 0},
      '60s': {'total': 0, 'completed': 0},
      '70s+': {'total': 0, 'completed': 0},
      'Unknown': {'total': 0, 'completed': 0},
    };

    for (var doc in usersSnap.docs) {
      final data = doc.data();
      String? dobStr;
      final dobVal = data['birthDate'];

      if (dobVal is String) {
        dobStr = dobVal;
      } else if (dobVal is Timestamp) {
        final date = dobVal.toDate();
        dobStr =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }

      String ageGroup = 'Unknown';
      if (dobStr != null && dobStr.length >= 4) {
        try {
          int birthYear = int.parse(dobStr.substring(0, 4));
          int age = now.year - birthYear;
          if (age >= 10 && age < 20)
            ageGroup = '10s';
          else if (age < 30)
            ageGroup = '20s';
          else if (age < 40)
            ageGroup = '30s';
          else if (age < 50)
            ageGroup = '40s';
          else if (age < 60)
            ageGroup = '50s';
          else if (age < 70)
            ageGroup = '60s';
          else if (age >= 70)
            ageGroup = '70s+';
        } catch (_) {}
      }

      distribution[ageGroup]!['total'] = distribution[ageGroup]!['total']! + 1;

      int userCompleted = userProgressMap[doc.id] ?? 0;
      if (targetIndex > 0 && userCompleted >= targetIndex) {
        distribution[ageGroup]!['completed'] =
            distribution[ageGroup]!['completed']! + 1;
      }
    }

    return distribution;
  }

  // --- Real-time Stream Support ---

  /// A stream that combines all stats required for the dashboard.
  Stream<Map<String, dynamic>> getStatsStream() {
    final now = DateTime.now();
    final yearStr = now.year.toString();

    // 1. Get Schedule Stream
    final scheduleStream = _db
        .collection('config')
        .doc('schedule')
        .collection('years')
        .doc(yearStr)
        .snapshots();

    return scheduleStream.switchMap((scheduleDoc) {
      // Calculate today's reading position
      int year = now.year;
      int week = -1;
      int day = -1;
      int targetIndex = 0;

      if (scheduleDoc.exists) {
        final schedule = ReadingSchedule.fromFirestore(scheduleDoc);
        targetIndex = DateHelper.getReadingIndex(now, schedule) + 1;
        final pos = DateHelper.getReadingPosition(now, schedule);
        if (pos != null) {
          year = pos.year;
          week = pos.week;
          day = pos.day;
        }
      }

      // 2. Today's completions query
      Stream<QuerySnapshot> completionsStream;
      if (week != -1) {
        completionsStream = _db
            .collectionGroup('completions')
            .where('year', isEqualTo: year)
            .where('week', isEqualTo: week)
            .where('day', isEqualTo: day)
            .snapshots();
      } else {
        completionsStream = Stream.value(null).cast<QuerySnapshot>();
      }

      // 3. Combine with Users and Total Stats
      return CombineLatestStream.combine4(
        _db.collection('users').snapshots(),
        _db.collectionGroup('stats').snapshots(),
        completionsStream,
        Stream.value(scheduleDoc), // Pass through
        (usersSnap, statsSnap, QuerySnapshot? completionsSnap, _) {
          final userCount = usersSnap.docs.length;
          if (userCount == 0) {
            return {
              'totalUsers': 0,
              'todayReaders': 0,
              'avgProgressPercent': 0.0,
              'ageStats': <String, Map<String, int>>{},
            };
          }

          Set<String> existingUserUids = usersSnap.docs
              .map((d) => d.id)
              .toSet();

          // Today's readers calculation (Unique Users who completed TODAY'S task)
          Set<String> todayReaderUids = {};
          if (completionsSnap != null) {
            for (var doc in completionsSnap.docs) {
              final parentDoc = doc.reference.parent.parent;
              if (parentDoc != null) {
                final uid = parentDoc.id;
                if (existingUserUids.contains(uid)) {
                  todayReaderUids.add(uid);
                }
              }
            }
          }

          // Progress calculation
          double totalCompletionRatio = 0.0;
          Map<String, int> userProgressMap = {};

          for (var doc in statsSnap.docs) {
            final data = doc.data();
            final parentDoc = doc.reference.parent.parent;
            if (parentDoc == null) continue;

            final uid = parentDoc.id;
            if (!existingUserUids.contains(uid)) continue;

            final completed = (data['total_days_completed'] as num? ?? 0)
                .toDouble();
            userProgressMap[uid] = completed.toInt();

            if (targetIndex > 0) {
              totalCompletionRatio += (completed / targetIndex).clamp(0.0, 1.0);
            }
          }

          double avgProgressPercent = (totalCompletionRatio / userCount) * 100;

          // Age distribution (Reuse logic)
          Map<String, Map<String, int>> distribution = {
            '10s': {'total': 0, 'completed': 0},
            '20s': {'total': 0, 'completed': 0},
            '30s': {'total': 0, 'completed': 0},
            '40s': {'total': 0, 'completed': 0},
            '50s': {'total': 0, 'completed': 0},
            '60s': {'total': 0, 'completed': 0},
            '70s+': {'total': 0, 'completed': 0},
            'Unknown': {'total': 0, 'completed': 0},
          };

          for (var doc in usersSnap.docs) {
            final data = doc.data();
            final birthDateVal = data['birthDate'];
            String? dobStr;

            if (birthDateVal is String) {
              dobStr = birthDateVal;
            } else if (birthDateVal is Timestamp) {
              final date = birthDateVal.toDate();
              dobStr =
                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            }

            String ageGroup = 'Unknown';
            if (dobStr != null && dobStr.length >= 4) {
              try {
                int birthYear = int.parse(dobStr.substring(0, 4));
                int age = now.year - birthYear;
                if (age >= 10 && age < 20)
                  ageGroup = '10s';
                else if (age < 30)
                  ageGroup = '20s';
                else if (age < 40)
                  ageGroup = '30s';
                else if (age < 50)
                  ageGroup = '40s';
                else if (age < 60)
                  ageGroup = '50s';
                else if (age < 70)
                  ageGroup = '60s';
                else if (age >= 70)
                  ageGroup = '70s+';
              } catch (_) {}
            }

            distribution[ageGroup]!['total'] =
                distribution[ageGroup]!['total']! + 1;
            int completedCount = userProgressMap[doc.id] ?? 0;
            if (targetIndex > 0 && completedCount >= targetIndex) {
              distribution[ageGroup]!['completed'] =
                  distribution[ageGroup]!['completed']! + 1;
            }
          }

          return {
            'totalUsers': userCount,
            'todayReaders': todayReaderUids.length,
            'avgProgressPercent': avgProgressPercent,
            'ageStats': distribution,
          };
        },
      );
    });
  }
}
