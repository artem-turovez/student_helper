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

  Future<void> scheduleAcademicEventReminder({
    required String eventId,
    required String subject,
    required String type,
    required String title,
    required String description,
    required DateTime eventDate,
    required String lessonTime,
    int reminderMinutesBefore = 30,
  }) async {
    final int notificationId = _notificationIdForAcademicEvent(eventId);

    await _localNotifications.cancel(id: notificationId);

    if (!_timeZoneInitialized) {
      debugPrint(
        'Напоминание учебного события $eventId не запланировано: '
        'часовой пояс устройства не определён.',
      );
      return;
    }

    final DateTime? lessonStart = _academicEventDateTime(
      eventDate: eventDate,
      lessonTime: lessonTime,
    );

    if (lessonStart == null) {
      debugPrint(
        'Напоминание учебного события $eventId не запланировано: '
        'не удалось определить время пары "$lessonTime".',
      );
      return;
    }

    final DateTime reminderDate = lessonStart.subtract(
      Duration(minutes: reminderMinutesBefore),
    );

    if (!reminderDate.isAfter(DateTime.now())) {
      debugPrint(
        'Напоминание учебного события $eventId не запланировано: '
        'время уже прошло.',
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

    final String normalizedType = type.trim();
    final String normalizedSubject = subject.trim();
    final String normalizedDescription = description.trim();

    final String notificationTitle = normalizedType.isNotEmpty
        ? '$normalizedType • $normalizedSubject'
        : normalizedSubject;

    final String notificationBody = normalizedDescription.isNotEmpty
        ? '$title\n$normalizedDescription'
        : title;

    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: notificationTitle,
      body: notificationBody,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
payload:
    'academic_event:$eventId:'
    '${eventDate.year}-'
    '${eventDate.month.toString().padLeft(2, '0')}',
        );

    debugPrint(
      'Напоминание учебного события $eventId запланировано '
      'на $scheduledDate.',
    );
  }
  Future<void> cancelStaleAcademicEventReminders({
  required Set<String> activeEventIds,
  required DateTime month,
}) async {
  final List<PendingNotificationRequest> pendingNotifications =
      await _localNotifications.pendingNotificationRequests();

  final String targetMonth =
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  int cancelledCount = 0;

  for (final PendingNotificationRequest notification
      in pendingNotifications) {
    final String? payload = notification.payload;

    if (payload == null || !payload.startsWith('academic_event:')) {
      continue;
    }

    final String payloadData =
        payload.substring('academic_event:'.length);

    final int monthSeparatorIndex = payloadData.lastIndexOf(':');

    // Старый формат:
    // academic_event:<eventId>
    //
    // Его не удаляем здесь, потому что невозможно надёжно определить,
    // к какому месяцу относится уведомление.
    if (monthSeparatorIndex == -1) {
      continue;
    }

    final String eventId =
        payloadData.substring(0, monthSeparatorIndex);

    final String eventMonth =
        payloadData.substring(monthSeparatorIndex + 1);

    // Синхронизируем только выбранный месяц.
    if (eventMonth != targetMonth) {
      continue;
    }

    if (activeEventIds.contains(eventId)) {
      continue;
    }

    await _localNotifications.cancel(id: notification.id);
    cancelledCount++;
  }

  if (cancelledCount > 0) {
    debugPrint(
      'Удалено устаревших напоминаний учебных событий '
      'за $targetMonth: $cancelledCount.',
    );
  }
}
  Future<void> cancelAcademicEventReminder(String eventId) async {
    final int notificationId = _notificationIdForAcademicEvent(eventId);

    await _localNotifications.cancel(id: notificationId);

    debugPrint('Напоминание учебного события $eventId отменено.');
  }

  DateTime? _academicEventDateTime({
    required DateTime eventDate,
    required String lessonTime,
  }) {
    final RegExp timePattern = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})\s*$',
    );

    final RegExpMatch? match = timePattern.firstMatch(lessonTime);

    if (match == null) {
      return null;
    }

    final int? hour = int.tryParse(match.group(1) ?? '');
    final int? minute = int.tryParse(match.group(2) ?? '');

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      hour,
      minute,
    );
  }

  int _notificationIdForAcademicEvent(String eventId) {
    int hash = 0x811c9dc5;

    for (final int byte in eventId.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    return 1100000000 + (hash % 900000000);
  }
}
