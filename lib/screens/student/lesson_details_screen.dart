import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/academic_event.dart';
import '../../models/lesson.dart';
import '../../services/academic_event_service.dart';

class LessonDetailsScreen extends StatefulWidget {
  final Lesson lesson;
  final DateTime date;

  const LessonDetailsScreen({
    super.key,
    required this.lesson,
    required this.date,
  });

  @override
  State<LessonDetailsScreen> createState() =>
      _LessonDetailsScreenState();
}

class _LessonDetailsScreenState
    extends State<LessonDetailsScreen> {
  final AcademicEventService _academicEventService =
      AcademicEventService();

  List<AcademicEvent> _events = [];

  bool _isLoadingEvents = true;
  bool _hasEventsError = false;

  Lesson get lesson => widget.lesson;
  DateTime get date => widget.date;

  @override
  void initState() {
    super.initState();
    _loadAcademicEvents();
  }

  Future<void> _loadAcademicEvents() async {
    final String? lessonId = lesson.id;
    final String? groupId = lesson.groupId;

    if (lessonId == null ||
        lessonId.trim().isEmpty ||
        groupId == null ||
        groupId.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _events = [];
        _isLoadingEvents = false;
        _hasEventsError = false;
      });

      return;
    }

    try {
      final List<AcademicEvent> events =
          await _academicEventService.getEventsForLesson(
        groupId: groupId,
        lessonId: lessonId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events = events;
        _isLoadingEvents = false;
        _hasEventsError = false;
      });
    } catch (error) {
      debugPrint(
        'Ошибка загрузки учебных событий: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events = [];
        _isLoadingEvents = false;
        _hasEventsError = true;
      });
    }
  }

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

  String getEventDate(DateTime eventDate) {
    final String day =
        eventDate.day.toString().padLeft(2, '0');

    final String month =
        eventDate.month.toString().padLeft(2, '0');

    return '$day.$month.${eventDate.year}';
  }

  String getSubgroup() {
    final String? subgroup = lesson.subgroup;

    if (subgroup == null ||
        subgroup.trim().isEmpty) {
      return 'Вся группа';
    }

    return subgroup;
  }

  String getGroup() {
    final String? groupId = lesson.groupId;

    if (groupId == null ||
        groupId.trim().isEmpty) {
      return 'Группа не указана';
    }

    return groupId;
  }

  IconData getEventIcon(String type) {
    final String normalizedType =
        type.toLowerCase();

    if (normalizedType.contains(
      'лаборатор',
    )) {
      return Icons.science_outlined;
    }

    if (normalizedType.contains(
      'контроль',
    )) {
      return Icons.assignment_outlined;
    }

    if (normalizedType.contains('тест')) {
      return Icons.quiz_outlined;
    }

    if (normalizedType.contains(
      'экзамен',
    )) {
      return Icons.school_outlined;
    }

    if (normalizedType.contains('окр')) {
      return Icons.fact_check_outlined;
    }

    return Icons.event_note_outlined;
  }

  Widget _buildAcademicEvents() {
    if (_isLoadingEvents) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 28,
        ),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasEventsError) {
      return _StateCard(
        icon: Icons.error_outline,
        iconColor: AppTheme.danger,
        title: 'Не удалось загрузить события',
        description:
            'Проверьте подключение и повторите попытку.',
        buttonText: 'Повторить',
        onPressed: () {
          setState(() {
            _isLoadingEvents = true;
            _hasEventsError = false;
          });

          _loadAcademicEvents();
        },
      );
    }

    if (_events.isEmpty) {
      return const _StateCard(
        icon: Icons.event_note_outlined,
        iconColor: AppTheme.primaryBlue,
        title: 'Событий пока нет',
        description:
            'Контрольные, лабораторные, тесты '
            'и другие учебные события будут '
            'отображаться здесь.',
      );
    }

    return Column(
      children: _events.map(
        (event) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: 10,
            ),
            child: AcademicEventCard(
              event: event,
              icon: getEventIcon(event.type),
              formattedDate:
                  getEventDate(event.date),
            ),
          );
        },
      ).toList(),
    );
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
        child: RefreshIndicator(
          onRefresh: _loadAcademicEvents,
          color: AppTheme.primaryBlue,
          backgroundColor: AppTheme.card,
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              16,
              AppTheme.screenPadding,
              32,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.subject,
                  style: AppTheme.pageTitle.copyWith(
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                _TypeBadge(
                  text: lesson.type,
                ),

                const SizedBox(height: 30),

                const _SectionTitle(
                  title: 'Основная информация',
                ),

                const SizedBox(height: 12),

                LessonInfoTile(
                  icon:
                      Icons.calendar_today_outlined,
                  title: 'Дата',
                  value: getFormattedDate(),
                ),

                const SizedBox(height: 10),

                LessonInfoTile(
                  icon:
                      Icons.format_list_numbered,
                  title: 'Номер пары',
                  value: '${lesson.number} пара',
                ),

                const SizedBox(height: 10),

                LessonInfoTile(
                  icon:
                      Icons.access_time_outlined,
                  title: 'Время',
                  value: lesson.time,
                ),

                const SizedBox(height: 28),

                const _SectionTitle(
                  title: 'Преподаватели',
                ),

                const SizedBox(height: 12),

                ...lesson.teachers.map(
                  (teacher) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: TeacherCard(
                        teacher: teacher,
                      ),
                    );
                  },
                ),

                if (lesson.teachers.isEmpty)
                  const EmptyInfoCard(
                    icon:
                        Icons.person_off_outlined,
                    text:
                        'Преподаватель не указан',
                  ),

                const SizedBox(height: 28),

                const _SectionTitle(
                  title: 'Аудитории',
                ),

                const SizedBox(height: 12),

                ...lesson.rooms.map(
                  (room) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: LessonInfoTile(
                        icon: Icons
                            .meeting_room_outlined,
                        title: 'Аудитория',
                        value: room,
                      ),
                    );
                  },
                ),

                if (lesson.rooms.isEmpty)
                  const EmptyInfoCard(
                    icon:
                        Icons.meeting_room_outlined,
                    text:
                        'Аудитория не указана',
                  ),

                const SizedBox(height: 28),

                const _SectionTitle(
                  title: 'Учебная группа',
                ),

                const SizedBox(height: 12),

                LessonInfoTile(
                  icon: Icons.groups_outlined,
                  title: 'Группа',
                  value: getGroup(),
                ),

                const SizedBox(height: 10),

                LessonInfoTile(
                  icon:
                      Icons.group_work_outlined,
                  title: 'Подгруппа',
                  value: getSubgroup(),
                ),

                const SizedBox(height: 28),

                const _SectionTitle(
                  title: 'Учебные события',
                ),

                const SizedBox(height: 12),

                _buildAcademicEvents(),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Создание напоминаний добавим позже',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons
                          .notifications_active_outlined,
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
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTheme.sectionTitle,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String text;

  const _TypeBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue
            .withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(
          10,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AcademicEventCard
    extends StatelessWidget {
  final AcademicEvent event;
  final IconData icon;
  final String formattedDate;

  const AcademicEventCard({
    super.key,
    required this.event,
    required this.icon,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _BlueIconBox(
            icon: icon,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  event.type,
                  style: const TextStyle(
                    fontSize: 12,
                    color:
                        AppTheme.primaryBlue,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  event.title,
                  style: AppTheme.cardTitle,
                ),

                if (event.description
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.description,
                    style: AppTheme
                        .secondaryBodyText,
                  ),
                ],

                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_today_outlined,
                      size: 15,
                      color:
                          AppTheme.secondaryText,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      formattedDate,
                      style:
                          AppTheme.labelText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(
        AppTheme.cardRadius,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: Text(
                'Профиль преподавателя $teacher добавим позже',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _BlueIconBox(
                icon: Icons.person_outline,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Преподаватель',
                      style:
                          AppTheme.labelText,
                    ),

                    const SizedBox(height: 3),

                    Text(
                      teacher,
                      style:
                          AppTheme.cardTitle,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color:
                    AppTheme.secondaryText,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          _BlueIconBox(
            icon: icon,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      AppTheme.labelText,
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style:
                      AppTheme.cardTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueIconBox extends StatelessWidget {
  final IconData icon;

  const _BlueIconBox({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue
            .withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(
          AppTheme.smallRadius,
        ),
      ),
      child: Icon(
        icon,
        size: 22,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

class EmptyInfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyInfoCard({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Row(
        children: [
          _BlueIconBox(
            icon: icon,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              text,
              style:
                  AppTheme.secondaryBodyText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 26,
      ),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconColor.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                AppTheme.cardRadius,
              ),
            ),
            child: Icon(
              icon,
              size: 27,
              color: iconColor,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.cardTitle,
          ),

          const SizedBox(height: 6),

          Text(
            description,
            textAlign: TextAlign.center,
            style:
                AppTheme.secondaryBodyText,
          ),

          if (buttonText != null &&
              onPressed != null) ...[
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: Text(
                  buttonText!,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}