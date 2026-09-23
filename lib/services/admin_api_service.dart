import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdminApiException implements Exception {
  const AdminApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminUser {
  const AdminUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.groupId,
    required this.teacherId,
    required this.createdAt,
  });

  final String uid;
  final String? name;
  final String? email;
  final String? role;
  final String? groupId;
  final String? teacherId;
  final DateTime? createdAt;

  String get displayName {
    final String? currentName = name;

    if (currentName != null && currentName.isNotEmpty) {
      return currentName;
    }

    final String? currentEmail = email;

    if (currentEmail != null && currentEmail.isNotEmpty) {
      return currentEmail;
    }

    return 'Пользователь';
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final String? createdAtString = json['createdAt'] as String?;

    return AdminUser(
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      groupId: json['groupId'] as String?,
      teacherId: json['teacherId'] as String?,
      createdAt: createdAtString == null
          ? null
          : DateTime.tryParse(createdAtString),
    );
  }
}

class AdminTeacher {
  const AdminTeacher({
    required this.teacherId,
    required this.name,
    required this.email,
    required this.phone,
    required this.telegram,
    required this.photoUrl,
    required this.department,
    required this.groupIds,
    required this.linked,
    required this.userUid,
    required this.userName,
    required this.userEmail,
  });

  final String teacherId;
  final String name;

  final String? email;
  final String? phone;
  final String? telegram;
  final String? photoUrl;
  final String? department;

  final List<String> groupIds;

  final bool linked;
  final String? userUid;
  final String? userName;
  final String? userEmail;

  factory AdminTeacher.fromJson(Map<String, dynamic> json) {
    final dynamic rawGroups = json['groupIds'];

    final List<String> groups;

    if (rawGroups is List) {
      groups = rawGroups
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    } else {
      groups = <String>[];
    }

    return AdminTeacher(
      teacherId: json['teacherId'] as String? ?? '',
      name: json['name'] as String? ?? 'Преподаватель',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      telegram: json['telegram'] as String?,
      photoUrl: json['photoUrl'] as String?,
      department: json['department'] as String?,
      groupIds: groups,
      linked: json['linked'] as bool? ?? false,
      userUid: json['userUid'] as String?,
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
    );
  }
}

class PublicProfilesSyncResult {
  const PublicProfilesSyncResult({
    required this.status,
    required this.message,
    required this.studentCount,
    required this.createdCount,
    required this.updatedCount,
    required this.skippedCount,
  });

  final String status;
  final String message;

  final int studentCount;
  final int createdCount;
  final int updatedCount;
  final int skippedCount;

  factory PublicProfilesSyncResult.fromJson(Map<String, dynamic> json) {
    final dynamic rawResult = json['result'];

    final Map<String, dynamic> result = rawResult is Map
        ? Map<String, dynamic>.from(rawResult)
        : <String, dynamic>{};

    return PublicProfilesSyncResult(
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      studentCount: result['students'] as int? ?? 0,
      createdCount: result['created'] as int? ?? 0,
      updatedCount: result['updated'] as int? ?? 0,
      skippedCount: result['skipped'] as int? ?? 0,
    );
  }
}

class ScheduleCheckResult {
  const ScheduleCheckResult({
    required this.status,
    required this.auditPassed,
    required this.fileName,
    required this.date,
    required this.lessonCount,
    required this.groupCount,
    required this.subjectCount,
    required this.teacherCount,
    required this.withoutTeacher,
    required this.withoutRoom,
    required this.issues,
  });

  final String status;
  final bool auditPassed;
  final String fileName;
  final String date;

  final int lessonCount;
  final int groupCount;
  final int subjectCount;
  final int teacherCount;
  final int withoutTeacher;
  final int withoutRoom;

  final List<String> issues;

  factory ScheduleCheckResult.fromJson(Map<String, dynamic> json) {
    return ScheduleCheckResult(
      status: json['status'] as String? ?? '',
      auditPassed: json['auditPassed'] as bool? ?? false,
      fileName: json['fileName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      lessonCount: json['lessonCount'] as int? ?? 0,
      groupCount: json['groupCount'] as int? ?? 0,
      subjectCount: json['subjectCount'] as int? ?? 0,
      teacherCount: json['teacherCount'] as int? ?? 0,
      withoutTeacher: json['withoutTeacher'] as int? ?? 0,
      withoutRoom: json['withoutRoom'] as int? ?? 0,
      issues: (json['issues'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class SchedulePublishResult {
  const SchedulePublishResult({
    required this.status,
    required this.message,
    required this.fileName,
    required this.date,
    required this.lessonCount,
    required this.previousLessonCount,
    required this.deletedLessonCount,
    required this.teachersCreated,
    required this.teachersUpdated,
  });

  final String status;
  final String message;
  final String fileName;
  final String date;

  final int lessonCount;
  final int previousLessonCount;
  final int deletedLessonCount;
  final int teachersCreated;
  final int teachersUpdated;

  factory SchedulePublishResult.fromJson(Map<String, dynamic> json) {
    return SchedulePublishResult(
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      lessonCount: json['lessonCount'] as int? ?? 0,
      previousLessonCount: json['previousLessonCount'] as int? ?? 0,
      deletedLessonCount: json['deletedLessonCount'] as int? ?? 0,
      teachersCreated: json['teachersCreated'] as int? ?? 0,
      teachersUpdated: json['teachersUpdated'] as int? ?? 0,
    );
  }
}

class AdminApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static Future<String> _getIdToken() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const AdminApiException('Пользователь не авторизован.');
    }

    final String? token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw const AdminApiException('Не удалось получить Firebase ID token.');
    }

    return token;
  }

  static Future<Map<String, dynamic>> checkAdmin() async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/admin/check'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      return data;
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось подключиться к серверу: '
        '$error',
      );
    }
  }

  static Future<List<AdminUser>> getUsers() async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/admin/users'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      final dynamic rawUsers = data['users'];

      if (rawUsers is! List) {
        throw const AdminApiException(
          'Сервер вернул некорректный '
          'список пользователей.',
        );
      }

      return rawUsers
          .whereType<Map>()
          .map((item) => AdminUser.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось загрузить '
        'пользователей: $error',
      );
    }
  }

  static Future<AdminUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required String? groupId,
    required String? teacherId,
  }) async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.post(
        Uri.parse('$_baseUrl/admin/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'groupId': groupId,
          'teacherId': teacherId,
        }),
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 201) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      final dynamic rawUser = data['user'];

      if (rawUser is! Map) {
        throw const AdminApiException(
          'Сервер вернул некорректные '
          'данные пользователя.',
        );
      }

      return AdminUser.fromJson(Map<String, dynamic>.from(rawUser));
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось создать '
        'пользователя: $error',
      );
    }
  }

  static Future<PublicProfilesSyncResult> syncPublicProfiles() async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.post(
        Uri.parse(
          '$_baseUrl/admin/users/'
          'sync-public-profiles',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      return PublicProfilesSyncResult.fromJson(data);
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось синхронизировать '
        'публичные профили: $error',
      );
    }
  }

  static Future<List<AdminTeacher>> getTeachers() async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/admin/teachers'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      final dynamic rawTeachers = data['teachers'];

      if (rawTeachers is! List) {
        throw const AdminApiException(
          'Сервер вернул некорректный '
          'список преподавателей.',
        );
      }

      return rawTeachers
          .whereType<Map>()
          .map((item) => AdminTeacher.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось загрузить '
        'преподавателей: $error',
      );
    }
  }

  static Future<AdminUser> updateUser({
    required String uid,
    required String? name,
    required String role,
    required String? groupId,
    required String? teacherId,
  }) async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.patch(
        Uri.parse(
          '$_baseUrl/admin/users/'
          '${Uri.encodeComponent(uid)}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': name,
          'role': role,
          'groupId': groupId,
          'teacherId': teacherId,
        }),
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      final dynamic rawUser = data['user'];

      if (rawUser is! Map) {
        throw const AdminApiException(
          'Сервер вернул некорректные '
          'данные пользователя.',
        );
      }

      return AdminUser.fromJson(Map<String, dynamic>.from(rawUser));
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось сохранить '
        'пользователя: $error',
      );
    }
  }

  static Future<void> deleteUser({required String uid}) async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.delete(
        Uri.parse(
          '$_baseUrl/admin/users/'
          '${Uri.encodeComponent(uid)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось удалить '
        'пользователя: $error',
      );
    }
  }

  static Future<AdminTeacher> updateTeacher({
    required String teacherId,
    required String name,
    required String? email,
    required String? phone,
    required String? telegram,
    required String? department,
  }) async {
    final String token = await _getIdToken();

    try {
      final http.Response response = await http.patch(
        Uri.parse(
          '$_baseUrl/admin/teachers/'
          '${Uri.encodeComponent(teacherId)}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'telegram': telegram,
          'department': department,
        }),
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      final dynamic rawTeacher = data['teacher'];

      if (rawTeacher is! Map) {
        throw const AdminApiException(
          'Сервер вернул некорректные '
          'данные преподавателя.',
        );
      }

      return AdminTeacher.fromJson(Map<String, dynamic>.from(rawTeacher));
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось сохранить '
        'преподавателя: $error',
      );
    }
  }

  static Future<ScheduleCheckResult> checkSchedule(PlatformFile file) async {
    final Map<String, dynamic> data = await _sendPdf(
      endpoint: '/schedule/check',
      file: file,
    );

    return ScheduleCheckResult.fromJson(data);
  }

  static Future<SchedulePublishResult> publishSchedule(
    PlatformFile file,
  ) async {
    final Map<String, dynamic> data = await _sendPdf(
      endpoint: '/schedule/publish',
      file: file,
    );

    return SchedulePublishResult.fromJson(data);
  }

  static Future<Map<String, dynamic>> _sendPdf({
    required String endpoint,
    required PlatformFile file,
  }) async {
    final String? filePath = file.path;

    if (filePath == null || filePath.isEmpty) {
      throw const AdminApiException(
        'Не удалось получить путь '
        'к выбранному PDF-файлу.',
      );
    }

    final String token = await _getIdToken();

    final Uri uri = Uri.parse('$_baseUrl$endpoint');

    final http.MultipartRequest request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: file.name),
    );

    try {
      final http.StreamedResponse streamedResponse = await request.send();

      final http.Response response = await http.Response.fromStream(
        streamedResponse,
      );

      final Map<String, dynamic> data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw AdminApiException(
          _extractErrorMessage(data, response.statusCode),
        );
      }

      return data;
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException(
        'Не удалось подключиться '
        'к серверу: $error',
      );
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw const FormatException();
    } catch (_) {
      throw AdminApiException(
        'Сервер вернул некорректный ответ '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  static String _extractErrorMessage(
    Map<String, dynamic> data,
    int statusCode,
  ) {
    final dynamic detail = data['detail'];

    if (detail is String && detail.isNotEmpty) {
      return detail;
    }

    return 'Ошибка сервера '
        '(HTTP $statusCode).';
  }
}
