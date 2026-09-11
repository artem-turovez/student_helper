class Lesson {
  final int number;
  final String time;
  final String subject;

  final List<String> teachers;
  final List<String> rooms;

  final String type;

  final DateTime? date;

  final String? groupId;
  final String? subgroup;

  const Lesson({
    required this.number,
    required this.time,
    required this.subject,
    required this.teachers,
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
}