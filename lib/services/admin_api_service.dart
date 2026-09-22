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

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/check'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final Map<String, dynamic> data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw AdminApiException(_extractErrorMessage(data, response.statusCode));
    }

    return data;
  }

  static Future<ScheduleCheckResult> checkSchedule(PlatformFile file) async {
    final String? filePath = file.path;

    if (filePath == null || filePath.isEmpty) {
      throw const AdminApiException(
        'Не удалось получить путь к выбранному PDF-файлу.',
      );
    }

    final String token = await _getIdToken();

    final Uri uri = Uri.parse('$_baseUrl/schedule/check');

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

      return ScheduleCheckResult.fromJson(data);
    } on AdminApiException {
      rethrow;
    } catch (error) {
      throw AdminApiException('Не удалось подключиться к серверу: $error');
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

    return 'Ошибка сервера (HTTP $statusCode).';
  }
}
