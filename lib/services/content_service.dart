import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/content.dart';

class ContentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _contentRef => _db.collection('contents');

  // Get Stream of Contents ordered by 'order'
  Stream<List<Content>> getContentStream() {
    return _contentRef.orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Content.fromFirestore(doc)).toList();
    });
  }

  // Add Content
  Future<void> addContent(Content content) async {
    // ID is auto-generated if empty, but model expects ID.
    // We'll let firestore generate ID then set it.
    final doc = _contentRef.doc();
    final newContent = Content(
      id: doc.id,
      type: content.type,
      title: content.title,
      url: content.url,
      isVisible: content.isVisible,
      order: content.order,
      createdAt: DateTime.now(),
    );
    await doc.set(newContent.toMap());
  }

  // Update Content
  Future<void> updateContent(Content content) async {
    await _contentRef.doc(content.id).update(content.toMap());
  }

  // Delete Content
  Future<void> deleteContent(String id) async {
    await _contentRef.doc(id).delete();
  }
}
