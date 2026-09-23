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

  Future<String> createAcademicEvent({
    required String groupId,
    required String lessonId,
    required String teacherId,
    required String subject,
    required String type,
    required String title,
    required String description,
    required DateTime date,
  }) async {
    final AcademicEvent event = _buildEvent(
      groupId: groupId,
      lessonId: lessonId,
      teacherId: teacherId,
      subject: subject,
      type: type,
      title: title,
      description: description,
      date: date,
    );

    final DocumentReference<Map<String, dynamic>> document = await _firestore
        .collection('academicEvents')
        .add(event.toFirestore());

    return document.id;
  }

  Future<void> updateAcademicEvent({
    required String eventId,
    required String groupId,
    required String lessonId,
    required String teacherId,
    required String subject,
    required String type,
    required String title,
    required String description,
    required DateTime date,
  }) async {
    final String normalizedEventId = eventId.trim();

    if (normalizedEventId.isEmpty) {
      throw ArgumentError('Не указано учебное событие');
    }

    final AcademicEvent event = _buildEvent(
      groupId: groupId,
      lessonId: lessonId,
      teacherId: teacherId,
      subject: subject,
      type: type,
      title: title,
      description: description,
      date: date,
    );

    await _firestore
        .collection('academicEvents')
        .doc(normalizedEventId)
        .update(event.toFirestore());
  }

  Future<void> deleteAcademicEvent({required String eventId}) async {
    final String normalizedEventId = eventId.trim();

    if (normalizedEventId.isEmpty) {
      throw ArgumentError('Не указано учебное событие');
    }

    await _firestore
        .collection('academicEvents')
        .doc(normalizedEventId)
        .delete();
  }

  AcademicEvent _buildEvent({
    required String groupId,
    required String lessonId,
    required String teacherId,
    required String subject,
    required String type,
    required String title,
    required String description,
    required DateTime date,
  }) {
    final String normalizedGroupId = groupId.trim();
    final String normalizedLessonId = lessonId.trim();
    final String normalizedTeacherId = teacherId.trim();
    final String normalizedSubject = subject.trim();
    final String normalizedType = type.trim();
    final String normalizedTitle = title.trim();
    final String normalizedDescription = description.trim();

    if (normalizedGroupId.isEmpty) {
      throw ArgumentError('Не указана учебная группа');
    }

    if (normalizedLessonId.isEmpty) {
      throw ArgumentError('Не указано занятие');
    }

    if (normalizedTeacherId.isEmpty) {
      throw ArgumentError('Не указан преподаватель');
    }

    if (normalizedSubject.isEmpty) {
      throw ArgumentError('Не указан предмет');
    }

    if (normalizedType.isEmpty) {
      throw ArgumentError('Не указан тип учебного события');
    }

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Не указано название учебного события');
    }

    return AcademicEvent(
      groupId: normalizedGroupId,
      lessonId: normalizedLessonId,
      teacherId: normalizedTeacherId,
      subject: normalizedSubject,
      type: normalizedType,
      title: normalizedTitle,
      description: normalizedDescription,
      date: DateTime(date.year, date.month, date.day),
    );
  }
}
