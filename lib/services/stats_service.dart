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
    final year = now.year.toString();

    // 1. Users Stream
    final usersStream = _db.collection('users').snapshots();

    // 2. Stats Stream (Collection Group)
    final statsStream = _db.collectionGroup('stats').snapshots();

    // 3. Schedule Stream
    final scheduleStream = _db
        .collection('config')
        .doc('schedule')
        .collection('years')
        .doc(year)
        .snapshots();

    return CombineLatestStream.combine3(
      usersStream,
      statsStream,
      scheduleStream,
      (usersSnap, statsSnap, scheduleDoc) {
        final userCount = usersSnap.docs.length;
        if (userCount == 0) {
          return {
            'totalUsers': 0,
            'todayReaders': 0,
            'avgProgressPercent': 0.0,
            'ageStats': <String, Map<String, int>>{},
          };
        }

        // Target index from schedule
        int targetIndex = 0;
        if (scheduleDoc.exists) {
          final schedule = ReadingSchedule.fromFirestore(scheduleDoc);
          targetIndex = DateHelper.getReadingIndex(now, schedule) + 1;
        }

        // Today's readers
        final todayStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).toIso8601String();
        int todayReaders = 0;

        // Progress calculate
        double totalCompletionRatio = 0.0;
        Map<String, int> userProgressMap = {};

        for (var doc in statsSnap.docs) {
          final data = doc.data();
          final lastCompleted = data['last_completed_date'] as String?;
          if (lastCompleted != null &&
              lastCompleted.compareTo(todayStart) >= 0) {
            todayReaders++;
          }

          final completed = (data['total_days_completed'] as num? ?? 0)
              .toDouble();
          if (targetIndex > 0) {
            totalCompletionRatio += (completed / targetIndex).clamp(0.0, 1.0);
          }

          final parentDoc = doc.reference.parent.parent;
          if (parentDoc != null) {
            userProgressMap[parentDoc.id] = completed.toInt();
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
          'todayReaders': todayReaders,
          'avgProgressPercent': avgProgressPercent,
          'ageStats': distribution,
        };
      },
    );
  }
}
