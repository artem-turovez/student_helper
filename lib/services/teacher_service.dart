import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/teacher.dart';

class TeacherService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<List<Teacher>> getTeachersForGroup(
    String groupId,
  ) async {
    if (groupId.trim().isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _firestore
            .collection('teachers')
            .where(
              'groupIds',
              arrayContains: groupId,
            )
            .get();

    final List<Teacher> teachers = snapshot.docs
        .map(
          (document) => Teacher.fromFirestore(
            document.id,
            document.data(),
          ),
        )
        .toList();

    teachers.sort(
      (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
    );

    return teachers;
  }

  Future<Teacher?> getTeacherById(
    String teacherId,
  ) async {
    if (teacherId.trim().isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>>
        document = await _firestore
            .collection('teachers')
            .doc(teacherId)
            .get();

    if (!document.exists) {
      return null;
    }

    final Map<String, dynamic>? data =
        document.data();

    if (data == null) {
      return null;
    }

    return Teacher.fromFirestore(
      document.id,
      data,
    );
  }
}