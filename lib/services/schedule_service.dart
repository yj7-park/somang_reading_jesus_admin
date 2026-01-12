import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reading_schedule.dart';

class ScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _yearsRef =>
      _db.collection('config').doc('schedule').collection('years');

  // Fetch schedule for a specific year
  Stream<ReadingSchedule?> getScheduleStream(String year) {
    return _yearsRef.doc(year).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ReadingSchedule.fromFirestore(doc);
    });
  }

  // Get available years (document IDs)
  Future<List<String>> getAvailableYears() async {
    final snapshot = await _yearsRef.get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Create or Update a schedule
  Future<void> saveSchedule(ReadingSchedule schedule) async {
    await _yearsRef.doc(schedule.year).set(schedule.toMap());
  }

  // Add a holiday range
  Future<void> addHoliday(String year, DateTime start, DateTime end) async {
    final docRef = _yearsRef.doc(year);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Create if doesn't exist (assuming start date is Jan 1st by default for now)
      await docRef.set({
        'startDate': Timestamp.fromDate(DateTime(int.parse(year), 1, 1)),
        'holidays': [
          {'start': Timestamp.fromDate(start), 'end': Timestamp.fromDate(end)},
        ],
      });
    } else {
      await docRef.update({
        'holidays': FieldValue.arrayUnion([
          {'start': Timestamp.fromDate(start), 'end': Timestamp.fromDate(end)},
        ]),
      });
    }
  }
}
