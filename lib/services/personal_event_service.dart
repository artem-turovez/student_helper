import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/personal_event.dart';

class PersonalEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<PersonalEvent>> getEventsForMonth({
    required String userId,
    required DateTime month,
  }) async {
    final DateTime startOfMonth = DateTime(month.year, month.month, 1);

    final DateTime startOfNextMonth = DateTime(month.year, month.month + 1, 1);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('personalEvents')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(startOfNextMonth))
        .get();

    final List<PersonalEvent> events = snapshot.docs
        .map((document) => PersonalEvent.fromFirestore(document))
        .toList();

    events.sort((a, b) => a.date.compareTo(b.date));

    return events;
  }

  Future<String> createEvent({required PersonalEvent event}) async {
    final DocumentReference<Map<String, dynamic>> document = await _firestore
        .collection('personalEvents')
        .add(event.toFirestore());

    return document.id;
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime date,
    required int? reminderMinutesBefore,
  }) async {
    await _firestore.collection('personalEvents').doc(eventId).update({
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'reminderMinutesBefore': reminderMinutesBefore,
    });
  }

  Future<void> setCompleted({
    required String eventId,
    required bool isCompleted,
  }) async {
    await _firestore.collection('personalEvents').doc(eventId).update({
      'isCompleted': isCompleted,
    });
  }

  Future<void> deleteEvent({required String eventId}) async {
    await _firestore.collection('personalEvents').doc(eventId).delete();
  }
}
