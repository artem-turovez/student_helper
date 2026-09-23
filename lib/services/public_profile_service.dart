import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_profile.dart';

class PublicProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<PublicProfile>> getClassmates({
    required String groupId,
    required String currentUserId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('publicProfiles')
        .where('groupId', isEqualTo: groupId)
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
    final Set<String> normalizedGroupIds = groupIds
        .map((groupId) => groupId.trim())
        .where((groupId) => groupId.isNotEmpty)
        .toSet();

    if (normalizedGroupIds.isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('publicProfiles')
        .get();

    final List<PublicProfile> profiles = snapshot.docs
        .map((document) => PublicProfile.fromFirestore(document))
        .where(
          (profile) =>
              profile.groupId != null &&
              normalizedGroupIds.contains(profile.groupId!.trim()),
        )
        .toList();

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
}
