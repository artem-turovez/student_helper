import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalEvent {
  final String? id;

  final String userId;
  final String title;
  final String description;

  final DateTime date;
  final DateTime? createdAt;

  final bool isCompleted;

  /// За сколько минут до события показать уведомление.
  ///
  /// null — напоминание выключено.
  /// 0 — в момент события.
  /// 5 — за 5 минут.
  /// 15 — за 15 минут.
  /// 30 — за 30 минут.
  /// 60 — за 1 час.
  /// 1440 — за 1 день.
  final int? reminderMinutesBefore;

  const PersonalEvent({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.date,
    this.createdAt,
    this.isCompleted = false,
    this.reminderMinutesBefore,
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

    final Timestamp? dateTimestamp = data['date'] as Timestamp?;

    if (dateTimestamp == null) {
      throw Exception('У личного события ${document.id} не указана дата');
    }

    final Timestamp? createdAtTimestamp = data['createdAt'] as Timestamp?;

    final Object? reminderValue = data['reminderMinutesBefore'];

    int? reminderMinutesBefore;

    if (reminderValue is int) {
      reminderMinutesBefore = reminderValue;
    } else if (reminderValue is num) {
      reminderMinutesBefore = reminderValue.toInt();
    }

    return PersonalEvent(
      id: document.id,
      userId: data['userId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      date: dateTimestamp.toDate(),
      createdAt: createdAtTimestamp?.toDate(),

      // Старые события этого поля не имеют.
      isCompleted: data['isCompleted'] as bool? ?? false,

      // Для старых событий автоматически будет null,
      // то есть напоминание выключено.
      reminderMinutesBefore: reminderMinutesBefore,
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
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }
}
