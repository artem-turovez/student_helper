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

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
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
}