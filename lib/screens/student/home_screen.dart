import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/academic_event.dart';
import '../../models/lesson.dart';
import '../../services/academic_event_service.dart';
import '../../services/schedule_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final AcademicEventService _academicEventService = AcademicEventService();

  late Future<_HomeData> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final DocumentSnapshot<Map<String, dynamic>> document =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final Map<String, dynamic>? userData = document.data();

    if (userData == null) {
      throw Exception('Профиль пользователя не найден');
    }

    final String fullName = userData['name']?.toString().trim() ?? 'Студент';

    final String? rawGroupId = userData['groupId']?.toString();
    final String? groupId = rawGroupId == null || rawGroupId.trim().isEmpty
        ? null
        : rawGroupId.trim();

    if (groupId == null) {
      return _HomeData(
        fullName: fullName,
        groupId: null,
        nextLesson: null,
        upcomingEvents: const [],
      );
    }

    final Future<Lesson?> nextLessonFuture = _findNextLesson(groupId);

    final Future<List<AcademicEvent>> eventsFuture = _loadUpcomingEvents(
      groupId,
    );

    final List<dynamic> results = await Future.wait<dynamic>([
      nextLessonFuture,
      eventsFuture,
    ]);

    return _HomeData(
      fullName: fullName,
      groupId: groupId,
      nextLesson: results[0] as Lesson?,
      upcomingEvents: results[1] as List<AcademicEvent>,
    );
  }

  Future<Lesson?> _findNextLesson(String groupId) async {
    final DateTime now = DateTime.now();

    // Для Beta ищем ближайшее занятие в пределах двух недель.
    // Этого достаточно, чтобы пережить выходные и короткие перерывы
    // в расписании.
    for (int offset = 0; offset < 14; offset++) {
      final DateTime date = DateTime(now.year, now.month, now.day + offset);

      final List<Lesson> lessons = await _scheduleService.getLessonsForDay(
        groupId: groupId,
        date: date,
      );

      if (lessons.isEmpty) {
        continue;
      }

      if (offset > 0) {
        return lessons.first;
      }

      for (final Lesson lesson in lessons) {
        if (_isLessonStillUpcomingToday(lesson, now)) {
          return lesson;
        }
      }
    }

    return null;
  }

  bool _isLessonStillUpcomingToday(Lesson lesson, DateTime now) {
    final DateTime? lessonStart = _getLessonStart(lesson);

    // Если время невозможно разобрать, лучше показать занятие,
    // чем ошибочно скрыть его.
    if (lessonStart == null) {
      return true;
    }

    return lessonStart.isAfter(now) || lessonStart.isAtSameMomentAs(now);
  }

  DateTime? _getLessonStart(Lesson lesson) {
    final DateTime? lessonDate = lesson.date;

    if (lessonDate == null || lesson.time.trim().isEmpty) {
      return null;
    }

    // Поддерживает строки вроде:
    // "09:00 - 10:20"
    // "09:00–10:20"
    // "09:00"
    final RegExpMatch? match = RegExp(r'(\d{1,2}):(\d{2})')
        .firstMatch(lesson.time);

    if (match == null) {
      return null;
    }

    final int? hour = int.tryParse(match.group(1) ?? '');
    final int? minute = int.tryParse(match.group(2) ?? '');

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return DateTime(
      lessonDate.year,
      lessonDate.month,
      lessonDate.day,
      hour,
      minute,
    );
  }

  Future<List<AcademicEvent>> _loadUpcomingEvents(String groupId) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<AcademicEvent> currentMonth = await _academicEventService
        .getEventsForMonth(groupId: groupId, month: today);

    final DateTime nextMonth = DateTime(today.year, today.month + 1, 1);

    final List<AcademicEvent> nextMonthEvents = await _academicEventService
        .getEventsForMonth(groupId: groupId, month: nextMonth);

    final List<AcademicEvent> events = [...currentMonth, ...nextMonthEvents]
        .where((event) {
          final DateTime eventDay = DateTime(
            event.date.year,
            event.date.month,
            event.date.day,
          );

          return !eventDay.isBefore(today);
        })
        .toList();

    events.sort((first, second) => first.date.compareTo(second.date));

    return events.take(3).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _homeFuture = _loadHomeData();
    });

    await _homeFuture;
  }

  String _getGreeting() {
    final int hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Доброе утро';
    }

    if (hour >= 12 && hour < 18) {
      return 'Добрый день';
    }

    if (hour >= 18 && hour < 23) {
      return 'Добрый вечер';
    }

    return 'Доброй ночи';
  }

  String _getFirstName(String fullName) {
    final List<String> nameParts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (nameParts.length >= 2) {
      return nameParts[1];
    }

    if (nameParts.isNotEmpty) {
      return nameParts.first;
    }

    return 'Студент';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Дата не указана';
    }

    final List<String> months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime lessonDay = DateTime(date.year, date.month, date.day);

    if (lessonDay == today) {
      return 'Сегодня';
    }

    if (lessonDay == today.add(const Duration(days: 1))) {
      return 'Завтра';
    }

    return '${date.day} ${months[date.month - 1]}';
  }

  String _eventTypeName(String type) {
    switch (type.trim().toLowerCase()) {
      case 'test':
      case 'контрольная':
      case 'контрольная работа':
        return 'Контрольная';

      case 'exam':
      case 'экзамен':
        return 'Экзамен';

      case 'credit':
      case 'зачёт':
      case 'зачет':
        return 'Зачёт';

      case 'laboratory':
      case 'lab':
      case 'лабораторная':
      case 'лабораторная работа':
        return 'Лабораторная';

      case 'homework':
      case 'домашнее задание':
        return 'Домашнее задание';

      default:
        final String normalized = type.trim();

        if (normalized.isEmpty) {
          return 'Учебное событие';
        }

        return normalized;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_HomeData>(
        future: _homeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _HomeError(
              onRetry: () {
                setState(() {
                  _homeFuture = _loadHomeData();
                });
              },
            );
          }

          final _HomeData data = snapshot.data!;
          final String firstName = _getFirstName(data.fullName);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                24,
                AppTheme.screenPadding,
                32,
              ),
              children: [
                const Text('Главная', style: AppTheme.pageTitle),

                const SizedBox(height: 28),

                Text(
                  '${_getGreeting()}, $firstName!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  data.groupId == null
                      ? 'Учебная группа пока не назначена'
                      : 'Группа ${data.groupId}',
                  style: AppTheme.secondaryBodyText,
                ),

                if (data.groupId == null) ...[
                  const SizedBox(height: 24),
                  const _HomeMessage(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'Ожидается назначение группы',
                    description: 'После того как администратор назначит учебную группу, здесь появятся расписание и учебные события.',
                  ),
                ] else ...[
                  const SizedBox(height: 30),

                  const Text('Следующее занятие', style: AppTheme.sectionTitle),

                  const SizedBox(height: 12),

                  if (data.nextLesson == null)
                    const _HomeMessage(
                      icon: Icons.calendar_today_outlined,
                      title: 'Ближайших занятий нет',
                      description: 'В загруженном расписании на ближайшие дни занятий не найдено.',
                    )
                  else
                    _NextLessonCard(
                      lesson: data.nextLesson!,
                      dateText: _formatDate(data.nextLesson!.date),
                    ),

                  const SizedBox(height: 28),

                  const Text('Ближайшие события', style: AppTheme.sectionTitle),

                  const SizedBox(height: 12),

                  if (data.upcomingEvents.isEmpty)
                    const _HomeMessage(
                      icon: Icons.event_note_outlined,
                      title: 'Событий пока нет',
                      description: 'Ближайших учебных событий пока нет.',
                    )
                  else
                    ...data.upcomingEvents.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final AcademicEvent event = entry.value;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == data.upcomingEvents.length - 1
                              ? 0
                              : 10,
                        ),
                        child: _AcademicEventCard(
                          event: event,
                          dateText: _formatDate(event.date),
                          typeText: _eventTypeName(event.type),
                        ),
                      );
                    }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  final String fullName;
  final String? groupId;
  final Lesson? nextLesson;
  final List<AcademicEvent> upcomingEvents;

  const _HomeData({
    required this.fullName,
    required this.groupId,
    required this.nextLesson,
    required this.upcomingEvents,
  });
}

class _NextLessonCard extends StatelessWidget {
  final Lesson lesson;
  final String dateText;

  const _NextLessonCard({required this.lesson, required this.dateText});

  @override
  Widget build(BuildContext context) {
    final String lessonType = lesson.type.trim();
    final String subgroup = lesson.subgroup?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                ),
                child: Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),

              const Spacer(),

              Text('${lesson.number} пара', style: AppTheme.labelText),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            lesson.subject.trim().isEmpty
                ? 'Предмет не указан'
                : lesson.subject,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),

          if (lessonType.isNotEmpty || subgroup.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              [
                if (lessonType.isNotEmpty) lessonType,
                if (subgroup.isNotEmpty) 'Подгруппа $subgroup',
              ].join(' • '),
              style: AppTheme.secondaryBodyText,
            ),
          ],

          const SizedBox(height: 16),

          _LessonInfoRow(
            icon: Icons.schedule_outlined,
            text: lesson.time.trim().isEmpty ? 'Время не указано' : lesson.time,
          ),

          const SizedBox(height: 10),

          _LessonInfoRow(icon: Icons.meeting_room_outlined, text: lesson.room),

          const SizedBox(height: 10),

          _LessonInfoRow(icon: Icons.person_outline, text: lesson.teacher),
        ],
      ),
    );
  }
}

class _LessonInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LessonInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppTheme.secondaryText),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTheme.secondaryBodyText)),
      ],
    );
  }
}

class _AcademicEventCard extends StatelessWidget {
  final AcademicEvent event;
  final String dateText;
  final String typeText;

  const _AcademicEventCard({
    required this.event,
    required this.dateText,
    required this.typeText,
  });

  @override
  Widget build(BuildContext context) {
    final String title = event.title.trim().isEmpty
        ? typeText
        : event.title.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            ),
            child: const Icon(
              Icons.event_note_outlined,
              color: AppTheme.primaryBlue,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(title, style: AppTheme.cardTitle)),
                    const SizedBox(width: 10),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(typeText, style: AppTheme.labelText),

                if (event.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    event.description.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.secondaryBodyText,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HomeMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.cardTitle),

                const SizedBox(height: 5),

                Text(description, style: AppTheme.secondaryBodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  final VoidCallback onRetry;

  const _HomeError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: AppTheme.secondaryText,
            ),

            const SizedBox(height: 16),

            const Text(
              'Не удалось загрузить главную',
              textAlign: TextAlign.center,
              style: AppTheme.sectionTitle,
            ),

            const SizedBox(height: 8),

            const Text(
              'Проверьте подключение к интернету и попробуйте ещё раз.',
              textAlign: TextAlign.center,
              style: AppTheme.secondaryBodyText,
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
