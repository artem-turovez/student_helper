import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'student_helper_high_importance';
  static const String _channelName = 'Основные уведомления';
  static const String _channelDescription =
      'Основные уведомления приложения Помощник учащегося';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _localNotificationsInitialized = false;
  bool _timeZoneInitialized = false;

  Future<void> initialize() async {
    await _requestPermission();
    await _initializeLocalNotifications();
    await _initializeTimeZone();

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
      debugPrint('FCM token обновлён.');

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

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
          defaultPresentBanner: true,
          defaultPresentList: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidPlugin?.createNotificationChannel(channel);
    }

    _localNotificationsInitialized = true;
  }

  Future<void> _initializeTimeZone() async {
    try {
      tz_data.initializeTimeZones();

      final TimezoneInfo timeZoneInfo =
          await FlutterTimezone.getLocalTimezone();

      final String timeZoneName = timeZoneInfo.identifier;

      final tz.Location location = tz.getLocation(timeZoneName);

      tz.setLocalLocation(location);
      _timeZoneInitialized = true;

      debugPrint('Часовой пояс уведомлений: $timeZoneName');
    } catch (error) {
      _timeZoneInitialized = false;

      debugPrint('Не удалось определить часовой пояс уведомлений: $error');
    }
  }

  Future<void> _configureAppleForegroundNotifications() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> schedulePersonalEventReminder({
    required String eventId,
    required String title,
    required String description,
    required DateTime eventDate,
    required int? reminderMinutesBefore,
  }) async {
    final int notificationId = _notificationIdForPersonalEvent(eventId);

    await _localNotifications.cancel(id: notificationId);

    if (reminderMinutesBefore == null) {
      debugPrint('Напоминание для события $eventId выключено.');
      return;
    }

    if (!_timeZoneInitialized) {
      debugPrint(
        'Напоминание для события $eventId не запланировано: '
        'часовой пояс устройства не определён.',
      );
      return;
    }

    final DateTime reminderDate = eventDate.subtract(
      Duration(minutes: reminderMinutesBefore),
    );

    if (!reminderDate.isAfter(DateTime.now())) {
      debugPrint(
        'Напоминание для события $eventId '
        'не запланировано: время уже прошло.',
      );
      return;
    }

    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      reminderDate.hour,
      reminderDate.minute,
      reminderDate.second,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final String notificationBody = description.trim().isNotEmpty
        ? description.trim()
        : _personalEventReminderText(reminderMinutesBefore);

    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: title,
      body: notificationBody,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'personal_event:$eventId',
    );

    debugPrint(
      'Напоминание события $eventId запланировано '
      'на $scheduledDate.',
    );
  }

  Future<void> cancelPersonalEventReminder(String eventId) async {
    final int notificationId = _notificationIdForPersonalEvent(eventId);

    await _localNotifications.cancel(id: notificationId);

    debugPrint('Напоминание события $eventId отменено.');
  }

  int _notificationIdForPersonalEvent(String eventId) {
    int hash = 0x811c9dc5;

    for (final int byte in eventId.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    return 100000000 + (hash % 900000000);
  }

  String _personalEventReminderText(int reminderMinutesBefore) {
    switch (reminderMinutesBefore) {
      case 0:
        return 'Событие начинается сейчас';

      case 5:
        return 'Событие начнётся через 5 минут';

      case 15:
        return 'Событие начнётся через 15 минут';

      case 30:
        return 'Событие начнётся через 30 минут';

      case 60:
        return 'Событие начнётся через 1 час';

      case 1440:
        return 'Событие состоится завтра';

      default:
        return 'Скоро начнётся запланированное событие';
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'Получено уведомление при открытом приложении: '
      '${message.messageId}',
    );

    debugPrint('Заголовок: ${message.notification?.title}');

    debugPrint('Текст: ${message.notification?.body}');

    debugPrint('Данные: ${message.data}');

    if (!Platform.isAndroid) {
      return;
    }

    final RemoteNotification? notification = message.notification;

    if (notification == null) {
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: notification.title ?? 'Помощник учащегося',
      body: notification.body ?? '',
      notificationDetails: notificationDetails,
    );
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    debugPrint(
      'Открыто локальное уведомление: '
      '${response.payload}',
    );

    // Позже подключим переход прямо к нужному событию.
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint(
      'Пользователь открыл уведомление: '
      '${message.messageId}',
    );

    debugPrint('Данные уведомления: ${message.data}');

    // Позже здесь добавим переход:
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

      debugPrint('FCM token получен.');
    } catch (error) {
      debugPrint('Не удалось получить FCM token: $error');
    }
  }
}
