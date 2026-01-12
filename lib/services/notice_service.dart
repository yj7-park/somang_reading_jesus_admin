import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notice.dart';

class NoticeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _noticeRef => _db.collection('notices');

  // Stream of Notices descending by createdAt
  Stream<List<Notice>> getNoticeStream() {
    return _noticeRef.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => Notice.fromFirestore(doc)).toList();
    });
  }

  // Add Notice
  Future<void> addNotice(Notice notice) async {
    final doc = _noticeRef.doc();
    final newNotice = Notice(
      id: doc.id,
      title: notice.title,
      body: notice.body,
      isVisible: notice.isVisible,
      sentPush: false, // Default false until requested
      createdAt: DateTime.now(),
    );
    await doc.set(newNotice.toMap());
  }

  // Update Notice
  Future<void> updateNotice(Notice notice) async {
    await _noticeRef.doc(notice.id).update(notice.toMap());
  }

  // Delete Notice
  Future<void> deleteNotice(String id) async {
    await _noticeRef.doc(id).delete();
  }
}
