import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _requestPermission();

    if (Platform.isIOS || Platform.isMacOS) {
      await _configureAppleForegroundNotifications();
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    await _printToken();

    _messaging.onTokenRefresh.listen((String token) {
      debugPrint('FCM token обновлён: $token');

      // Позже здесь будем сохранять новый токен в Firestore.
    });
  }

  Future<void> _requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'Разрешение на уведомления: '
      '${settings.authorizationStatus}',
    );
  }

  Future<void> _configureAppleForegroundNotifications() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      'Получено уведомление при открытом приложении: '
      '${message.messageId}',
    );

    debugPrint('Заголовок: ${message.notification?.title}');

    debugPrint('Текст: ${message.notification?.body}');

    debugPrint('Данные: ${message.data}');
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint(
      'Пользователь открыл уведомление: '
      '${message.messageId}',
    );

    debugPrint('Данные уведомления: ${message.data}');

    // Позже здесь добавим переход, например:
    // расписание -> экран расписания;
    // событие -> экран календаря;
    // изменение пары -> нужный день расписания.
  }

  Future<void> _printToken() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final String? apnsToken = await _messaging.getAPNSToken();

        if (apnsToken == null) {
          debugPrint(
            'APNs token пока недоступен. '
            'Для полноценной работы push на iOS '
            'необходима настройка APNs.',
          );

          return;
        }
      }

      final String? token = await _messaging.getToken();

      if (token == null) {
        debugPrint('FCM token пока недоступен.');
        return;
      }

      debugPrint('FCM token: $token');
    } catch (error) {
      debugPrint('Не удалось получить FCM token: $error');
    }
  }
}
