import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../services/schedule_service.dart';
import 'lesson_details_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService scheduleService = ScheduleService();

  int selectedDayIndex = 0;
  int weekOffset = 0;

  String? groupId;
  String? loadingError;

  bool isLoadingGroup = true;
  bool isLoadingLessons = false;

  List<Lesson> lessons = [];

  final List<String> days = const [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
  ];

  late final DateTime currentMonday;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    currentMonday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
    );

    if (now.weekday >= DateTime.monday &&
        now.weekday <= DateTime.saturday) {
      selectedDayIndex = now.weekday - 1;
    } else {
      selectedDayIndex = 0;
    }

    loadStudentGroup();
  }

  DateTime get selectedMonday {
    return currentMonday.add(
      Duration(days: weekOffset * 7),
    );
  }

  DateTime get selectedDate {
    return selectedMonday.add(
      Duration(days: selectedDayIndex),
    );
  }

  DateTime getDateForIndex(int index) {
    return selectedMonday.add(
      Duration(days: index),
    );
  }

  Future<void> loadStudentGroup() async {
    setState(() {
      isLoadingGroup = true;
      loadingError = null;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDocument.exists) {
        throw Exception('Профиль пользователя не найден');
      }

      final Map<String, dynamic>? userData = userDocument.data();

      if (userData == null) {
        throw Exception(
          'Не удалось получить данные пользователя',
        );
      }

      final String? loadedGroupId =
          userData['groupId']?.toString();

      if (loadedGroupId == null ||
          loadedGroupId.trim().isEmpty) {
        throw Exception(
          'Учебная группа пользователю не назначена',
        );
      }

      groupId = loadedGroupId;

      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingGroup = false;
      });

      await loadLessons();
    } catch (e) {
      debugPrint(
        'Ошибка загрузки группы пользователя: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingGroup = false;
        loadingError =
            'Не удалось определить учебную группу.';
      });
    }
  }

  Future<void> loadLessons() async {
    final String? currentGroupId = groupId;

    if (currentGroupId == null) {
      return;
    }

    setState(() {
      isLoadingLessons = true;
      loadingError = null;
    });

    try {
      final List<Lesson> loadedLessons =
          await scheduleService.getLessonsForDay(
        groupId: currentGroupId,
        date: selectedDate,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        lessons = loadedLessons;
        isLoadingLessons = false;
      });
    } catch (e) {
      debugPrint(
        'Ошибка загрузки расписания: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        lessons = [];
        isLoadingLessons = false;
        loadingError =
            'Не удалось получить расписание. '
            'Проверьте подключение и повторите попытку.';
      });
    }
  }

  Future<void> previousWeek() async {
    setState(() {
      weekOffset--;
      selectedDayIndex = 0;
    });

    await loadLessons();
  }

  Future<void> nextWeek() async {
    setState(() {
      weekOffset++;
      selectedDayIndex = 0;
    });

    await loadLessons();
  }

  Future<void> selectDay(int index) async {
    setState(() {
      selectedDayIndex = index;
    });

    await loadLessons();
  }

  Future<void> returnToCurrentWeek() async {
    final DateTime now = DateTime.now();

    setState(() {
      weekOffset = 0;

      if (now.weekday >= DateTime.monday &&
          now.weekday <= DateTime.saturday) {
        selectedDayIndex = now.weekday - 1;
      } else {
        selectedDayIndex = 0;
      }
    });

    await loadLessons();
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

  String getWeekTitle() {
    final DateTime monday = selectedMonday;
    final DateTime saturday = monday.add(
      const Duration(days: 5),
    );

    if (monday.month == saturday.month) {
      return '${monday.day} – ${saturday.day} '
          '${getMonthName(monday.month)}';
    }

    return '${monday.day} ${getMonthName(monday.month)} – '
        '${saturday.day} ${getMonthName(saturday.month)}';
  }

  String getWeekSubtitle() {
    if (weekOffset == 0) {
      return 'Текущая неделя';
    }

    if (weekOffset == 1) {
      return 'Следующая неделя';
    }

    if (weekOffset == -1) {
      return 'Предыдущая неделя';
    }

    if (weekOffset > 1) {
      return 'Через $weekOffset недели';
    }

    return '${weekOffset.abs()} недели назад';
  }

  bool isToday(DateTime date) {
    final DateTime now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              24,
              AppTheme.screenPadding,
              0,
            ),
            child: Text(
              'Расписание',
              style: AppTheme.pageTitle,
            ),
          ),

          const SizedBox(height: 22),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: _WeekSelector(
              title: getWeekTitle(),
              subtitle: getWeekSubtitle(),
              canReturnToCurrentWeek: weekOffset != 0,
              isLoading: isLoadingLessons,
              onPrevious: previousWeek,
              onNext: nextWeek,
              onCurrentWeek: returnToCurrentWeek,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 76,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) {
                return const SizedBox(width: 8);
              },
              itemBuilder: (context, index) {
                final bool isSelected =
                    selectedDayIndex == index;

                final DateTime date =
                    getDateForIndex(index);

                return _DayButton(
                  day: days[index],
                  date: date.day,
                  isSelected: isSelected,
                  isToday: isToday(date),
                  onTap: isLoadingLessons
                      ? null
                      : () => selectDay(index),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedDate.day} '
                    '${getMonthName(selectedDate.month)}',
                    style: AppTheme.sectionTitle,
                  ),
                ),
                if (groupId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(
                        AppTheme.smallRadius,
                      ),
                    ),
                    child: Text(
                      groupId!,
                      style: AppTheme.labelText,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Expanded(
            child: buildScheduleContent(),
          ),
        ],
      ),
    );
  }

  Widget buildScheduleContent() {
    if (isLoadingGroup || isLoadingLessons) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (loadingError != null) {
      return ScheduleError(
        message: loadingError!,
        onRetry: () {
          if (groupId == null) {
            loadStudentGroup();
          } else {
            loadLessons();
          }
        },
      );
    }

    if (lessons.isEmpty) {
      return const EmptySchedule();
    }

    return RefreshIndicator(
      onRefresh: loadLessons,
      color: AppTheme.primaryBlue,
      backgroundColor: AppTheme.card,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          32,
        ),
        itemCount: lessons.length,
        separatorBuilder: (_, _) {
          return const SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          return LessonCard(
            lesson: lessons[index],
          );
        },
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool canReturnToCurrentWeek;
  final bool isLoading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrentWeek;

  const _WeekSelector({
    required this.title,
    required this.subtitle,
    required this.canReturnToCurrentWeek,
    required this.isLoading,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrentWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Row(
        children: [
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Предыдущая неделя',
            onPressed: isLoading ? null : onPrevious,
          ),

          Expanded(
            child: GestureDetector(
              onTap: canReturnToCurrentWeek && !isLoading
                  ? onCurrentWeek
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 2,
                ),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTheme.cardTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: canReturnToCurrentWeek
                            ? AppTheme.primaryBlue
                            : AppTheme.secondaryText,
                        fontWeight: canReturnToCurrentWeek
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Следующая неделя',
            onPressed: isLoading ? null : onNext,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor:
            AppTheme.primaryBlue.withValues(alpha: 0.12),
        foregroundColor: AppTheme.primaryBlue,
        disabledForegroundColor:
            AppTheme.secondaryText.withValues(alpha: 0.4),
      ),
      icon: Icon(icon),
    );
  }
}

class _DayButton extends StatelessWidget {
  final String day;
  final int date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback? onTap;

  const _DayButton({
    required this.day,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppTheme.primaryBlue
          : AppTheme.card,
      borderRadius: BorderRadius.circular(
        AppTheme.cardRadius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppTheme.cardRadius,
            ),
            border: isToday && !isSelected
                ? Border.all(
                    color: AppTheme.primaryBlue,
                    width: 1.5,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$date',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonCard extends StatelessWidget {
  final Lesson lesson;

  const LessonCard({
    super.key,
    required this.lesson,
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
          final DateTime lessonDate =
              lesson.date ?? DateTime.now();

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) {
                return LessonDetailsScreen(
                  lesson: lesson,
                  date: lessonDate,
                );
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallRadius,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${lesson.number}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.subject,
                      style: AppTheme.cardTitle,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      lesson.time,
                      style: AppTheme.secondaryBodyText,
                    ),

                    const SizedBox(height: 12),

                    _LessonInfo(
                      icon: Icons.person_outline,
                      text: lesson.teacher,
                    ),

                    const SizedBox(height: 7),

                    _LessonInfo(
                      icon: Icons.meeting_room_outlined,
                      text: lesson.room,
                    ),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(
                          10,
                        ),
                      ),
                      child: Text(
                        lesson.type,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LessonInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.secondaryText,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppTheme.secondaryBodyText,
          ),
        ),
      ],
    );
  }
}

class EmptySchedule extends StatelessWidget {
  const EmptySchedule({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          20,
          AppTheme.screenPadding,
          40,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 30,
          ),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(
              AppTheme.cardRadius,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.cardRadius,
                  ),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  size: 28,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Занятий нет',
                style: AppTheme.sectionTitle,
              ),

              const SizedBox(height: 6),

              const Text(
                'На этот день расписание пустое.',
                textAlign: TextAlign.center,
                style: AppTheme.secondaryBodyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ScheduleError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        10,
        AppTheme.screenPadding,
        32,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(
            AppTheme.cardRadius,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.cardRadius,
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: AppTheme.danger,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Не удалось загрузить расписание',
              textAlign: TextAlign.center,
              style: AppTheme.sectionTitle,
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.secondaryBodyText,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}