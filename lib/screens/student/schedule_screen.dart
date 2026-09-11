import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      Duration(
        days: weekOffset * 7,
      ),
    );
  }

  DateTime get selectedDate {
    return selectedMonday.add(
      Duration(
        days: selectedDayIndex,
      ),
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
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Пользователь не авторизован',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>>
          userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDocument.exists) {
        throw Exception(
          'Профиль пользователя не найден',
        );
      }

      final Map<String, dynamic>? userData =
          userDocument.data();

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            8,
          ),
          child: Text(
            'Расписание',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: isLoadingLessons
                    ? null
                    : previousWeek,
                icon: const Icon(
                  Icons.chevron_left,
                ),
                tooltip: 'Предыдущая неделя',
              ),

              Expanded(
                child: Column(
                  children: [
                    Text(
                      getWeekTitle(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      getWeekSubtitle(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB6C5E0),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: isLoadingLessons
                    ? null
                    : nextWeek,
                icon: const Icon(
                  Icons.chevron_right,
                ),
                tooltip: 'Следующая неделя',
              ),
            ],
          ),
        ),

        if (weekOffset != 0)
          Center(
            child: TextButton.icon(
              onPressed: isLoadingLessons
                  ? null
                  : returnToCurrentWeek,
              icon: const Icon(
                Icons.today_outlined,
                size: 18,
              ),
              label: const Text(
                'Текущая неделя',
              ),
            ),
          ),

        const SizedBox(height: 10),

        SizedBox(
          height: 82,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) {
              return const SizedBox(
                width: 10,
              );
            },
            itemBuilder: (context, index) {
              final bool isSelected =
                  selectedDayIndex == index;

              final DateTime date =
                  getDateForIndex(index);

              final bool today =
                  isToday(date);

              return GestureDetector(
                onTap: isLoadingLessons
                    ? null
                    : () {
                        selectDay(index);
                      },
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  width: 58,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(
                            0xFF2B7FFF,
                          )
                        : const Color(
                            0xFF10213D,
                          ),
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    border: today &&
                            !isSelected
                        ? Border.all(
                            color:
                                const Color(
                              0xFF2B7FFF,
                            ),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        days[index],
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? Colors.white
                              : const Color(
                                  0xFFB6C5E0,
                                ),
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${selectedDate.day} '
                  '${getMonthName(selectedDate.month)}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(
                      0xFFB6C5E0,
                    ),
                  ),
                ),
              ),

              if (groupId != null)
                Text(
                  groupId!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(
                      0xFFB6C5E0,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: buildScheduleContent(),
        ),
      ],
    );
  }

  Widget buildScheduleContent() {
    if (isLoadingGroup ||
        isLoadingLessons) {
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
      child: ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24,
        ),
        itemCount: lessons.length,
        separatorBuilder: (_, _ ) {
          return const SizedBox(
            height: 14,
          );
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

class LessonCard extends StatelessWidget {
  final Lesson lesson;

  const LessonCard({
    super.key,
    required this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        final DateTime lessonDate =
            lesson.date ??
                DateTime.now();

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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF10213D),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF2B7FFF,
                ).withValues(
                  alpha: 0.15,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Center(
                child: Text(
                  '${lesson.number}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF2B7FFF),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.subject,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    lesson.time,
                    style: const TextStyle(
                      fontSize: 14,
                      color:
                          Color(0xFFB6C5E0),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 18,
                        color:
                            Color(0xFFB6C5E0),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          lesson.teacher,
                          style:
                              const TextStyle(
                            fontSize: 14,
                            color: Color(
                              0xFFB6C5E0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons
                            .meeting_room_outlined,
                        size: 18,
                        color:
                            Color(0xFFB6C5E0),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          lesson.room,
                          style:
                              const TextStyle(
                            fontSize: 14,
                            color: Color(
                              0xFFB6C5E0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF2B7FFF,
                      ).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Text(
                      lesson.type,
                      style: const TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF2B7FFF),
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Padding(
              padding: EdgeInsets.only(
                top: 10,
              ),
              child: Icon(
                Icons.chevron_right,
                color:
                    Color(0xFFB6C5E0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptySchedule extends StatelessWidget {
  const EmptySchedule({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .event_available_outlined,
              size: 64,
              color:
                  Color(0xFF2B7FFF),
            ),

            SizedBox(height: 18),

            Text(
              'Занятий нет',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'На этот день расписание пустое.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color:
                    Color(0xFFB6C5E0),
              ),
            ),
          ],
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
  Widget build(
    BuildContext context,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 58,
              color:
                  Color(0xFFB6C5E0),
            ),

            const SizedBox(height: 16),

            const Text(
              'Не удалось загрузить расписание',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              message,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color:
                    Color(0xFFB6C5E0),
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Повторить',
              ),
            ),
          ],
        ),
      ),
    );
  }
}