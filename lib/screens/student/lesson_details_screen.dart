import 'package:flutter/material.dart';

import '../../models/lesson.dart';

class LessonDetailsScreen extends StatelessWidget {
  final Lesson lesson;

  const LessonDetailsScreen({
    super.key,
    required this.lesson,
  });

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

              const SizedBox(height: 12),

              const LessonInfoTile(
                icon: Icons.calendar_today_outlined,
                title: 'Дата',
                value: 'Дата будет определяться расписанием',
              ),

              const SizedBox(height: 28),

              const Text(
                'Преподаватель',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Профиль преподавателя добавим позже',
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
                          color: const Color(0xFF2B7FFF)
                              .withValues(
                            alpha: 0.15,
                          ),
                          borderRadius:
                              BorderRadius.circular(14),
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
                              lesson.teacher,
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
              ),

              const SizedBox(height: 12),

              LessonInfoTile(
                icon: Icons.meeting_room_outlined,
                title: 'Аудитория',
                value: lesson.room == 'Спортзал'
                    ? lesson.room
                    : 'Кабинет ${lesson.room}',
              ),

              const SizedBox(height: 28),

              const Text(
                'Дополнительная информация',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              const LessonInfoTile(
                icon: Icons.groups_outlined,
                title: 'Учебная группа',
                value: 'Будет загружена из расписания',
              ),

              const SizedBox(height: 12),

              const LessonInfoTile(
                icon: Icons.group_work_outlined,
                title: 'Подгруппа',
                value: 'Не указана',
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
                            'Список событий добавим позже',
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
                      'Контрольные, лабораторные и другие '
                      'учебные события будут отображаться здесь.',
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
              crossAxisAlignment: CrossAxisAlignment.start,
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