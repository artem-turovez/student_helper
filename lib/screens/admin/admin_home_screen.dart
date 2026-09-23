import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../../services/admin_api_service.dart';
import '../auth/start_screen.dart';
import 'schedule_management_screen.dart';
import 'teachers_management_screen.dart';
import 'users_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _isSyncing = false;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartScreen()),
      (route) => false,
    );
  }

  void _openSchedule() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ScheduleManagementScreen()));
  }

  void _openUsers() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const UsersManagementScreen()));
  }

  void _openTeachers() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TeachersManagementScreen()));
  }

  Future<void> _syncPublicProfiles() async {
    if (_isSyncing) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Синхронизация учащихся'),
          content: const Text(
            'Будут обновлены публичные '
            'профили всех учащихся на '
            'основе данных пользователей.\n\n'
            'Это позволит корректно '
            'отображать одногруппников '
            'и учащихся в контактах '
            'преподавателей.',
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
              child: const Text('Синхронизировать'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final PublicProfilesSyncResult result =
          await AdminApiService.syncPublicProfiles();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.message}\n'
            'Учащихся обработано: '
            '${result.studentCount}',
          ),
        ),
      );
    } on AdminApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось выполнить '
            'синхронизацию: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _signOut,
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    AppBrand.logoPath,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(width: 14),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppBrand.appName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          'Администратор',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              const Text('Управление', style: AppTheme.pageTitle),

              const SizedBox(height: 8),

              const Text(
                'Управление данными '
                'приложения и расписанием '
                'колледжа.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 28),

              _AdminCard(
                icon: Icons.calendar_month_rounded,
                title: 'Расписание',
                description:
                    'Загрузка и публикация '
                    'расписания из '
                    'PDF-файла.',
                onTap: _openSchedule,
              ),

              const SizedBox(height: 14),

              _AdminCard(
                icon: Icons.groups_rounded,
                title: 'Пользователи',
                description:
                    'Управление учащимися, '
                    'преподавателями и '
                    'администраторами.',
                onTap: _openUsers,
              ),

              const SizedBox(height: 14),

              _AdminCard(
                icon: Icons.sync_rounded,
                title: 'Синхронизация учащихся',
                description: _isSyncing
                    ? 'Выполняется '
                          'синхронизация...'
                    : 'Обновление данных '
                          'учащихся для '
                          'контактов и групп.',
                onTap: _isSyncing ? null : _syncPublicProfiles,
                isLoading: _isSyncing,
              ),

              const SizedBox(height: 14),

              _AdminCard(
                icon: Icons.school_rounded,
                title: 'Преподаватели',
                description:
                    'Просмотр данных '
                    'преподавателей и '
                    'привязки аккаунтов.',
                onTap: _openTeachers,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(icon, color: AppTheme.primaryBlue),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              if (!isLoading)
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
