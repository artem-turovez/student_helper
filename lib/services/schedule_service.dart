import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lesson.dart';

class ScheduleService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<List<Lesson>> getLessonsForDay({
    required String groupId,
    required DateTime date,
  }) async {
    final DateTime startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final DateTime endOfDay = startOfDay.add(
      const Duration(days: 1),
    );

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _firestore
            .collection('lessons')
            .where(
              'groupId',
              isEqualTo: groupId,
            )
            .where(
              'date',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(startOfDay),
            )
            .where(
              'date',
              isLessThan:
                  Timestamp.fromDate(endOfDay),
            )
            .get();

    final List<Lesson> lessons = snapshot.docs
        .map(
          (document) =>
              Lesson.fromFirestore(document),
        )
        .toList();

    lessons.sort(
      (a, b) => a.number.compareTo(b.number),
    );

    return lessons;
  }

  Future<List<Lesson>> getLessonsForTeacher({
    required String teacherId,
  }) async {
    if (teacherId.trim().isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _firestore
            .collection('lessons')
            .where(
              'teacherIds',
              arrayContains: teacherId,
            )
            .get();

    final List<Lesson> lessons = snapshot.docs
        .map(
          (document) =>
              Lesson.fromFirestore(document),
        )
        .toList();

    lessons.sort(_compareLessons);

    return lessons;
  }

  Future<List<Lesson>>
      getTeacherLessonsForDay({
    required String teacherId,
    required DateTime date,
  }) async {
    if (teacherId.trim().isEmpty) {
      return [];
    }

    final List<Lesson> lessons =
        await getLessonsForTeacher(
      teacherId: teacherId,
    );

    return lessons.where(
      (lesson) {
        final DateTime? lessonDate =
            lesson.date;

        if (lessonDate == null) {
          return false;
        }

        return lessonDate.year == date.year &&
            lessonDate.month == date.month &&
            lessonDate.day == date.day;
      },
    ).toList();
  }

  int _compareLessons(
    Lesson first,
    Lesson second,
  ) {
    final DateTime? firstDate =
        first.date;

    final DateTime? secondDate =
        second.date;

    if (firstDate == null &&
        secondDate == null) {
      return first.number.compareTo(
        second.number,
      );
    }

    if (firstDate == null) {
      return 1;
    }

    if (secondDate == null) {
      return -1;
    }

    final int dateComparison =
        firstDate.compareTo(secondDate);

    if (dateComparison != 0) {
      return dateComparison;
    }

    return first.number.compareTo(
      second.number,
    );
  }
}