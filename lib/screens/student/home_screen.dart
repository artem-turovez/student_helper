import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<Map<String, dynamic>?> loadUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> document =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    return document.data();
  }

  String getGreeting() {
    final int hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Доброе утро';
    }

    if (hour >= 12 && hour < 18) {
      return 'Добрый день';
    }

    if (hour >= 18 && hour < 23) {
      return 'Добрый вечер';
    }

    return 'Доброй ночи';
  }

  String getFirstName(String fullName) {
    final List<String> nameParts = fullName
        .trim()
        .split(RegExp(r'\s+'));

    if (nameParts.length >= 2) {
      return nameParts[1];
    }

    if (nameParts.isNotEmpty &&
        nameParts.first.isNotEmpty) {
      return nameParts.first;
    }

    return 'Студент';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: loadUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const _HomeMessage(
              icon: Icons.error_outline,
              title: 'Не удалось загрузить данные',
              description:
                  'Попробуйте открыть экран ещё раз.',
            );
          }

          final Map<String, dynamic>? data =
              snapshot.data;

          final String fullName =
              data?['name']?.toString() ??
                  'Студент';

          final String firstName =
              getFirstName(fullName);

          final String? groupId =
              data?['groupId']?.toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              24,
              AppTheme.screenPadding,
              32,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Главная',
                  style: AppTheme.pageTitle,
                ),

                const SizedBox(height: 28),

                Text(
                  '${getGreeting()}, $firstName!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  groupId == null ||
                          groupId.trim().isEmpty
                      ? 'Учебная группа пока не назначена'
                      : 'Группа $groupId',
                  style:
                      AppTheme.secondaryBodyText,
                ),

                const SizedBox(height: 30),

                const Text(
                  'Следующее занятие',
                  style: AppTheme.sectionTitle,
                ),

                const SizedBox(height: 12),

                const _HomeMessage(
                  icon:
                      Icons.calendar_today_outlined,
                  title:
                      'Расписание пока отсутствует',
                  description:
                      'После загрузки расписания здесь появится ближайшее занятие.',
                ),

                const SizedBox(height: 28),

                const Text(
                  'Ближайшие события',
                  style: AppTheme.sectionTitle,
                ),

                const SizedBox(height: 12),

                const _HomeMessage(
                  icon:
                      Icons.event_note_outlined,
                  title:
                      'Событий пока нет',
                  description:
                      'Ближайших учебных событий пока нет.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HomeMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(
                AppTheme.smallRadius,
              ),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryBlue,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.cardTitle,
                ),

                const SizedBox(height: 5),

                Text(
                  description,
                  style:
                      AppTheme.secondaryBodyText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}