import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<Map<String, dynamic>?> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return document.data();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;

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

    if (nameParts.isNotEmpty && nameParts.first.isNotEmpty) {
      return nameParts.first;
    }

    return 'Студент';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: loadUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final data = snapshot.data;

        final String fullName =
            data?['name']?.toString() ?? 'Студент';

        final String firstName = getFirstName(fullName);

        final String? groupId =
            data?['groupId']?.toString();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              Text(
                '${getGreeting()}, $firstName!',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                groupId == null
                    ? 'Учебная группа пока не назначена'
                    : 'Группа: $groupId',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFB6C5E0),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Следующее занятие',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10213D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Расписание пока отсутствует',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'После загрузки расписания здесь появится ближайшее занятие.',
                      style: TextStyle(
                        color: Color(0xFFB6C5E0),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Ближайшие события',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10213D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Ближайших учебных событий пока нет.',
                  style: TextStyle(
                    color: Color(0xFFB6C5E0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}