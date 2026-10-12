import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'database_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS displays notification payloads while the app is backgrounded.
  // Navigation is handled when the app is opened from the notification.
  debugPrint('Received flood warning in background: ${message.messageId}');
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    required DatabaseService database,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _database = database;

  final FirebaseMessaging _messaging;
  final DatabaseService _database;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> initialize({
    void Function(String warningId)? onWarningOpened,
    void Function(RemoteMessage message)? onMessageReceived,
  }) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _getToken();
    if (token != null) await _saveToken(token);

    _tokenSubscription = _messaging.onTokenRefresh.listen(_saveToken);
    FirebaseMessaging.onMessage.listen((message) {
      onMessageReceived?.call(message);
      debugPrint(
        'Flood warning received while app is open: ${message.messageId}',
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final warningId = message.data['warningId'];
      if (warningId is String && warningId.isNotEmpty) {
        onWarningOpened?.call(warningId);
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    final warningId = initialMessage?.data['warningId'];
    if (warningId is String && warningId.isNotEmpty) {
      onWarningOpened?.call(warningId);
    }
  }

  Future<void> _saveToken(String token) =>
      _database.saveDeviceToken(token: token, platform: _platformName);

  Future<String?> _getToken() async {
    if (!kIsWeb) return _messaging.getToken();
    const vapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
    if (vapidKey.isEmpty) {
      debugPrint(
        'Web push is disabled until FIREBASE_WEB_VAPID_KEY is supplied.',
      );
      return null;
    }
    return _messaging.getToken(
      vapidKey: vapidKey,
      // Explicitly use the worker shipped with this Flutter web build. This
      // matters on GitHub Pages because the app is hosted below a project path.
      serviceWorkerScriptPath: 'firebase-messaging-sw.js',
    );
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  Future<void> dispose() async => _tokenSubscription?.cancel();
}
