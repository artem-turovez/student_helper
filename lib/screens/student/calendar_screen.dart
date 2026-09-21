import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/academic_event.dart';
import '../../services/academic_event_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() =>
      _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AcademicEventService _academicEventService =
      AcademicEventService();

  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  String? _groupId;

  List<AcademicEvent> _events = [];

  bool _isLoading = true;
  bool _hasError = false;

  static const List<String> _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static const List<String> _monthNamesGenitive = [
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

  static const List<String> _weekdays = [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    _visibleMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    _selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _loadStudentGroup();
  }

  Future<void> _loadStudentGroup() async {
    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Пользователь не авторизован',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>>
          document = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? data =
          document.data();

      final String? groupId =
          data?['groupId']?.toString();

      if (groupId == null ||
          groupId.trim().isEmpty) {
        throw Exception(
          'Учебная группа не назначена',
        );
      }

      _groupId = groupId;

      await _loadEvents();
    } catch (error) {
      debugPrint(
        'Ошибка получения группы для календаря: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadEvents() async {
    final String? groupId = _groupId;

    if (groupId == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final List<AcademicEvent> events =
          await _academicEventService
              .getEventsForMonth(
        groupId: groupId,
        month: _visibleMonth,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events = events;
        _isLoading = false;
        _hasError = false;
      });
    } catch (error) {
      debugPrint(
        'Ошибка загрузки событий календаря: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events = [];
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _previousMonth() async {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month - 1,
        1,
      );

      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        1,
      );
    });

    await _loadEvents();
  }

  Future<void> _nextMonth() async {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        1,
      );

      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        1,
      );
    });

    await _loadEvents();
  }

  bool _isSameDay(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _hasEventsOnDay(DateTime date) {
    return _events.any(
      (event) => _isSameDay(
        event.date,
        date,
      ),
    );
  }

  List<AcademicEvent> _getEventsForSelectedDay() {
    return _events
        .where(
          (event) => _isSameDay(
            event.date,
            _selectedDate,
          ),
        )
        .toList();
  }

  List<DateTime?> _getCalendarDays() {
    final DateTime firstDay = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );

    final int daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    final int emptyDaysBefore =
        firstDay.weekday - 1;

    final List<DateTime?> days = [];

    for (int i = 0;
        i < emptyDaysBefore;
        i++) {
      days.add(null);
    }

    for (int day = 1;
        day <= daysInMonth;
        day++) {
      days.add(
        DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          day,
        ),
      );
    }

    return days;
  }

  IconData _getEventIcon(String type) {
    final String value = type.toLowerCase();

    if (value.contains('лаборатор')) {
      return Icons.science_outlined;
    }

    if (value.contains('контроль')) {
      return Icons.assignment_outlined;
    }

    if (value.contains('тест')) {
      return Icons.quiz_outlined;
    }

    if (value.contains('экзамен')) {
      return Icons.school_outlined;
    }

    if (value.contains('окр')) {
      return Icons.fact_check_outlined;
    }

    return Icons.event_note_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime?> calendarDays =
        _getCalendarDays();

    final List<AcademicEvent> selectedEvents =
        _getEventsForSelectedDay();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadEvents,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            32,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Календарь',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Учебные события и важные даты',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB6C5E0),
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF10213D),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _previousMonth,
                          icon: const Icon(
                            Icons.chevron_left,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            '${_monthNames[_visibleMonth.month - 1]} '
                            '${_visibleMonth.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: _nextMonth,
                          icon: const Icon(
                            Icons.chevron_right,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: _weekdays.map(
                        (weekday) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                weekday,
                                style:
                                    const TextStyle(
                                  fontSize: 13,
                                  color: Color(
                                    0xFFB6C5E0,
                                  ),
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(height: 10),

                    GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount:
                          calendarDays.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 4,
                      ),
                      itemBuilder:
                          (context, index) {
                        final DateTime? day =
                            calendarDays[index];

                        if (day == null) {
                          return const SizedBox();
                        }

                        final bool isSelected =
                            _isSameDay(
                          day,
                          _selectedDate,
                        );

                        final bool isToday =
                            _isSameDay(
                          day,
                          DateTime.now(),
                        );

                        final bool hasEvents =
                            _hasEventsOnDay(day);

                        return InkWell(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedDate = day;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFF2B7FFF,
                                    )
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                              border: isToday &&
                                      !isSelected
                                  ? Border.all(
                                      color:
                                          const Color(
                                        0xFF2B7FFF,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Stack(
                              alignment:
                                  Alignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        isSelected ||
                                                isToday
                                            ? FontWeight
                                                .bold
                                            : FontWeight
                                                .normal,
                                    color: isSelected
                                        ? Colors.white
                                        : null,
                                  ),
                                ),

                                if (hasEvents)
                                  Positioned(
                                    bottom: 4,
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration:
                                          BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(
                                                0xFF2B7FFF,
                                              ),
                                        shape:
                                            BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'События на ${_selectedDate.day} '
                '${_monthNamesGenitive[_selectedDate.month - 1]}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding:
                        EdgeInsets.all(24),
                    child:
                        CircularProgressIndicator(),
                  ),
                )
              else if (_hasError)
                _CalendarMessageCard(
                  icon: Icons.error_outline,
                  title:
                      'Не удалось загрузить события',
                  description:
                      'Попробуйте обновить календарь.',
                )
              else if (selectedEvents.isEmpty)
                const _CalendarMessageCard(
                  icon:
                      Icons.event_note_outlined,
                  title: 'Событий пока нет',
                  description:
                      'Учебные события выбранного дня '
                      'будут отображаться здесь.',
                )
              else
                ...selectedEvents.map(
                  (event) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: _CalendarEventCard(
                      event: event,
                      icon: _getEventIcon(
                        event.type,
                      ),
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

class _CalendarEventCard extends StatelessWidget {
  final AcademicEvent event;
  final IconData icon;

  const _CalendarEventCard({
    required this.event,
    required this.icon,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  event.type,
                  style: const TextStyle(
                    color: Color(0xFF2B7FFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),

                if (event.description
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFFB6C5E0),
                    ),
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

class _CalendarMessageCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _CalendarMessageCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10213D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: const Color(0xFF2B7FFF),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFFB6C5E0),
            ),
          ),
        ],
      ),
    );
  }
}