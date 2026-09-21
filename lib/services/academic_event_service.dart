import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/academic_event.dart';

class AcademicEventService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<List<AcademicEvent>> getEventsForLesson({
    required String groupId,
    required String lessonId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
            .collection('academicEvents')
            .where(
              'groupId',
              isEqualTo: groupId,
            )
            .where(
              'lessonId',
              isEqualTo: lessonId,
            )
            .get();

    final List<AcademicEvent> events = snapshot.docs
        .map(
          (document) =>
              AcademicEvent.fromFirestore(document),
        )
        .toList();

    events.sort(
      (a, b) => a.date.compareTo(b.date),
    );

    return events;
  }
}