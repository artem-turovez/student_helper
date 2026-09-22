import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> checkAdminAccess() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final String? idToken = await user.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Не удалось получить Firebase ID token');
    }

    final response = await http
        .get(
          Uri.parse('$_baseUrl/admin/check'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    Map<String, dynamic> data = {};

    if (response.body.isNotEmpty) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    }

    if (response.statusCode != 200) {
      final String message =
          data['detail']?.toString() ?? 'Ошибка API: ${response.statusCode}';

      throw Exception(message);
    }

    return data;
  }
}
