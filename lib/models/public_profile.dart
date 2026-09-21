import 'package:cloud_firestore/cloud_firestore.dart';

class PublicProfile {
  final String id;
  final String name;
  final String? groupId;

  final String? email;
  final String? phone;
  final String? telegram;
  final String? photoUrl;

  const PublicProfile({
    required this.id,
    required this.name,
    this.groupId,
    this.email,
    this.phone,
    this.telegram,
    this.photoUrl,
  });

  factory PublicProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw Exception(
        'Публичный профиль ${document.id} не содержит данных',
      );
    }

    return PublicProfile(
      id: document.id,
      name: data['name']?.toString() ?? '',
      groupId: data['groupId']?.toString(),
      email: data['email']?.toString(),
      phone: data['phone']?.toString(),
      telegram: data['telegram']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
    );
  }
}