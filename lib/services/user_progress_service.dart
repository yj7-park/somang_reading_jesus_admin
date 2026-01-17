import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/reading_schedule.dart';
import '../utils/date_helper.dart';

// Extension to UserAndRosterService or standalone
// Since it's related to specific user actions, let's keep it here or new service.
// Let's create a new 'ReadingProgressService' or append to 'UserAndRosterService' or 'StatsService'.
// Given 'StatsService' is for aggregation, let's put individual history in `UserAndRosterService` or new `UserProgressService`.
// Let's append to `UserAndRosterService` for simplicity or create `UserProgressService`. I'll create `UserProgressService`.

class UserProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get reading completions for a user
  // Returns List of Dates that are completed
  Future<List<DateTime>> getUserReadings(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('completions')
        .get();
    // Assuming doc ID is 'YYYY-MM-DD' or field 'date' exists.
    // Existing app structure usually uses 'YYYY-MM-DD' as doc ID for easy lookup, or auto-id with date field.
    // Let's assume field 'date' (Timestamp) exists or we parse ID.
    // Plan mentions: Sub-collection: `completions/{completionId}` (Existing `ReadingCompletion`)
    // I need to know the schema of ReadingCompletion.
    // Usually it has a 'date' field.

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final val = data['date'];
          if (val is Timestamp) return val.toDate();
          if (val is String) {
            try {
              return DateTime.parse(val);
            } catch (_) {}
          }
          return null; // Will be filtered out
        })
        .whereType<DateTime>()
        .toList();
  }

  // Toggle reading status
  Future<void> toggleReading(String uid, DateTime date) async {
    try {
      final schedule = await getSchedule(date.year);
      if (schedule == null) {
        debugPrint("Toggle failed: No schedule for ${date.year}");
        return;
      }

      final pos = DateHelper.getReadingPosition(date, schedule);
      if (pos == null) {
        debugPrint("Toggle failed: Not a reading position for $date");
        return;
      }

      final docId = pos.docId;
      final userDocRef = _db.collection('users').doc(uid);
      final completionRef = userDocRef.collection('completions').doc(docId);
      final statsRef = userDocRef.collection('stats').doc('summary');

      // Sequential updates instead of runTransaction to avoid native abort() crash on Windows
      final compSnap = await completionRef.get();
      final statsSnap = await statsRef.get();

      final bool isToday = DateHelper.isSameDay(date, DateTime.now());

      if (compSnap.exists) {
        // Deleting
        await completionRef.delete();
        if (statsSnap.exists) {
          final statsData = statsSnap.data() ?? {};
          int count = (statsData['total_days_completed'] as num? ?? 1).toInt();

          // Find the most recent completion date after deletion
          final remainingCompletions = await _db
              .collection('users')
              .doc(uid)
              .collection('completions')
              .orderBy('date', descending: true)
              .limit(1)
              .get();

          final updates = {
            'total_days_completed': (count - 1).clamp(0, 9999),
            'updatedAt': DateTime.now().toIso8601String(),
          };

          if (remainingCompletions.docs.isNotEmpty) {
            // Update to the most recent remaining completion date
            final mostRecentDate =
                remainingCompletions.docs.first.data()['date'] as String?;
            if (mostRecentDate != null) {
              updates['last_completed_date'] = mostRecentDate;
            }
          } else {
            // No completions left, remove the field
            updates['last_completed_date'] = FieldValue.delete();
          }

          // Recalculate streak from remaining completions
          if (isToday && remainingCompletions.docs.isNotEmpty) {
            // Get schedule for proper date calculations
            final schedule = await getSchedule(date.year);
            if (schedule != null) {
              final streak = await _calculateStreakFromCompletions(
                uid,
                schedule,
              );
              updates['streak_current'] = streak;
            } else {
              updates['streak_current'] = 0;
            }
          } else if (isToday) {
            updates['streak_current'] = 0;
          }
          await statsRef.update(updates);
        }
      } else {
        // Creating
        await completionRef.set({
          'year': pos.year,
          'week': pos.week,
          'day': pos.day,
          'date': DateTime(date.year, date.month, date.day).toIso8601String(),
          'readings': [], // Fallback for admin app
          'createdAt': DateTime.now().toIso8601String(),
        });

        if (statsSnap.exists) {
          final statsData = statsSnap.data() ?? {};
          int count = (statsData['total_days_completed'] as num? ?? 0).toInt();
          final updates = {
            'total_days_completed': count + 1,
            'last_completed_date': date.toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
          // Calculate streak: check if yesterday was also completed
          if (isToday) {
            final schedule = await getSchedule(date.year);
            if (schedule != null) {
              final yesterday = await _getYesterdayReadingDate(date, schedule);

              if (yesterday != null) {
                final yesterdayPos = DateHelper.getReadingPosition(
                  yesterday,
                  schedule,
                );
                if (yesterdayPos != null) {
                  final yesterdayDoc = await userDocRef
                      .collection('completions')
                      .doc(yesterdayPos.docId)
                      .get();

                  if (yesterdayDoc.exists) {
                    // Yesterday was completed, increment streak
                    final currentStreak =
                        (statsData['streak_current'] as num? ?? 0).toInt();
                    updates['streak_current'] = currentStreak + 1;
                  } else {
                    // Yesterday was not completed, reset to 1
                    updates['streak_current'] = 1;
                  }
                } else {
                  updates['streak_current'] = 1;
                }
              } else {
                // No valid yesterday (e.g., first day of schedule), set to 1
                updates['streak_current'] = 1;
              }
            } else {
              updates['streak_current'] = 1;
            }
          }
          await statsRef.update(updates);
        } else {
          final data = {
            'total_days_completed': 1,
            'last_completed_date': date.toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
          if (isToday) data['streak_current'] = 1;
          await statsRef.set(data);
        }
      }
    } catch (e, stack) {
      debugPrint("Toggle Error abort prevention: $e");
      debugPrint(stack.toString());
    }
  }

  // Fetch and cache schedule
  final Map<String, ReadingSchedule> _scheduleCache = {};
  Future<ReadingSchedule?> getSchedule(int year) async {
    if (year < 2020 || year > 2100) return null;
    final yearStr = year.toString();
    if (_scheduleCache.containsKey(yearStr)) return _scheduleCache[yearStr];
    try {
      final doc = await _db
          .collection('config')
          .doc('schedule')
          .collection('years')
          .doc(yearStr)
          .get();
      if (doc.exists) {
        final s = ReadingSchedule.fromFirestore(doc);
        _scheduleCache[yearStr] = s;
        return s;
      }
    } catch (e) {
      debugPrint("Error fetching schedule for $year: $e");
    }
    return null;
  }

  // Recalculate summary stats based on all completions
  Future<void> recalculateUserStats(String uid) async {
    try {
      final userDocRef = _db.collection('users').doc(uid);
      final completionsSnap = await userDocRef.collection('completions').get();
      final statsRef = userDocRef.collection('stats').doc('summary');

      if (completionsSnap.docs.isEmpty) {
        await statsRef.set({
          'total_days_completed': 0,
          'streak_current': 0,
          'streak_max': 0,
          'last_completed_date': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      // 1. Parse and sort all completion dates safely
      List<DateTime> dates = [];
      for (var doc in completionsSnap.docs) {
        final data = doc.data();
        final val = data['date'];
        DateTime? parsed;
        if (val is String) {
          parsed = DateTime.tryParse(val);
        } else if (val is Timestamp) {
          parsed = val.toDate();
        }
        if (parsed != null) dates.add(parsed);
      }

      if (dates.isEmpty) return;
      dates.sort((a, b) => a.compareTo(b));

      // 2. Map dates to indices with safety
      List<int> indices = [];
      for (var date in dates) {
        final schedule = await getSchedule(date.year);
        if (schedule != null) {
          int idx = DateHelper.getReadingIndex(date, schedule);
          if (idx >= 0) indices.add(idx);
        }
      }
      indices = indices.toSet().toList(); // De-duplicate
      indices.sort();

      // 3. Calculate Streaks and Total
      int totalDays = indices.length;
      int maxStreak = 0;
      int currentStreak = 0;

      if (indices.isNotEmpty) {
        int tempStreak = 1;
        maxStreak = 1;
        for (int i = 1; i < indices.length; i++) {
          if (indices[i] == indices[i - 1] + 1) {
            tempStreak++;
          } else {
            if (tempStreak > maxStreak) maxStreak = tempStreak;
            tempStreak = 1;
          }
        }
        if (tempStreak > maxStreak) maxStreak = tempStreak;

        final now = DateTime.now();
        final currentSchedule = await getSchedule(now.year);
        if (currentSchedule != null) {
          int todayIdx = DateHelper.getReadingIndex(now, currentSchedule);
          int lastIdx = indices.last;

          if (lastIdx == todayIdx || lastIdx == todayIdx - 1) {
            int tailStreak = 1;
            for (int i = indices.length - 2; i >= 0; i--) {
              if (indices[i] == indices[i + 1] - 1) {
                tailStreak++;
              } else {
                break;
              }
            }
            currentStreak = tailStreak;
          }
        }
      }

      // 4. Update Stats safely
      final latestDateStr = dates.last.toIso8601String();
      await statsRef.set({
        'total_days_completed': totalDays,
        'streak_current': currentStreak,
        'streak_max': maxStreak,
        'last_completed_date': latestDateStr,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, stack) {
      debugPrint("EXTREME ERROR in recalculateUserStats: $e");
      debugPrint(stack.toString());
    }
  }

  /// Get the previous valid reading date (skipping Sundays and holidays)
  Future<DateTime?> _getYesterdayReadingDate(
    DateTime date,
    ReadingSchedule schedule,
  ) async {
    DateTime current = date.subtract(const Duration(days: 1));
    final startDate = schedule.startDate;

    if (startDate == null) return null;

    // Go back up to 7 days to find the previous reading day
    for (int i = 0; i < 7; i++) {
      if (current.isBefore(startDate)) return null;

      // Check if it's a valid reading day (Mon-Sat, not holiday)
      bool isReadingDay =
          current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.saturday;

      if (isReadingDay) {
        bool isHoliday = false;
        for (final holiday in schedule.holidays) {
          if ((current.isAfter(holiday.start) ||
                  DateHelper.isSameDay(current, holiday.start)) &&
              (current.isBefore(holiday.end) ||
                  DateHelper.isSameDay(current, holiday.end))) {
            isHoliday = true;
            break;
          }
        }

        if (!isHoliday) {
          return current;
        }
      }

      current = current.subtract(const Duration(days: 1));
    }

    return null;
  }

  /// Calculate current streak from all completion records
  Future<int> _calculateStreakFromCompletions(
    String uid,
    ReadingSchedule schedule,
  ) async {
    try {
      // Get all completions ordered by date descending
      final completionsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('completions')
          .orderBy('date', descending: true)
          .get();

      if (completionsSnap.docs.isEmpty) return 0;

      // Convert to DateTime list and get indices
      List<DateTime> dates = [];
      for (var doc in completionsSnap.docs) {
        final dateStr = doc.data()['date'] as String?;
        if (dateStr != null) {
          dates.add(DateTime.parse(dateStr));
        }
      }

      if (dates.isEmpty) return 0;

      // Get reading indices for all dates
      List<int> indices = [];
      for (var date in dates) {
        int idx = DateHelper.getReadingIndex(date, schedule);
        if (idx >= 0) indices.add(idx);
      }

      if (indices.isEmpty) return 0;

      indices = indices.toSet().toList();
      indices.sort();

      // Calculate current streak (from the end)
      final now = DateTime.now();
      int todayIdx = DateHelper.getReadingIndex(now, schedule);
      int lastIdx = indices.last;

      // Current streak only counts if the last completion is today or yesterday
      if (lastIdx != todayIdx && lastIdx != todayIdx - 1) {
        return 0;
      }

      int currentStreak = 1;
      for (int i = indices.length - 2; i >= 0; i--) {
        if (indices[i] == indices[i + 1] - 1) {
          currentStreak++;
        } else {
          break;
        }
      }

      return currentStreak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }
}
