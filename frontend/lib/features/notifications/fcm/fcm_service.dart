import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/notification_repository.dart';
import '../data/notification_repository_impl.dart';

/// Top-level handler required by `firebase_messaging` for background /
/// terminated state. Must be a top-level or static function with the
/// `@pragma('vm:entry-point')` annotation.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal: the message will be shown by the system itself
  // (when sent with a `notification` block) and we don't need to do anything
  // here for Phase 3. Hook for telemetry / silent updates later.
  if (kDebugMode) {
    // ignore: avoid_print
    print('[fcm-bg] ${message.messageId} ${message.data}');
  }
}

/// Singleton wrapper around `firebase_messaging` + foreground display
/// via `flutter_local_notifications`.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final NotificationRepository _repo = NotificationRepositoryImpl();

  bool _started = false;

  /// Cold-start tap payload, captured during [start] but only delivered to
  /// the first listener so the router has time to mount.
  Map<String, dynamic>? _pendingInitialTap;

  /// Broadcasts tap payloads from foreground / background / terminated state.
  /// Wire this to the navigator to deep-link the user to the right screen.
  final _tapEvents = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get tapEvents => _tapEvents.stream;

  /// Drain the cold-start tap (if any). Returns the payload or null. The
  /// caller (`main.dart`) converts it to a route and stashes it in
  /// `pendingPushRoute` for SplashScreen to consume after auth resolves.
  Map<String, dynamic>? consumePendingInitial() {
    final pending = _pendingInitialTap;
    _pendingInitialTap = null;
    return pending;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Background handler must be registered before any other listener.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _setupLocalChannels();
    await _registerCurrentToken();

    _fm.onTokenRefresh.listen(_onTokenRefresh);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // App was launched from a terminated state by tapping a push.
    // Stash the payload — caller flushes it after the router is ready.
    final initial = await _fm.getInitialMessage();
    if (initial != null) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[fcm] initial message captured: ${initial.data}');
      }
      _pendingInitialTap = Map<String, dynamic>.from(initial.data);
    }
  }

  Future<void> _requestPermission() async {
    await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _setupLocalChannels() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          _emitTap({'notification_id': payload});
        }
      },
    );

    // Default Android channel — id MUST match backend
    // `Settings.FCM_DEFAULT_ANDROID_CHANNEL`.
    const defaultChannel = AndroidNotificationChannel(
      'notifications_default',
      'General notifications',
      description: 'Operational alerts from the 3DP platform',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(defaultChannel);
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await _fm.getToken();
      if (token == null || token.isEmpty) return;
      await _repo.registerDevice(
        fcmToken: token,
        platform: _platformName(),
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[fcm] register failed: $e');
      }
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    try {
      await _repo.registerDevice(
        fcmToken: newToken,
        platform: _platformName(),
      );
    } catch (_) {
      // Best-effort; next register on app start covers eventual consistency.
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    // When the app is in the foreground iOS/Android do not auto-display the
    // notification. Render it via flutter_local_notifications using the
    // same Android channel so the user still gets a banner.
    final n = message.notification;
    final tag = message.collapseKey;
    if (n == null) return;
    _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'notifications_default',
          'General notifications',
          channelDescription: 'Operational alerts from the 3DP platform',
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['notification_id']?.toString(),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _emitTap(message.data);
  }

  void _emitTap(Map<String, dynamic> data) {
    if (_tapEvents.isClosed) return;
    _tapEvents.add(Map<String, dynamic>.from(data));
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  /// Called on logout — unregister token so the user stops getting pushes
  /// on this device.
  Future<void> unregister() async {
    try {
      final token = await _fm.getToken();
      if (token != null && token.isNotEmpty) {
        await _repo.unregisterDevice(token);
      }
      await _fm.deleteToken();
    } catch (_) {
      // Ignore — server-side cleanup will eventually prune dead tokens.
    }
  }

  Future<void> dispose() async {
    await _tapEvents.close();
  }
}
