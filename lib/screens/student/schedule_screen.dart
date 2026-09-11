import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import 'lesson_details_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int selectedDayIndex = 0;
  int weekOffset = 0;

  final List<String> days = const [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
  ];

  late final DateTime currentMonday;

  final Map<int, List<Lesson>> weeklySchedule = {
    0: const [
      Lesson(
        number: 1,
        time: '08:00 – 09:40',
        subject: 'Разработка программных модулей',
        teachers: [
          'Иванов И. И.',
        ],
        rooms: [
          '301',
        ],
        type: 'Практическое занятие',
        groupId: '4к9391',
      ),
      Lesson(
        number: 2,
        time: '09:50 – 11:30',
        subject: 'Базы данных',
        teachers: [
          'Петров П. П.',
        ],
        rooms: [
          '405',
        ],
        type: 'Лабораторная работа',
        groupId: '4к9391',
        subgroup: '1 подгруппа',
      ),
      Lesson(
        number: 3,
        time: '11:50 – 13:30',
        subject: 'Иностранный язык',
        teachers: [
          'Кузнецова Е. С.',
        ],
        rooms: [
          '118',
        ],
        type: 'Практическое занятие',
        groupId: '4к9391',
        subgroup: '2 подгруппа',
      ),
    ],

    1: const [
      Lesson(
        number: 2,
        time: '09:50 – 11:30',
        subject: 'Технология разработки программного обеспечения',
        teachers: [
          'Сидоров А. В.',
        ],
        rooms: [
          '214',
        ],
        type: 'Лекция',
        groupId: '4к9391',
      ),
      Lesson(
        number: 3,
        time: '11:50 – 13:30',
        subject: 'Операционные системы',
        teachers: [
          'Орлов Д. П.',
        ],
        rooms: [
          '302',
        ],
        type: 'Лабораторная работа',
        groupId: '4к9391',
      ),
      Lesson(
        number: 4,
        time: '13:40 – 15:20',
        subject: 'Физическая культура',
        teachers: [
          'Смирнов В. А.',
        ],
        rooms: [
          'Спортзал',
        ],
        type: 'Практическое занятие',
        groupId: '4к9391',
      ),
    ],

    2: const [
      Lesson(
        number: 1,
        time: '08:00 – 09:40',
        subject: 'Базы данных',
        teachers: [
          'Петров П. П.',
        ],
        rooms: [
          '405',
        ],
        type: 'Лекция',
        groupId: '4к9391',
      ),
      Lesson(
        number: 2,
        time: '09:50 – 11:30',
        subject: 'Разработка программных модулей',
        teachers: [
          'Иванов И. И.',
          'Семенов Д. А.',
        ],
        rooms: [
          '301',
          '302',
        ],
        type: 'Лабораторная работа',
        groupId: '4к9391',
      ),
    ],

    3: const [
      Lesson(
        number: 3,
        time: '11:50 – 13:30',
        subject: 'Иностранный язык',
        teachers: [
          'Кузнецова Е. С.',
        ],
        rooms: [
          '118',
        ],
        type: 'Практическое занятие',
        groupId: '4к9391',
      ),
      Lesson(
        number: 4,
        time: '13:40 – 15:20',
        subject: 'Тестирование программного обеспечения',
        teachers: [
          'Морозов Н. В.',
        ],
        rooms: [
          '407',
        ],
        type: 'Практическое занятие',
        groupId: '4к9391',
      ),
      Lesson(
        number: 5,
        time: '15:40 – 17:20',
        subject: 'Технология разработки программного обеспечения',
        teachers: [
          'Сидоров А. В.',
        ],
        rooms: [
          '214',
        ],
        type: 'Практическое занятие',
        groupId: '4к9391',
      ),
    ],

    4: const [
      Lesson(
        number: 1,
        time: '08:00 – 09:40',
        subject: 'Операционные системы',
        teachers: [
          'Орлов Д. П.',
        ],
        rooms: [
          '302',
        ],
        type: 'Лекция',
        groupId: '4к9391',
      ),
      Lesson(
        number: 2,
        time: '09:50 – 11:30',
        subject: 'Тестирование программного обеспечения',
        teachers: [
          'Морозов Н. В.',
        ],
        rooms: [
          '407',
        ],
        type: 'Лабораторная работа',
        groupId: '4к9391',
      ),
    ],

    5: const [],
  };

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
  }

  DateTime get selectedMonday {
    return currentMonday.add(
      Duration(days: weekOffset * 7),
    );
  }

  DateTime getDateForIndex(int index) {
    return selectedMonday.add(
      Duration(days: index),
    );
  }

  void previousWeek() {
    setState(() {
      weekOffset--;
      selectedDayIndex = 0;
    });
  }

  void nextWeek() {
    setState(() {
      weekOffset++;
      selectedDayIndex = 0;
    });
  }

  void returnToCurrentWeek() {
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
    final List<Lesson> lessons =
        weeklySchedule[selectedDayIndex] ?? [];

    final DateTime selectedDate =
        getDateForIndex(selectedDayIndex);

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
                onPressed: previousWeek,
                icon: const Icon(
                  Icons.chevron_left,
                ),
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
                onPressed: nextWeek,
                icon: const Icon(
                  Icons.chevron_right,
                ),
              ),
            ],
          ),
        ),

        if (weekOffset != 0)
          Center(
            child: TextButton.icon(
              onPressed: returnToCurrentWeek,
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
            separatorBuilder: (_, __) {
              return const SizedBox(width: 10);
            },
            itemBuilder: (context, index) {
              final bool isSelected =
                  selectedDayIndex == index;

              final DateTime date =
                  getDateForIndex(index);

              final bool today = isToday(date);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDayIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  width: 58,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2B7FFF)
                        : const Color(0xFF10213D),
                    borderRadius: BorderRadius.circular(18),
                    border: today && !isSelected
                        ? Border.all(
                            color: const Color(0xFF2B7FFF),
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
                              : const Color(0xFFB6C5E0),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
          child: Text(
            '${selectedDate.day} ${getMonthName(selectedDate.month)}',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFFB6C5E0),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: lessons.isEmpty
              ? const EmptySchedule()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    24,
                  ),
                  itemCount: lessons.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 14);
                  },
                  itemBuilder: (context, index) {
                    return LessonCard(
                      lesson: lessons[index],
                      date: selectedDate,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final DateTime date;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return LessonDetailsScreen(
                lesson: lesson,
                date: date,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF2B7FFF).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '${lesson.number}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B7FFF),
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    lesson.time,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB6C5E0),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Color(0xFFB6C5E0),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          lesson.teacher,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB6C5E0),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        size: 18,
                        color: Color(0xFFB6C5E0),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          lesson.room,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB6C5E0),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B7FFF).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lesson.type,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2B7FFF),
                        fontWeight: FontWeight.w600,
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
                color: Color(0xFFB6C5E0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptySchedule extends StatelessWidget {
  const EmptySchedule({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 64,
              color: Color(0xFF2B7FFF),
            ),
            SizedBox(height: 18),
            Text(
              'Занятий нет',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'На этот день расписание пустое.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFFB6C5E0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}