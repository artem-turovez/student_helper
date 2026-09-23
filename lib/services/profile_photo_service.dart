import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoService {
  static const String _baseUrl = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
    defaultValue: 'https://studenthelper-production-9d49.up.railway.app',
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndUploadPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (image == null) {
      return null;
    }

    return uploadPhoto(image);
  }

  Future<String> uploadPhoto(XFile image) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('Пользователь не авторизован.');
    }

    final String? idToken = await user.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Не удалось получить токен авторизации.');
    }

    final Uri uri = Uri.parse('$_baseUrl/profile/photo');

    final http.MultipartRequest request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';

    final List<int> bytes = await image.readAsBytes();

    final String fileName = _normalizedFileName(image.name);
    final MediaType contentType = _contentTypeForFile(fileName);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: contentType,
      ),
    );

    final http.StreamedResponse streamedResponse = await request.send();

    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    Map<String, dynamic>? data;

    try {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      data = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String detail = data?['detail']?.toString().trim() ?? '';

      throw Exception(
        detail.isNotEmpty ? detail : 'Не удалось загрузить фотографию.',
      );
    }

    final String photoUrl = data?['photoUrl']?.toString().trim() ?? '';

    if (photoUrl.isEmpty) {
      throw Exception('Сервер не вернул адрес фотографии.');
    }

    return photoUrl;
  }

  String _normalizedFileName(String originalName) {
    final String trimmedName = originalName.trim();
    final String lowerName = trimmedName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return trimmedName;
    }

    if (lowerName.endsWith('.webp')) {
      return trimmedName;
    }

    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return trimmedName;
    }

    return 'profile.jpg';
  }

  MediaType _contentTypeForFile(String fileName) {
    final String lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return MediaType('image', 'png');
    }

    if (lowerName.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }

    return MediaType('image', 'jpeg');
  }
}
