import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/academic_event.dart';
import '../../models/personal_event.dart';
import '../../services/academic_event_service.dart';
import '../../services/personal_event_service.dart';
import 'create_personal_event_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() =>
      _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AcademicEventService _academicEventService =
      AcademicEventService();

  final PersonalEventService _personalEventService =
      PersonalEventService();

  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  String? _groupId;

  List<AcademicEvent> _academicEvents = [];
  List<PersonalEvent> _personalEvents = [];

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

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (groupId == null || user == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final List<dynamic> results =
          await Future.wait([
        _academicEventService.getEventsForMonth(
          groupId: groupId,
          month: _visibleMonth,
        ),
        _personalEventService.getEventsForMonth(
          userId: user.uid,
          month: _visibleMonth,
        ),
      ]);

      final List<AcademicEvent> academicEvents =
          results[0] as List<AcademicEvent>;

      final List<PersonalEvent> personalEvents =
          results[1] as List<PersonalEvent>;

      if (!mounted) {
        return;
      }

      setState(() {
        _academicEvents = academicEvents;
        _personalEvents = personalEvents;

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
        _academicEvents = [];
        _personalEvents = [];

        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _openCreatePersonalEvent() async {
    final bool? changed =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreatePersonalEventScreen(
          initialDate: _selectedDate,
        ),
      ),
    );

    if (changed == true) {
      await _loadEvents();
    }
  }

  Future<void> _editPersonalEvent(
    PersonalEvent event,
  ) async {
    final bool? changed =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreatePersonalEventScreen(
          initialDate: event.date,
          event: event,
        ),
      ),
    );

    if (changed == true) {
      await _loadEvents();
    }
  }

  Future<void> _togglePersonalEvent(
    PersonalEvent event,
  ) async {
    final String? eventId = event.id;

    if (eventId == null) {
      return;
    }

    try {
      await _personalEventService.setCompleted(
        eventId: eventId,
        isCompleted: !event.isCompleted,
      );

      await _loadEvents();
    } catch (error) {
      debugPrint(
        'Ошибка изменения статуса события: $error',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось изменить статус события',
          ),
        ),
      );
    }
  }

  Future<void> _deletePersonalEvent(
    PersonalEvent event,
  ) async {
    final String? eventId = event.id;

    if (eventId == null) {
      return;
    }

    final bool? shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Удалить событие?',
          ),
          content: Text(
            'Событие «${event.title}» будет удалено без возможности восстановления.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Отмена',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Удалить',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _personalEventService.deleteEvent(
        eventId: eventId,
      );

      await _loadEvents();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Событие удалено',
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        'Ошибка удаления события: $error',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось удалить событие',
          ),
        ),
      );
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

  bool _hasAcademicEventsOnDay(
    DateTime date,
  ) {
    return _academicEvents.any(
      (event) => _isSameDay(
        event.date,
        date,
      ),
    );
  }

  bool _hasPersonalEventsOnDay(
    DateTime date,
  ) {
    return _personalEvents.any(
      (event) => _isSameDay(
        event.date,
        date,
      ),
    );
  }

  List<AcademicEvent>
      _getAcademicEventsForSelectedDay() {
    return _academicEvents
        .where(
          (event) => _isSameDay(
            event.date,
            _selectedDate,
          ),
        )
        .toList();
  }

  List<PersonalEvent>
      _getPersonalEventsForSelectedDay() {
    final List<PersonalEvent> events =
        _personalEvents
            .where(
              (event) => _isSameDay(
                event.date,
                _selectedDate,
              ),
            )
            .toList();

    events.sort((a, b) {
      if (a.isCompleted == b.isCompleted) {
        return a.date.compareTo(b.date);
      }

      return a.isCompleted ? 1 : -1;
    });

    return events;
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

    for (
      int i = 0;
      i < emptyDaysBefore;
      i++
    ) {
      days.add(null);
    }

    for (
      int day = 1;
      day <= daysInMonth;
      day++
    ) {
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

    final List<AcademicEvent> academicEvents =
        _getAcademicEventsForSelectedDay();

    final List<PersonalEvent> personalEvents =
        _getPersonalEventsForSelectedDay();

    final bool hasSelectedEvents =
        academicEvents.isNotEmpty ||
            personalEvents.isNotEmpty;

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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Календарь',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed:
                        _openCreatePersonalEvent,
                    icon: const Icon(
                      Icons.add,
                    ),
                    tooltip:
                        'Добавить событие',
                  ),
                ],
              ),

              const SizedBox(height: 6),

              const Text(
                'Учебные и личные события',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB6C5E0),
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF10213D),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                              _previousMonth,
                          icon: const Icon(
                            Icons.chevron_left,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            '${_monthNames[_visibleMonth.month - 1]} '
                            '${_visibleMonth.year}',
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed:
                              _nextMonth,
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

                        final bool
                            hasAcademicEvents =
                            _hasAcademicEventsOnDay(
                          day,
                        );

                        final bool
                            hasPersonalEvents =
                            _hasPersonalEventsOnDay(
                          day,
                        );

                        return InkWell(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedDate =
                                  day;
                            });
                          },
                          child: Container(
                            decoration:
                                BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFF2B7FFF,
                                    )
                                  : Colors
                                      .transparent,
                              borderRadius:
                                  BorderRadius
                                      .circular(12),
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
                                  style:
                                      TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        isSelected ||
                                                isToday
                                            ? FontWeight
                                                .bold
                                            : FontWeight
                                                .normal,
                                    color:
                                        isSelected
                                            ? Colors
                                                .white
                                            : null,
                                  ),
                                ),

                                if (hasAcademicEvents ||
                                    hasPersonalEvents)
                                  Positioned(
                                    bottom: 3,
                                    child: Row(
                                      mainAxisSize:
                                          MainAxisSize
                                              .min,
                                      children: [
                                        if (hasAcademicEvents)
                                          _EventDot(
                                            isSelected:
                                                isSelected,
                                            isPersonal:
                                                false,
                                          ),

                                        if (hasAcademicEvents &&
                                            hasPersonalEvents)
                                          const SizedBox(
                                            width: 3,
                                          ),

                                        if (hasPersonalEvents)
                                          _EventDot(
                                            isSelected:
                                                isSelected,
                                            isPersonal:
                                                true,
                                          ),
                                      ],
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
                const _CalendarMessageCard(
                  icon: Icons.error_outline,
                  title:
                      'Не удалось загрузить события',
                  description:
                      'Попробуйте обновить календарь.',
                )
              else if (!hasSelectedEvents)
                const _CalendarMessageCard(
                  icon:
                      Icons.event_note_outlined,
                  title:
                      'Событий пока нет',
                  description:
                      'На выбранную дату ничего не запланировано.',
                )
              else ...[
                if (academicEvents.isNotEmpty) ...[
                  const _SectionTitle(
                    title:
                        'Учебные события',
                  ),
                  const SizedBox(height: 10),

                  ...academicEvents.map(
                    (event) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child:
                          _AcademicEventCard(
                        event: event,
                        icon: _getEventIcon(
                          event.type,
                        ),
                      ),
                    ),
                  ),
                ],

                if (personalEvents.isNotEmpty) ...[
                  if (academicEvents.isNotEmpty)
                    const SizedBox(height: 10),

                  const _SectionTitle(
                    title:
                        'Личные события',
                  ),

                  const SizedBox(height: 10),

                  ...personalEvents.map(
                    (event) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child:
                          _PersonalEventCard(
                        event: event,
                        onToggle: () =>
                            _togglePersonalEvent(
                          event,
                        ),
                        onEdit: () =>
                            _editPersonalEvent(
                          event,
                        ),
                        onDelete: () =>
                            _deletePersonalEvent(
                          event,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDot extends StatelessWidget {
  final bool isSelected;
  final bool isPersonal;

  const _EventDot({
    required this.isSelected,
    required this.isPersonal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white
            : isPersonal
                ? const Color(0xFFB18CFF)
                : const Color(0xFF2B7FFF),
        shape: BoxShape.circle,
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
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFFB6C5E0),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AcademicEventCard
    extends StatelessWidget {
  final AcademicEvent event;
  final IconData icon;

  const _AcademicEventCard({
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2B7FFF)
                  .withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF2B7FFF),
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
                    color:
                        Color(0xFF2B7FFF),
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
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
                      color:
                          Color(0xFFB6C5E0),
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

class _PersonalEventCard
    extends StatelessWidget {
  final PersonalEvent event;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonalEventCard({
    required this.event,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10213D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius:
                BorderRadius.circular(50),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                event.isCompleted
                    ? Icons.check_circle
                    : Icons
                        .radio_button_unchecked,
                size: 28,
                color: event.isCompleted
                    ? const Color(
                        0xFF63D6A3,
                      )
                    : const Color(
                        0xFFB18CFF,
                      ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  event.isCompleted
                      ? 'Выполнено'
                      : 'Личное событие',
                  style: TextStyle(
                    color: event.isCompleted
                        ? const Color(
                            0xFF63D6A3,
                          )
                        : const Color(
                            0xFFB18CFF,
                          ),
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                    height: 1.3,
                    color: event.isCompleted
                        ? const Color(
                            0xFF8291AA,
                          )
                        : Colors.white,
                    decoration:
                        event.isCompleted
                            ? TextDecoration
                                .lineThrough
                            : null,
                  ),
                ),

                if (event.description
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: event.isCompleted
                          ? const Color(
                              0xFF718097,
                            )
                          : const Color(
                              0xFFB6C5E0,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          PopupMenuButton<String>(
            tooltip: 'Действия',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              }

              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Редактировать',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Удалить',
                    ),
                  ],
                ),
              ),
            ],
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
            color:
                const Color(0xFF2B7FFF),
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