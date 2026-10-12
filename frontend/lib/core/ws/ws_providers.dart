import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/shared/services/dio_client.dart';
import 'package:frontend/shared/services/storage_service.dart';

import 'ws_client.dart';
import 'ws_protocol.dart';

/// Root provider — configures the singleton on first read.
final wsClientProvider = Provider<ReconnectingWebSocket>((ref) {
  // ignore: avoid_print
  if (kDebugMode) print('[ws] wsClientProvider initialized; baseUrl=${DioClient.instance.options.baseUrl}');
  final client = ReconnectingWebSocket.instance;
  client.configure(
    baseHttpUrl: DioClient.instance.options.baseUrl,
    tokenProvider: () => StorageService.getToken(),
  );
  return client;
});

/// Connection state stream.
final wsConnectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final client = ref.watch(wsClientProvider);
  return client.connectionState;
});

/// Per-topic event stream. Manages subscribe/unsubscribe lifecycle via Riverpod.
final wsTopicEventsProvider =
    StreamProvider.autoDispose.family<WsEvent, String>((ref, topic) {
  // ignore: avoid_print
  if (kDebugMode) print('[ws] wsTopicEventsProvider building topic=$topic');
  final client = ref.watch(wsClientProvider);
  client.subscribe(topic);
  ref.onDispose(() => client.unsubscribe(topic));
  return client.events.where((e) => e.topic == topic);
});
