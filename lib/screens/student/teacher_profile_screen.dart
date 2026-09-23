import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../models/teacher.dart';
import '../../services/schedule_service.dart';

class TeacherProfileScreen extends StatefulWidget {
  final Teacher teacher;

  const TeacherProfileScreen({super.key, required this.teacher});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final ScheduleService _scheduleService = ScheduleService();

  List<Lesson> _lessons = [];

  late DateTime _selectedDate;

  bool _isLoadingSchedule = true;
  bool _hasScheduleError = false;

  Teacher get teacher => widget.teacher;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    _selectedDate = DateTime(now.year, now.month, now.day);

    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    if (mounted) {
      setState(() {
        _isLoadingSchedule = true;
        _hasScheduleError = false;
      });
    }

    try {
      final List<Lesson> lessons = await _scheduleService
          .getTeacherLessonsForDay(teacherId: teacher.id, date: _selectedDate);

      lessons.sort((a, b) => a.number.compareTo(b.number));

      if (!mounted) {
        return;
      }

      setState(() {
        _lessons = lessons;
        _isLoadingSchedule = false;
        _hasScheduleError = false;
      });
    } catch (error) {
      debugPrint('Ошибка загрузки расписания преподавателя: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _lessons = [];
        _isLoadingSchedule = false;
        _hasScheduleError = true;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (selectedDate == null) {
      return;
    }

    final DateTime normalizedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    if (_isSameDay(normalizedDate, _selectedDate)) {
      return;
    }

    setState(() {
      _selectedDate = normalizedDate;
    });

    await _loadSchedule();
  }

  Future<void> _selectToday() async {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    if (_isSameDay(today, _selectedDate)) {
      return;
    }

    setState(() {
      _selectedDate = today;
    });

    await _loadSchedule();
  }

  bool _hasContacts() {
    return (teacher.showEmail && teacher.email.trim().isNotEmpty) ||
        (teacher.showPhone && teacher.phone.trim().isNotEmpty) ||
        (teacher.showTelegram && teacher.telegram.trim().isNotEmpty);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _isToday(DateTime date) {
    final DateTime now = DateTime.now();

    return _isSameDay(date, now);
  }

  String _getWeekdayName(int weekday) {
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

  String _getMonthName(int month) {
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

  String _formatDate(DateTime date) {
    return '${_getWeekdayName(date.weekday)}, '
        '${date.day} '
        '${_getMonthName(date.month)}';
  }

  String _formatShortDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Widget _buildDateSelector() {
    final bool isToday = _isToday(_selectedDate);

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _BlueIconBox(icon: Icons.calendar_month_outlined),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Выбранная дата', style: AppTheme.labelText),

                    const SizedBox(height: 4),

                    Text(_formatDate(_selectedDate), style: AppTheme.cardTitle),

                    const SizedBox(height: 3),

                    Text(
                      _formatShortDate(_selectedDate),
                      style: AppTheme.secondaryBodyText,
                    ),
                  ],
                ),
              ),

              if (isToday) ...[
                const SizedBox(width: 8),
                const _TodayBadge(),
              ] else ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _selectToday,
                  tooltip: 'Сегодня',
                  icon: const Icon(
                    Icons.today_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],

              const SizedBox(width: 2),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchedule() {
    if (_isLoadingSchedule) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasScheduleError) {
      return _ScheduleStateCard(
        icon: Icons.error_outline,
        iconColor: AppTheme.danger,
        title: 'Не удалось загрузить расписание',
        description:
            'Проверьте подключение к интернету '
            'и повторите попытку.',
        buttonText: 'Повторить',
        onPressed: _loadSchedule,
      );
    }

    if (_lessons.isEmpty) {
      return _ScheduleStateCard(
        icon: Icons.event_busy_outlined,
        iconColor: AppTheme.primaryBlue,
        title: 'Занятий нет',
        description: _isToday(_selectedDate)
            ? 'У преподавателя сегодня нет занятий.'
            : 'У преподавателя нет занятий '
                  'на выбранную дату.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _formatDate(_selectedDate),
                style: AppTheme.cardTitle,
              ),
            ),

            if (_isToday(_selectedDate)) const _TodayBadge(),
          ],
        ),

        const SizedBox(height: 10),

        ..._lessons.map((lesson) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TeacherLessonCard(lesson: lesson),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showEmail = teacher.showEmail && teacher.email.trim().isNotEmpty;

    final bool showPhone = teacher.showPhone && teacher.phone.trim().isNotEmpty;

    final bool showTelegram =
        teacher.showTelegram && teacher.telegram.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Преподаватель')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSchedule,
          color: AppTheme.primaryBlue,
          backgroundColor: AppTheme.card,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              24,
              AppTheme.screenPadding,
              32,
            ),
            children: [
              _TeacherHeader(teacher: teacher),

              const SizedBox(height: 28),

              const Text('Контактная информация', style: AppTheme.sectionTitle),

              const SizedBox(height: 14),

              if (showEmail)
                _InfoCard(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: teacher.email,
                ),

              if (showEmail && (showPhone || showTelegram))
                const SizedBox(height: 10),

              if (showPhone)
                _InfoCard(
                  icon: Icons.phone_outlined,
                  title: 'Телефон',
                  value: teacher.phone,
                ),

              if (showPhone && showTelegram) const SizedBox(height: 10),

              if (showTelegram)
                _InfoCard(
                  icon: Icons.send_outlined,
                  title: 'Telegram',
                  value: teacher.telegram,
                ),

              if (!_hasContacts()) const _EmptyContactsCard(),

              const SizedBox(height: 32),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Расписание преподавателя',
                      style: AppTheme.sectionTitle,
                    ),
                  ),

                  IconButton(
                    onPressed: _loadSchedule,
                    tooltip: 'Обновить',
                    icon: const Icon(
                      Icons.refresh,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _buildDateSelector(),

              const SizedBox(height: 18),

              _buildSchedule(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  final Teacher teacher;

  const _TeacherHeader({required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TeacherAvatar(teacher: teacher),

        const SizedBox(height: 18),

        Text(
          teacher.name,
          textAlign: TextAlign.center,
          style: AppTheme.pageTitle,
        ),

        if (teacher.department.trim().isNotEmpty) ...[
          const SizedBox(height: 8),

          Text(
            teacher.department,
            textAlign: TextAlign.center,
            style: AppTheme.secondaryBodyText,
          ),
        ],
      ],
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final Teacher teacher;

  const _TeacherAvatar({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = teacher.photoUrl;

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(
          photoUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.school_outlined,
        size: 44,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
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
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          _BlueIconBox(icon: icon),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelText),

                const SizedBox(height: 4),

                SelectableText(value, style: AppTheme.cardTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherLessonCard extends StatelessWidget {
  final Lesson lesson;

  const _TeacherLessonCard({required this.lesson});

  String _getGroup() {
    final String? groupId = lesson.groupId;

    if (groupId == null || groupId.trim().isEmpty) {
      return 'Группа не указана';
    }

    return groupId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                ),
                child: Center(
                  child: Text(
                    '${lesson.number}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.subject, style: AppTheme.cardTitle),

                    if (lesson.type.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Text(lesson.type, style: AppTheme.labelText),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1),

          const SizedBox(height: 14),

          _LessonDetailRow(
            icon: Icons.access_time_outlined,
            value: lesson.time,
          ),

          const SizedBox(height: 9),

          _LessonDetailRow(icon: Icons.groups_outlined, value: _getGroup()),

          const SizedBox(height: 9),

          _LessonDetailRow(
            icon: Icons.meeting_room_outlined,
            value: lesson.room,
          ),

          if (lesson.subgroup != null &&
              lesson.subgroup!.trim().isNotEmpty) ...[
            const SizedBox(height: 9),

            _LessonDetailRow(
              icon: Icons.group_work_outlined,
              value: 'Подгруппа: ${lesson.subgroup}',
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonDetailRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _LessonDetailRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryText),

        const SizedBox(width: 9),

        Expanded(child: Text(value, style: AppTheme.secondaryBodyText)),
      ],
    );
  }
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Сегодня',
        style: TextStyle(
          color: AppTheme.primaryBlue,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BlueIconBox extends StatelessWidget {
  final IconData icon;

  const _BlueIconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      ),
      child: Icon(icon, size: 21, color: AppTheme.primaryBlue),
    );
  }
}

class _EmptyContactsCard extends StatelessWidget {
  const _EmptyContactsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.secondaryText),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'Преподаватель не предоставил '
              'контактную информацию',
              style: AppTheme.secondaryBodyText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _ScheduleStateCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Icon(icon, size: 27, color: iconColor),
          ),

          const SizedBox(height: 14),

          Text(title, textAlign: TextAlign.center, style: AppTheme.cardTitle),

          const SizedBox(height: 6),

          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTheme.secondaryBodyText,
          ),

          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh),
                label: Text(buttonText!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
