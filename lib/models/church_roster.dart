import 'package:cloud_firestore/cloud_firestore.dart';

class ChurchRoster {
  final String phoneNumber; // Document ID is usually the phone number
  final String name;
  final String birthDate;
  final DateTime? createdAt;

  ChurchRoster({
    required this.phoneNumber,
    required this.name,
    required this.birthDate,
    this.createdAt,
  });

  factory ChurchRoster.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String parseBirthDate(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is Timestamp) {
        final date = value.toDate();
        return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }
      return value.toString();
    }

    return ChurchRoster(
      phoneNumber: doc.id,
      name: data['name'] ?? '',
      birthDate: parseBirthDate(data['birthDate']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'birthDate': birthDate,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
