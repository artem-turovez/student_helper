import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/academic_event.dart';
import '../../models/personal_event.dart';
import '../../services/academic_event_service.dart';
import '../../services/personal_event_service.dart';
import '../student/create_personal_event_screen.dart';
import 'create_academic_event_screen.dart';

class TeacherCalendarScreen extends StatefulWidget {
  const TeacherCalendarScreen({super.key});

  @override
  State<TeacherCalendarScreen> createState() => _TeacherCalendarScreenState();
}

class _TeacherCalendarScreenState extends State<TeacherCalendarScreen> {
  final AcademicEventService _academicEventService = AcademicEventService();
  final PersonalEventService _personalEventService = PersonalEventService();

  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  String? _teacherId;

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

    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _loadTeacher();
  }

  Future<void> _loadTeacher() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!document.exists) {
        throw Exception('Профиль преподавателя не найден');
      }

      final Map<String, dynamic>? data = document.data();

      final String teacherId = data?['teacherId']?.toString().trim() ?? '';

      if (teacherId.isEmpty) {
        throw Exception('Преподаватель не привязан к профилю');
      }

      _teacherId = teacherId;

      await _loadEvents();
    } catch (error) {
      debugPrint('Ошибка получения преподавателя для календаря: $error');

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
    final String? teacherId = _teacherId;
    final User? user = FirebaseAuth.instance.currentUser;

    if (teacherId == null || user == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final List<dynamic> results = await Future.wait([
        _academicEventService.getTeacherEventsForMonth(
          teacherId: teacherId,
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
      debugPrint('Ошибка загрузки событий календаря преподавателя: $error');

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

  Future<void> _openCreateEventMenu() async {
    final String? teacherId = _teacherId;

    if (teacherId == null || teacherId.trim().isEmpty) {
      _showMessage('Преподаватель не привязан к профилю');
      return;
    }

    final String? eventType = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 8, 14),
                  child: Text('Добавить событие', style: AppTheme.sectionTitle),
                ),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  title: const Text('Учебное событие'),
                  subtitle: const Text('Для группы и занятия преподавателя'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop('academic');
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.personalEvent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      color: AppTheme.personalEvent,
                    ),
                  ),
                  title: const Text('Личное событие'),
                  subtitle: const Text('Будет видно только в вашем календаре'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop('personal');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || eventType == null) {
      return;
    }

    if (eventType == 'academic') {
      await _openCreateAcademicEvent();
      return;
    }

    if (eventType == 'personal') {
      await _openCreatePersonalEvent();
    }
  }

  Future<void> _openCreateAcademicEvent() async {
    final String? teacherId = _teacherId;

    if (teacherId == null || teacherId.trim().isEmpty) {
      return;
    }

    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateAcademicEventScreen(
          teacherId: teacherId,
          initialDate: _selectedDate,
        ),
      ),
    );

    if (changed == true) {
      await _loadEvents();
    }
  }

  Future<void> _editAcademicEvent(AcademicEvent event) async {
    final String? teacherId = _teacherId;

    if (teacherId == null || teacherId.trim().isEmpty) {
      _showMessage('Преподаватель не привязан к профилю');
      return;
    }

    if (event.id?.trim().isEmpty != false) {
      _showMessage('Не удалось определить учебное событие');
      return;
    }

    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateAcademicEventScreen(
          teacherId: teacherId,
          initialDate: event.date,
          event: event,
        ),
      ),
    );

    if (changed == true) {
      await _loadEvents();
    }
  }

  Future<void> _deleteAcademicEvent(AcademicEvent event) async {
    final String eventId = event.id?.trim() ?? '';

    if (eventId.isEmpty) {
      _showMessage('Не удалось определить учебное событие');
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить учебное событие?'),
          content: Text(
            'Событие «${event.title}» будет удалено '
            'без возможности восстановления.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _academicEventService.deleteAcademicEvent(eventId: eventId);

      await _loadEvents();

      if (!mounted) {
        return;
      }

      _showMessage('Учебное событие удалено');
    } on FirebaseException catch (error) {
      debugPrint(
        'Ошибка Firebase при удалении учебного события: '
        '${error.code} | ${error.message}',
      );

      if (!mounted) {
        return;
      }

      if (error.code == 'permission-denied') {
        _showMessage('Нет разрешения на удаление учебного события');
      } else if (error.code == 'unavailable') {
        _showMessage('Нет подключения к серверу. Попробуйте позже');
      } else {
        _showMessage('Не удалось удалить учебное событие');
      }
    } catch (error) {
      debugPrint('Ошибка удаления учебного события: $error');

      if (!mounted) {
        return;
      }

      _showMessage('Не удалось удалить учебное событие');
    }
  }

  Future<void> _openCreatePersonalEvent() async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreatePersonalEventScreen(initialDate: _selectedDate),
      ),
    );

    if (changed == true) {
      await _loadEvents();
    }
  }

  Future<void> _editPersonalEvent(PersonalEvent event) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreatePersonalEventScreen(initialDate: event.date, event: event),
      ),
    );

    if (changed == true) {
      await _loadEvents();
    }
  }

  Future<void> _togglePersonalEvent(PersonalEvent event) async {
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
      debugPrint('Ошибка изменения статуса события: $error');

      if (!mounted) {
        return;
      }

      _showMessage('Не удалось изменить статус события');
    }
  }

  Future<void> _deletePersonalEvent(PersonalEvent event) async {
    final String? eventId = event.id;

    if (eventId == null) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить событие?'),
          content: Text(
            'Событие «${event.title}» будет удалено '
            'без возможности восстановления.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _personalEventService.deleteEvent(eventId: eventId);

      await _loadEvents();

      if (!mounted) {
        return;
      }

      _showMessage('Событие удалено');
    } catch (error) {
      debugPrint('Ошибка удаления события: $error');

      if (!mounted) {
        return;
      }

      _showMessage('Не удалось удалить событие');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _previousMonth() async {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);

      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });

    await _loadEvents();
  }

  Future<void> _nextMonth() async {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);

      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });

    await _loadEvents();
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _hasAcademicEventsOnDay(DateTime date) {
    return _academicEvents.any((event) => _isSameDay(event.date, date));
  }

  bool _hasPersonalEventsOnDay(DateTime date) {
    return _personalEvents.any((event) => _isSameDay(event.date, date));
  }

  List<AcademicEvent> _getAcademicEventsForSelectedDay() {
    return _academicEvents
        .where((event) => _isSameDay(event.date, _selectedDate))
        .toList();
  }

  List<PersonalEvent> _getPersonalEventsForSelectedDay() {
    final List<PersonalEvent> events = _personalEvents
        .where((event) => _isSameDay(event.date, _selectedDate))
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

    final int emptyDaysBefore = firstDay.weekday - 1;

    final List<DateTime?> days = [];

    for (int i = 0; i < emptyDaysBefore; i++) {
      days.add(null);
    }

    for (int day = 1; day <= daysInMonth; day++) {
      days.add(DateTime(_visibleMonth.year, _visibleMonth.month, day));
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
    final List<DateTime?> calendarDays = _getCalendarDays();

    final List<AcademicEvent> academicEvents =
        _getAcademicEventsForSelectedDay();

    final List<PersonalEvent> personalEvents =
        _getPersonalEventsForSelectedDay();

    final bool hasSelectedEvents =
        academicEvents.isNotEmpty || personalEvents.isNotEmpty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadEvents,
        color: AppTheme.primaryBlue,
        backgroundColor: AppTheme.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            24,
            AppTheme.screenPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Календарь', style: AppTheme.pageTitle),
                  ),
                  IconButton.filled(
                    onPressed: _openCreateEventMenu,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    tooltip: 'Добавить событие',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _CalendarCard(
                visibleMonth: _visibleMonth,
                selectedDate: _selectedDate,
                calendarDays: calendarDays,
                monthName: _monthNames[_visibleMonth.month - 1],
                weekdays: _weekdays,
                onPrevious: _previousMonth,
                onNext: _nextMonth,
                isSameDay: _isSameDay,
                hasAcademicEvents: _hasAcademicEventsOnDay,
                hasPersonalEvents: _hasPersonalEventsOnDay,
                onSelectDate: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),

              const SizedBox(height: 28),

              Text(
                'События на ${_selectedDate.day} '
                '${_monthNamesGenitive[_selectedDate.month - 1]}',
                style: AppTheme.sectionTitle,
              ),

              const SizedBox(height: 14),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_hasError)
                const _CalendarMessageCard(
                  icon: Icons.error_outline,
                  iconColor: AppTheme.danger,
                  title: 'Не удалось загрузить события',
                  description: 'Попробуйте обновить календарь.',
                )
              else if (!hasSelectedEvents)
                const _CalendarMessageCard(
                  icon: Icons.event_note_outlined,
                  iconColor: AppTheme.primaryBlue,
                  title: 'Событий пока нет',
                  description: 'На выбранную дату ничего не запланировано.',
                )
              else ...[
                if (academicEvents.isNotEmpty) ...[
                  const _EventSectionTitle(
                    title: 'Учебные события',
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 10),
                  ...academicEvents.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AcademicEventCard(
                        event: event,
                        icon: _getEventIcon(event.type),
                        onEdit: () => _editAcademicEvent(event),
                        onDelete: () => _deleteAcademicEvent(event),
                      ),
                    ),
                  ),
                ],
                if (personalEvents.isNotEmpty) ...[
                  if (academicEvents.isNotEmpty) const SizedBox(height: 14),
                  const _EventSectionTitle(
                    title: 'Личные события',
                    color: AppTheme.personalEvent,
                  ),
                  const SizedBox(height: 10),
                  ...personalEvents.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PersonalEventCard(
                        event: event,
                        onToggle: () => _togglePersonalEvent(event),
                        onEdit: () => _editPersonalEvent(event),
                        onDelete: () => _deletePersonalEvent(event),
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

class _CalendarCard extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<DateTime?> calendarDays;
  final String monthName;
  final List<String> weekdays;

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  final bool Function(DateTime, DateTime) isSameDay;
  final bool Function(DateTime) hasAcademicEvents;
  final bool Function(DateTime) hasPersonalEvents;

  final ValueChanged<DateTime> onSelectDate;

  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.calendarDays,
    required this.monthName,
    required this.weekdays,
    required this.onPrevious,
    required this.onNext,
    required this.isSameDay,
    required this.hasAcademicEvents,
    required this.hasPersonalEvents,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MonthArrow(
                icon: Icons.chevron_left_rounded,
                onPressed: onPrevious,
              ),
              Expanded(
                child: Text(
                  '$monthName ${visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: AppTheme.sectionTitle,
                ),
              ),
              _MonthArrow(icon: Icons.chevron_right_rounded, onPressed: onNext),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: weekdays.map((weekday) {
              return Expanded(
                child: Center(
                  child: Text(
                    weekday,
                    style: AppTheme.labelText.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final DateTime? day = calendarDays[index];

              if (day == null) {
                return const SizedBox();
              }

              final bool selected = isSameDay(day, selectedDate);
              final bool today = isSameDay(day, DateTime.now());
              final bool academic = hasAcademicEvents(day);
              final bool personal = hasPersonalEvents(day);

              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                child: InkWell(
                  onTap: () => onSelectDate(day),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primaryBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      border: today && !selected
                          ? Border.all(color: AppTheme.primaryBlue)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected || today
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected
                                ? Colors.white
                                : AppTheme.primaryText,
                          ),
                        ),
                        if (academic || personal)
                          Positioned(
                            bottom: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (academic)
                                  _EventDot(
                                    isSelected: selected,
                                    isPersonal: false,
                                  ),
                                if (academic && personal)
                                  const SizedBox(width: 3),
                                if (personal)
                                  _EventDot(
                                    isSelected: selected,
                                    isPersonal: true,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MonthArrow({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
        foregroundColor: AppTheme.primaryBlue,
      ),
      icon: Icon(icon),
    );
  }
}

class _EventDot extends StatelessWidget {
  final bool isSelected;
  final bool isPersonal;

  const _EventDot({required this.isSelected, required this.isPersonal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white
            : isPersonal
            ? AppTheme.personalEvent
            : AppTheme.primaryBlue,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EventSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _EventSectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTheme.cardTitle),
      ],
    );
  }
}

class _AcademicEventCard extends StatelessWidget {
  final AcademicEvent event;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AcademicEventCard({
    required this.event,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final String subject = event.subject.trim().isEmpty
        ? 'Предмет не указан'
        : event.subject.trim();

    final String group = event.groupId.trim().isEmpty
        ? 'Группа не указана'
        : 'Группа ${event.groupId.trim()}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventIconBox(icon: icon, color: AppTheme.primaryBlue),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.type,
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(event.title, style: AppTheme.cardTitle),

                const SizedBox(height: 10),

                _AcademicEventInfoRow(
                  icon: Icons.menu_book_outlined,
                  text: subject,
                ),

                const SizedBox(height: 6),

                _AcademicEventInfoRow(icon: Icons.groups_outlined, text: group),

                if (event.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(event.description, style: AppTheme.secondaryBodyText),
                ],
              ],
            ),
          ),

          PopupMenuButton<String>(
            tooltip: 'Действия',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.secondaryText,
            ),
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
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 10),
                    Text('Редактировать'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text('Удалить', style: TextStyle(color: AppTheme.danger)),
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

class _AcademicEventInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AcademicEventInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppTheme.secondaryText),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: AppTheme.secondaryBodyText)),
      ],
    );
  }
}

class _PersonalEventCard extends StatelessWidget {
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
    final Color eventColor = event.isCompleted
        ? AppTheme.success
        : AppTheme.personalEvent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: eventColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.smallRadius),
              ),
              child: Icon(
                event.isCompleted
                    ? Icons.check_rounded
                    : Icons.event_note_outlined,
                color: eventColor,
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.isCompleted ? 'Выполнено' : 'Личное событие',
                  style: TextStyle(
                    color: eventColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  event.title,
                  style: AppTheme.cardTitle.copyWith(
                    color: event.isCompleted
                        ? AppTheme.secondaryText
                        : AppTheme.primaryText,
                    decoration: event.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),

                if (event.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.description,
                    style: AppTheme.secondaryBodyText.copyWith(
                      decoration: event.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),

          PopupMenuButton<String>(
            tooltip: 'Действия',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.secondaryText,
            ),
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
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 10),
                    Text('Редактировать'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text('Удалить', style: TextStyle(color: AppTheme.danger)),
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

class _EventIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _EventIconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _CalendarMessageCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _CalendarMessageCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          _EventIconBox(icon: icon, color: iconColor),

          const SizedBox(height: 14),

          Text(title, textAlign: TextAlign.center, style: AppTheme.cardTitle),

          const SizedBox(height: 6),

          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTheme.secondaryBodyText,
          ),
        ],
      ),
    );
  }
}
