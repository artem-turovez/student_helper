import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicEvent {
  final String? id;

  final String groupId;
  final String? lessonId;
  final String? teacherId;

  final String type;
  final String title;
  final String description;

  final DateTime date;

  const AcademicEvent({
    this.id,
    required this.groupId,
    this.lessonId,
    this.teacherId,
    required this.type,
    required this.title,
    required this.description,
    required this.date,
  });

  factory AcademicEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw Exception(
        'Документ учебного события ${document.id} не содержит данных',
      );
    }

    final Timestamp? timestamp =
        data['date'] as Timestamp?;

    if (timestamp == null) {
      throw Exception(
        'У учебного события ${document.id} не указана дата',
      );
    }

    return AcademicEvent(
      id: document.id,
      groupId: data['groupId']?.toString() ?? '',
      lessonId: data['lessonId']?.toString(),
      teacherId: data['teacherId']?.toString(),
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      date: timestamp.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'lessonId': lessonId,
      'teacherId': teacherId,
      'type': type,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
    };
  }
}