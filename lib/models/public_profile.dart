import 'package:cloud_firestore/cloud_firestore.dart';

class PublicProfile {
  final String id;
  final String name;
  final String? groupId;

  final String? email;
  final String? phone;
  final String? telegram;
  final String? photoUrl;

  final bool showEmail;
  final bool showPhone;
  final bool showTelegram;

  const PublicProfile({
    required this.id,
    required this.name,
    this.groupId,
    this.email,
    this.phone,
    this.telegram,
    this.photoUrl,
    this.showEmail = false,
    this.showPhone = false,
    this.showTelegram = false,
  });

  factory PublicProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw Exception('Публичный профиль ${document.id} не содержит данных');
    }

    return PublicProfile(
      id: document.id,
      name: data['name']?.toString() ?? '',
      groupId: data['groupId']?.toString(),
      email: data['email']?.toString(),
      phone: data['phone']?.toString(),
      telegram: data['telegram']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      showEmail: data['showEmail'] == true,
      showPhone: data['showPhone'] == true,
      showTelegram: data['showTelegram'] == true,
    );
  }
}
