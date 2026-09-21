import 'package:cloud_firestore/cloud_firestore.dart';

class Lesson {
  final String? id;

  final int number;
  final String time;
  final String subject;

  /// ФИО преподавателей.
  ///
  /// Поле сохраняем для отображения и совместимости
  /// с уже существующими документами Firestore.
  final List<String> teachers;

  /// ID преподавателей из коллекции teachers.
  ///
  /// Например:
  /// [
  ///   "teacher_test_1",
  ///   "teacher_test_2",
  /// ]
  final List<String> teacherIds;

  final List<String> rooms;

  final String type;

  final DateTime? date;

  final String? groupId;
  final String? subgroup;

  const Lesson({
    this.id,
    required this.number,
    required this.time,
    required this.subject,
    required this.teachers,
    this.teacherIds = const [],
    required this.rooms,
    required this.type,
    this.date,
    this.groupId,
    this.subgroup,
  });

  String get teacher {
    if (teachers.isEmpty) {
      return 'Преподаватель не указан';
    }

    return teachers.join(', ');
  }

  String get room {
    if (rooms.isEmpty) {
      return 'Аудитория не указана';
    }

    return rooms.join(', ');
  }

  bool get hasLinkedTeachers {
    return teacherIds.isNotEmpty;
  }

  factory Lesson.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data =
        document.data();

    if (data == null) {
      throw Exception(
        'Документ занятия ${document.id} '
        'не содержит данных',
      );
    }

    final Timestamp? timestamp =
        data['date'] as Timestamp?;

    return Lesson(
      id: document.id,
      number: data['number'] as int? ?? 0,
      time: data['time']?.toString() ?? '',
      subject:
          data['subject']?.toString() ?? '',
      teachers: List<String>.from(
        data['teachers'] ?? const [],
      ),
      teacherIds: List<String>.from(
        data['teacherIds'] ?? const [],
      ),
      rooms: List<String>.from(
        data['rooms'] ?? const [],
      ),
      type: data['type']?.toString() ?? '',
      date: timestamp?.toDate(),
      groupId:
          data['groupId']?.toString(),
      subgroup:
          data['subgroup']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'number': number,
      'time': time,
      'subject': subject,
      'teachers': teachers,
      'teacherIds': teacherIds,
      'rooms': rooms,
      'type': type,
      'date': date == null
          ? null
          : Timestamp.fromDate(date!),
      'groupId': groupId,
      'subgroup': subgroup,
    };
  }
}