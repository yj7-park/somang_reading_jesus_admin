import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/user_profile.dart';
import '../models/church_roster.dart';
import '../models/reading_schedule.dart';
import '../utils/date_helper.dart';

class UserAndRosterService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Collection Accessors ---
  CollectionReference get _usersRef => _db.collection('users');
  CollectionReference get _rosterRef => _db.collection('church_roster');

  // --- User Profile Operations ---

  // Get all users (Stream) - Warning: Potentially large data set
  // Ideally, use pagination. For admin v1, we used a stream but maybe we limit?
  // Let's implement simple pagination or getting latest.
  Query getLatestUsersQuery() {
    return _usersRef.orderBy('createdAt', descending: true).limit(50);
  }

  // Update User Profile
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _usersRef.doc(uid).update(data);
  }

  // Search User by Name or Phone (Exact match for now as Firestore search is limited)
  Future<List<UserProfile>> searchUsers(String term) async {
    // Try name
    final byName = await _usersRef.where('name', isEqualTo: term).get();
    if (byName.docs.isNotEmpty) {
      return byName.docs.map((d) => UserProfile.fromFirestore(d)).toList();
    }

    // Try phone
    final byPhone = await _usersRef.where('phoneNumber', isEqualTo: term).get();
    if (byPhone.docs.isNotEmpty) {
      return byPhone.docs.map((d) => UserProfile.fromFirestore(d)).toList();
    }

    return [];
  }

  // --- Church Roster Operations ---

  // Add to Roster
  Future<void> addToRoster(ChurchRoster roster) async {
    // Phone number is ID
    await _rosterRef.doc(roster.phoneNumber).set(roster.toMap());
  }

  // Get Roster Query
  Query getRosterQuery() {
    return _rosterRef.orderBy('name').limit(50);
  }

  // Search Roster
  Future<List<ChurchRoster>> searchRoster(String term) async {
    // Try name
    final byName = await _rosterRef.where('name', isEqualTo: term).get();
    if (byName.docs.isNotEmpty) {
      return byName.docs.map((d) => ChurchRoster.fromFirestore(d)).toList();
    }
    return [];
  }

  // Delete from Roster/Update (if needed)
  Future<void> deleteFromRoster(String phoneNumber) async {
    await _rosterRef.doc(phoneNumber).delete();
  }

  // --- Real-time Stream Support ---

  Stream<Map<String, dynamic>> getCombinedUserRosterStream() {
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

      // 3. Combine
      return CombineLatestStream.combine3(
        _usersRef.snapshots(),
        _rosterRef.snapshots(),
        _db.collectionGroup('stats').snapshots(),
        (usersSnap, rosterSnap, statsSnap) {
          final users = usersSnap.docs
              .map((d) => UserProfile.fromFirestore(d))
              .toList();
          final roster = rosterSnap.docs
              .map((d) => ChurchRoster.fromFirestore(d))
              .toList();

          Map<String, Map<String, dynamic>> statsMap = {};
          Set<String> todayCompletedUids = {};

          for (var doc in statsSnap.docs) {
            final parentDoc = doc.reference.parent.parent;
            if (parentDoc != null) {
              final uid = parentDoc.id;
              final data = doc.data();
              statsMap[uid] = data;

              final completed = (data['total_days_completed'] as num? ?? 0)
                  .toInt();
              if (targetIndex > 0 && completed >= targetIndex) {
                todayCompletedUids.add(uid);
              }
            }
          }

          return {
            'users': users,
            'roster': roster,
            'todayCompletedUids': todayCompletedUids,
            'stats': statsMap,
            'targetIndex': targetIndex,
          };
        },
      );
    });
  }
}
