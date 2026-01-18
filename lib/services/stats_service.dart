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
    // This value is actually derived from streams in the dashboard,
    // but if needed as a single future, we'd need to fetch schedule + stats.
    // For now, simpler to just return 0 or implement fully if used elsewhere.
    // Given the request context, this method might be legacy or less used,
    // but let's update it to be consistent if possible, or just leave it
    // if it's not the main source. The Dashboard uses getStatsStream.
    // Let's implement it correctly.

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

    if (targetIndex <= 0) return 0;

    final countQuery = await _db
        .collectionGroup('stats')
        .where('total_days_completed', isGreaterThanOrEqualTo: targetIndex)
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
      '10대': {'total': 0, 'completed': 0},
      '20대': {'total': 0, 'completed': 0},
      '30대': {'total': 0, 'completed': 0},
      '40대': {'total': 0, 'completed': 0},
      '50대': {'total': 0, 'completed': 0},
      '60대': {'total': 0, 'completed': 0},
      '70대+': {'total': 0, 'completed': 0},
      '미상': {'total': 0, 'completed': 0},
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

      String ageGroup = '미상';
      if (dobStr != null && dobStr.length >= 4) {
        try {
          int birthYear = int.parse(dobStr.substring(0, 4));
          int age = now.year - birthYear;
          if (age >= 10 && age < 20)
            ageGroup = '10대';
          else if (age < 30)
            ageGroup = '20대';
          else if (age < 40)
            ageGroup = '30대';
          else if (age < 50)
            ageGroup = '40대';
          else if (age < 60)
            ageGroup = '50대';
          else if (age < 70)
            ageGroup = '60대';
          else if (age >= 70)
            ageGroup = '70대+';
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
      int targetIndex = 0;

      if (scheduleDoc.exists) {
        final schedule = ReadingSchedule.fromFirestore(scheduleDoc);
        targetIndex = DateHelper.getReadingIndex(now, schedule) + 1;
        final pos = DateHelper.getReadingPosition(now, schedule);
        // Position logic removed as we don't query via completions anymore
        if (pos != null) {
          // year = pos.year; // Unused
          // week = pos.week; // Unused
          // day = pos.day;   // Unused
        }
      }

      // 2. Filter completions (removed - using stats instead)

      // 3. Combine with Users and Total Stats
      return CombineLatestStream.combine3(
        _db.collection('users').snapshots(),
        _db.collectionGroup('stats').snapshots(),
        Stream.value(scheduleDoc),
        (usersSnap, statsSnap, _) {
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

          // Progress calculation & Today's Readers (>= targetIndex)
          double totalCompletionRatio = 0.0;
          Set<String> todayReaderUids = {};
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
              if (completed >= targetIndex) {
                todayReaderUids.add(uid);
              }
            }
          }

          double avgProgressPercent = (totalCompletionRatio / userCount) * 100;

          // Age distribution (Reuse logic)
          Map<String, Map<String, int>> distribution = {
            '10대': {'total': 0, 'completed': 0},
            '20대': {'total': 0, 'completed': 0},
            '30대': {'total': 0, 'completed': 0},
            '40대': {'total': 0, 'completed': 0},
            '50대': {'total': 0, 'completed': 0},
            '60대': {'total': 0, 'completed': 0},
            '70대+': {'total': 0, 'completed': 0},
            '미상': {'total': 0, 'completed': 0},
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

            String ageGroup = '미상';
            if (dobStr != null && dobStr.length >= 4) {
              try {
                int birthYear = int.parse(dobStr.substring(0, 4));
                int age = now.year - birthYear;
                if (age >= 10 && age < 20)
                  ageGroup = '10대';
                else if (age < 30)
                  ageGroup = '20대';
                else if (age < 40)
                  ageGroup = '30대';
                else if (age < 50)
                  ageGroup = '40대';
                else if (age < 60)
                  ageGroup = '50대';
                else if (age < 70)
                  ageGroup = '60대';
                else if (age >= 70)
                  ageGroup = '70대+';
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
