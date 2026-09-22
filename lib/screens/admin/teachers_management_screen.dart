import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/admin_api_service.dart';

class TeachersManagementScreen extends StatefulWidget {
  const TeachersManagementScreen({super.key});

  @override
  State<TeachersManagementScreen> createState() =>
      _TeachersManagementScreenState();
}

class _TeachersManagementScreenState extends State<TeachersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<AdminTeacher> _teachers = <AdminTeacher>[];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);

    _searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<AdminTeacher> teachers = await AdminApiService.getTeachers();

      if (!mounted) {
        return;
      }

      setState(() {
        _teachers = teachers;
        _isLoading = false;
      });
    } on AdminApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Не удалось загрузить '
            'преподавателей: $error';

        _isLoading = false;
      });
    }
  }

  List<AdminTeacher> get _filteredTeachers {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _teachers;
    }

    return _teachers.where((AdminTeacher teacher) {
      final String groups = teacher.groupIds.join(' ').toLowerCase();

      final String email = (teacher.email ?? '').toLowerCase();

      final String department = (teacher.department ?? '').toLowerCase();

      return teacher.name.toLowerCase().contains(query) ||
          teacher.teacherId.toLowerCase().contains(query) ||
          groups.contains(query) ||
          email.contains(query) ||
          department.contains(query);
    }).toList();
  }

  int get _linkedCount {
    return _teachers.where((teacher) => teacher.linked).length;
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminTeacher> filteredTeachers = _filteredTeachers;

    return Scaffold(
      appBar: AppBar(title: const Text('Преподаватели')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTeachers,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              const Text('Преподаватели', style: AppTheme.pageTitle),

              const SizedBox(height: 8),

              const Text(
                'Преподаватели колледжа '
                'и состояние привязки '
                'их аккаунтов.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 22),

              if (!_isLoading && _errorMessage == null)
                _StatisticsCard(total: _teachers.length, linked: _linkedCount),

              if (!_isLoading && _errorMessage == null)
                const SizedBox(height: 18),

              if (!_isLoading && _errorMessage == null)
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск преподавателя',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            tooltip: 'Очистить',
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),

              if (!_isLoading && _errorMessage == null)
                const SizedBox(height: 20),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                _ErrorCard(message: _errorMessage!, onRetry: _loadTeachers)
              else if (filteredTeachers.isEmpty)
                const _EmptyCard()
              else ...[
                Text(
                  _searchController.text.trim().isEmpty
                      ? 'Все преподаватели'
                      : 'Найдено: '
                            '${filteredTeachers.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),

                const SizedBox(height: 12),

                ...filteredTeachers.map(
                  (teacher) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TeacherCard(teacher: teacher),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.total, required this.linked});

  final int total;
  final int linked;

  @override
  Widget build(BuildContext context) {
    final int unlinked = total - linked;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatisticItem(
              value: total.toString(),
              label: 'Всего',
              icon: Icons.school_rounded,
            ),
          ),
          Expanded(
            child: _StatisticItem(
              value: linked.toString(),
              label: 'Привязано',
              icon: Icons.link_rounded,
            ),
          ),
          Expanded(
            child: _StatisticItem(
              value: unlinked.toString(),
              label: 'Без аккаунта',
              icon: Icons.person_off_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  const _StatisticItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 22),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
        ),
      ],
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher});

  final AdminTeacher teacher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
                    ),

                    if (teacher.department != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        teacher.department!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (teacher.groupIds.isNotEmpty) ...[
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.groups_2_rounded,
                  size: 18,
                  color: AppTheme.secondaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teacher.groupIds.join(', '),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (teacher.email != null) ...[
            const SizedBox(height: 10),

            _InfoRow(icon: Icons.email_outlined, text: teacher.email!),
          ],

          if (teacher.phone != null) ...[
            const SizedBox(height: 10),

            _InfoRow(icon: Icons.phone_outlined, text: teacher.phone!),
          ],

          if (teacher.telegram != null) ...[
            const SizedBox(height: 10),

            _InfoRow(icon: Icons.send_rounded, text: teacher.telegram!),
          ],

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: teacher.linked
                  ? AppTheme.primaryBlue.withValues(alpha: 0.10)
                  : AppTheme.secondaryText.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  teacher.linked ? Icons.link_rounded : Icons.link_off_rounded,
                  size: 19,
                  color: teacher.linked
                      ? AppTheme.primaryBlue
                      : AppTheme.secondaryText,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    teacher.linked
                        ? _linkedText(teacher)
                        : 'Аккаунт '
                              'не привязан',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: teacher.linked
                          ? AppTheme.primaryBlue
                          : AppTheme.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _linkedText(AdminTeacher teacher) {
    final String? userName = teacher.userName;

    if (userName != null && userName.isNotEmpty) {
      return 'Аккаунт привязан: '
          '$userName';
    }

    final String? userEmail = teacher.userEmail;

    if (userEmail != null && userEmail.isNotEmpty) {
      return 'Аккаунт привязан: '
          '$userEmail';
    }

    return 'Аккаунт привязан';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: AppTheme.secondaryText,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.secondaryBodyText,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              onRetry();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: AppTheme.secondaryText,
          ),
          SizedBox(height: 12),
          Text(
            'Преподаватели '
            'не найдены.',
            style: AppTheme.secondaryBodyText,
          ),
        ],
      ),
    );
  }
}
