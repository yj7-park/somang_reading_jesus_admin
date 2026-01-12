import 'package:cloud_firestore/cloud_firestore.dart';

enum ContentType { image, youtube, unknown }

class Content {
  final String id;
  final ContentType type;
  final String title;
  final String url;
  final bool isVisible;
  final int order;
  final DateTime? createdAt;

  Content({
    required this.id,
    required this.type,
    required this.title,
    required this.url,
    required this.isVisible,
    required this.order,
    this.createdAt,
  });

  factory Content.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String typeStr = data['type'] ?? '';
    ContentType parsedType = ContentType.unknown;
    if (typeStr == 'image') parsedType = ContentType.image;
    if (typeStr == 'youtube') parsedType = ContentType.youtube;

    return Content(
      id: doc.id,
      type: parsedType,
      title: data['title'] ?? '',
      url: data['url'] ?? '',
      isVisible: data['isVisible'] ?? true,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type == ContentType.image ? 'image' : 'youtube',
      'title': title,
      'url': url,
      'isVisible': isVisible,
      'order': order,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
