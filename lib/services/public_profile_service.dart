import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_profile.dart';

class PublicProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<PublicProfile?> getProfileById(String userId) async {
    final String normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('publicProfiles')
        .doc(normalizedUserId)
        .get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return PublicProfile.fromFirestore(document);
  }

  Future<List<PublicProfile>> getClassmates({
    required String groupId,
    required String currentUserId,
  }) async {
    final String normalizedGroupId = groupId.trim();

    if (normalizedGroupId.isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('publicProfiles')
        .where('groupId', isEqualTo: normalizedGroupId)
        .get();

    final List<PublicProfile> profiles = snapshot.docs
        .where((document) => document.id != currentUserId)
        .map((document) => PublicProfile.fromFirestore(document))
        .toList();

    profiles.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return profiles;
  }

  Future<List<PublicProfile>> getStudentsForGroups({
    required List<String> groupIds,
  }) async {
    final List<String> normalizedGroupIds = groupIds
        .map((groupId) => groupId.trim())
        .where((groupId) => groupId.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedGroupIds.isEmpty) {
      return [];
    }

    final List<PublicProfile> profiles = [];

    for (final String groupId in normalizedGroupIds) {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('publicProfiles')
          .where('groupId', isEqualTo: groupId)
          .get();

      profiles.addAll(
        snapshot.docs.map((document) => PublicProfile.fromFirestore(document)),
      );
    }

    profiles.sort((a, b) {
      final String firstGroup = a.groupId?.toLowerCase() ?? '';

      final String secondGroup = b.groupId?.toLowerCase() ?? '';

      final int groupComparison = firstGroup.compareTo(secondGroup);

      if (groupComparison != 0) {
        return groupComparison;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return profiles;
  }

  Future<void> updateOwnProfile({
    required String userId,
    required String phone,
    required String telegram,
    required bool showEmail,
    required bool showPhone,
    required bool showTelegram,
  }) async {
    final String normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError('Не указан идентификатор пользователя.');
    }

    await _firestore.collection('publicProfiles').doc(normalizedUserId).update({
      'phone': phone.trim().isEmpty ? null : phone.trim(),
      'telegram': telegram.trim().isEmpty ? null : telegram.trim(),
      'showEmail': showEmail,
      'showPhone': showPhone,
      'showTelegram': showTelegram,
    });
  }
}
