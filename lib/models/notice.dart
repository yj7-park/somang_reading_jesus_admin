import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String id;
  final String title;
  final String body;
  final bool isVisible;
  final bool sentPush;
  final DateTime? createdAt;

  Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.isVisible,
    required this.sentPush,
    this.createdAt,
  });

  factory Notice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Notice(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      isVisible: data['isVisible'] ?? true,
      sentPush: data['sentPush'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'isVisible': isVisible,
      'sentPush': sentPush,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
