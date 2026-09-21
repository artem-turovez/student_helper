import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalEvent {
  final String? id;

  final String userId;
  final String title;
  final String description;

  final DateTime date;
  final DateTime? createdAt;

  final bool isCompleted;

  const PersonalEvent({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.date,
    this.createdAt,
    this.isCompleted = false,
  });

  factory PersonalEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw Exception(
        'Документ личного события ${document.id} не содержит данных',
      );
    }

    final Timestamp? dateTimestamp =
        data['date'] as Timestamp?;

    if (dateTimestamp == null) {
      throw Exception(
        'У личного события ${document.id} не указана дата',
      );
    }

    final Timestamp? createdAtTimestamp =
        data['createdAt'] as Timestamp?;

    return PersonalEvent(
      id: document.id,
      userId: data['userId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description:
          data['description']?.toString() ?? '',
      date: dateTimestamp.toDate(),
      createdAt: createdAtTimestamp?.toDate(),

      // Для старых событий, где этого поля ещё нет,
      // автоматически считаем событие невыполненным.
      isCompleted:
          data['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'isCompleted': isCompleted,
    };
  }
}