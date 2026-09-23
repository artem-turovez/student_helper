import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/academic_event.dart';

class AcademicEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AcademicEvent>> getEventsForLesson({
    required String groupId,
    required String lessonId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('academicEvents')
        .where('groupId', isEqualTo: groupId)
        .where('lessonId', isEqualTo: lessonId)
        .get();

    final List<AcademicEvent> events = snapshot.docs
        .map((document) => AcademicEvent.fromFirestore(document))
        .toList();

    events.sort((a, b) => a.date.compareTo(b.date));

    return events;
  }

  Future<List<AcademicEvent>> getEventsForMonth({
    required String groupId,
    required DateTime month,
  }) async {
    final DateTime startOfMonth = DateTime(month.year, month.month, 1);

    final DateTime startOfNextMonth = DateTime(month.year, month.month + 1, 1);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('academicEvents')
        .where('groupId', isEqualTo: groupId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(startOfNextMonth))
        .get();

    final List<AcademicEvent> events = snapshot.docs
        .map((document) => AcademicEvent.fromFirestore(document))
        .toList();

    events.sort((a, b) => a.date.compareTo(b.date));

    return events;
  }

  Future<List<AcademicEvent>> getTeacherEventsForMonth({
    required String teacherId,
    required DateTime month,
  }) async {
    final String normalizedTeacherId = teacherId.trim();

    if (normalizedTeacherId.isEmpty) {
      return [];
    }

    final DateTime startOfMonth = DateTime(month.year, month.month, 1);

    final DateTime startOfNextMonth = DateTime(month.year, month.month + 1, 1);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('academicEvents')
        .where('teacherId', isEqualTo: normalizedTeacherId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(startOfNextMonth))
        .get();

    final List<AcademicEvent> events = snapshot.docs
        .map((document) => AcademicEvent.fromFirestore(document))
        .toList();

    events.sort((a, b) => a.date.compareTo(b.date));

    return events;
  }
}
