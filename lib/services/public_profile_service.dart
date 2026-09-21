import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_profile.dart';

class PublicProfileService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<List<PublicProfile>> getClassmates({
    required String groupId,
    required String currentUserId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
            .collection('publicProfiles')
            .where(
              'groupId',
              isEqualTo: groupId,
            )
            .get();

    final List<PublicProfile> profiles = snapshot.docs
        .where(
          (document) =>
              document.id != currentUserId,
        )
        .map(
          (document) =>
              PublicProfile.fromFirestore(document),
        )
        .toList();

    profiles.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(
            b.name.toLowerCase(),
          ),
    );

    return profiles;
  }
}