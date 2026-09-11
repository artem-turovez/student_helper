import 'package:flutter/material.dart';

import '../../models/lesson.dart';

class LessonDetailsScreen extends StatelessWidget {
  final Lesson lesson;
  final DateTime date;

  const LessonDetailsScreen({
    super.key,
    required this.lesson,
    required this.date,
  });

  String getMonthName(int month) {
    const List<String> months = [
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

    return months[month - 1];
  }

  String getWeekdayName(int weekday) {
    const List<String> weekdays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];

    return weekdays[weekday - 1];
  }

  String getFormattedDate() {
    return '${getWeekdayName(date.weekday)}, '
        '${date.day} ${getMonthName(date.month)} ${date.year}';
  }

  String getSubgroup() {
    final String? subgroup = lesson.subgroup;

    if (subgroup == null || subgroup.trim().isEmpty) {
      return 'Вся группа';
    }

    return subgroup;
  }

  String getGroup() {
    final String? groupId = lesson.groupId;

    if (groupId == null || groupId.trim().isEmpty) {
      return 'Группа не указана';
    }

    return groupId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Информация о занятии',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.subject,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B7FFF).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lesson.type,
                  style: const TextStyle(
                    color: Color(0xFF2B7FFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Основная информация',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              LessonInfoTile(
                icon: Icons.calendar_today_outlined,
                title: 'Дата',
                value: getFormattedDate(),
              ),

              const SizedBox(height: 12),

              LessonInfoTile(
                icon: Icons.format_list_numbered,
                title: 'Номер пары',
                value: '${lesson.number} пара',
              ),

              const SizedBox(height: 12),

              LessonInfoTile(
                icon: Icons.access_time_outlined,
                title: 'Время',
                value: lesson.time,
              ),

              const SizedBox(height: 28),

              const Text(
                'Преподаватели',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              ...lesson.teachers.map(
                (teacher) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: TeacherCard(
                      teacher: teacher,
                    ),
                  );
                },
              ),

              if (lesson.teachers.isEmpty)
                const EmptyInfoCard(
                  text: 'Преподаватель не указан',
                ),

              const SizedBox(height: 16),

              const Text(
                'Аудитории',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              ...lesson.rooms.map(
                (room) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: LessonInfoTile(
                      icon: Icons.meeting_room_outlined,
                      title: 'Аудитория',
                      value: room,
                    ),
                  );
                },
              ),

              if (lesson.rooms.isEmpty)
                const EmptyInfoCard(
                  text: 'Аудитория не указана',
                ),

              const SizedBox(height: 16),

              const Text(
                'Учебная группа',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              LessonInfoTile(
                icon: Icons.groups_outlined,
                title: 'Группа',
                value: getGroup(),
              ),

              const SizedBox(height: 12),

              LessonInfoTile(
                icon: Icons.group_work_outlined,
                title: 'Подгруппа',
                value: getSubgroup(),
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Учебные события',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Список учебных событий добавим позже',
                          ),
                          behavior:
                              SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text(
                      'Все',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10213D),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 42,
                      color: Color(0xFF2B7FFF),
                    ),

                    SizedBox(height: 12),

                    Text(
                      'Событий пока нет',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      'Контрольные, лабораторные, тесты '
                      'и другие учебные события будут '
                      'отображаться здесь.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFFB6C5E0),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Создание напоминаний добавим позже',
                        ),
                        behavior:
                            SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                  ),
                  label: const Text(
                    'Создать напоминание',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherCard extends StatelessWidget {
  final String teacher;

  const TeacherCard({
    super.key,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Профиль преподавателя $teacher добавим позже',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF10213D),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2B7FFF).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFF2B7FFF),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Преподаватель',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB6C5E0),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    teacher,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Color(0xFFB6C5E0),
            ),
          ],
        ),
      ),
    );
  }
}

class LessonInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const LessonInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10213D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2B7FFF).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2B7FFF),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB6C5E0),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyInfoCard extends StatelessWidget {
  final String text;

  const EmptyInfoCard({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10213D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB6C5E0),
        ),
      ),
    );
  }
}