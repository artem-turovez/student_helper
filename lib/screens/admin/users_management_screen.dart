import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/admin_api_service.dart';
import 'user_create_screen.dart';
import 'user_edit_screen.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<AdminUser> _users = const [];

  @override
  void initState() {
    super.initState();

    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<AdminUser> users = await AdminApiService.getUsers();

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
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
            'пользователей: $error';

        _isLoading = false;
      });
    }
  }

  Future<void> _createUser() async {
    final AdminUser? createdUser = await Navigator.of(context).push<AdminUser>(
      MaterialPageRoute(builder: (context) => const UserCreateScreen()),
    );

    if (createdUser == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Пользователь '
          '${createdUser.displayName} создан.',
        ),
      ),
    );

    await _loadUsers();
  }

  Future<void> _openUser(AdminUser user) async {
    final String? result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => UserEditScreen(user: user)),
    );

    if (result == null || !mounted) {
      return;
    }

    await _loadUsers();

    if (!mounted) {
      return;
    }

    if (result == 'deleted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пользователь ${user.displayName} удалён.')),
      );

      return;
    }

    if (result == 'updated') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные пользователя сохранены.')),
      );
    }
  }

  String _roleTitle(String? role) {
    switch (role) {
      case 'admin':
        return 'Администратор';

      case 'teacher':
        return 'Преподаватель';

      case 'student':
        return 'Учащийся';

      default:
        return 'Роль не указана';
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;

      case 'teacher':
        return Icons.school_rounded;

      case 'student':
        return Icons.person_rounded;

      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _createUser,
            tooltip: 'Добавить пользователя',
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _loadUsers, child: _buildContent()),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _createUser,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Добавить пользователя'),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          const SizedBox(height: 80),

          const Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: AppTheme.secondaryText,
          ),

          const SizedBox(height: 18),

          const Text(
            'Не удалось загрузить пользователей',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryText,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppTheme.secondaryBodyText,
          ),

          const SizedBox(height: 24),

          Center(
            child: FilledButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ),
        ],
      );
    }

    if (_users.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          const SizedBox(height: 60),

          const Icon(
            Icons.group_off_rounded,
            size: 56,
            color: AppTheme.secondaryText,
          ),

          const SizedBox(height: 18),

          const Text(
            'Пользователей пока нет',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryText,
            ),
          ),

          const SizedBox(height: 24),

          _buildAddButton(),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        const Text('Все пользователи', style: AppTheme.pageTitle),

        const SizedBox(height: 8),

        Text(
          'Всего пользователей: '
          '${_users.length}',
          style: AppTheme.secondaryBodyText,
        ),

        const SizedBox(height: 8),

        const Text(
          'Создавайте новые аккаунты '
          'или нажмите на пользователя, '
          'чтобы изменить его данные.',
          style: AppTheme.secondaryBodyText,
        ),

        const SizedBox(height: 20),

        _buildAddButton(),

        const SizedBox(height: 24),

        ..._users.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _UserCard(
              user: user,
              roleTitle: _roleTitle(user.role),
              roleIcon: _roleIcon(user.role),
              onTap: () => _openUser(user),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.roleTitle,
    required this.roleIcon,
    required this.onTap,
  });

  final AdminUser user;
  final String roleTitle;
  final IconData roleIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? email = user.email;
    final String? groupId = user.groupId;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(roleIcon, color: AppTheme.primaryBlue),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
                    ),

                    if (email != null &&
                        email.isNotEmpty &&
                        email != user.displayName) ...[
                      const SizedBox(height: 5),

                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(icon: roleIcon, text: roleTitle),

                        if (groupId != null && groupId.isNotEmpty)
                          _InfoChip(icon: Icons.groups_rounded, text: groupId),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

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
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryBlue),

          const SizedBox(width: 5),

          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
