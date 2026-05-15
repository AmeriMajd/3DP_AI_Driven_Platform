import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'ws_protocol.dart';

/// Auto-reconnecting WebSocket client with exponential backoff + jitter.
///
/// Single shared connection per app session. Topics are reference-counted:
/// the first subscribe issues a server-side subscribe; the last unsubscribe
/// drops it. Resubscribes happen automatically on reconnect.
///
/// Public surface:
/// - `connect(url, tokenProvider)` — start (idempotent).
/// - `subscribe(topic)` / `unsubscribe(topic)` — reference-counted.
/// - `events` — broadcast stream of all `WsEvent`s, callers filter by topic.
/// - `errors` — broadcast stream of `WsError`s from server.
/// - `connectionState` — broadcast stream of `WsConnectionState`s.
/// - `dispose()` — terminal shutdown.
enum WsConnectionState { disconnected, connecting, connected, fallback }

class ReconnectingWebSocket {
  ReconnectingWebSocket._();
  static final ReconnectingWebSocket instance = ReconnectingWebSocket._();

  Future<String?> Function()? _tokenProvider;
  String? _baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  Timer? _pongDeadline;
  bool _disposed = false;
  bool _starting = false;
  int _failedConnects = 0; // consecutive failed connect attempts

  final _events = StreamController<WsEvent>.broadcast();
  final _errors = StreamController<WsError>.broadcast();
  final _state = StreamController<WsConnectionState>.broadcast();
  final Map<String, int> _refCounts = {};

  Stream<WsEvent> get events => _events.stream;
  Stream<WsError> get errors => _errors.stream;
  Stream<WsConnectionState> get connectionState => _state.stream;

  WsConnectionState _current = WsConnectionState.disconnected;
  WsConnectionState get currentState => _current;

  /// Configure and (re)start the loop. Safe to call multiple times — only
  /// the first call wires the loop; subsequent calls update config.
  void configure({
    required String baseHttpUrl,
    required Future<String?> Function() tokenProvider,
  }) {
    _baseUrl = baseHttpUrl;
    _tokenProvider = tokenProvider;
    if (!_starting && _channel == null) {
      _starting = true;
      // ignore: discarded_futures
      _connectLoop();
    }
  }

  Future<void> subscribe(String topic) async {
    _refCounts[topic] = (_refCounts[topic] ?? 0) + 1;
    if (_refCounts[topic] == 1) {
      _sendRaw({'op': 'subscribe', 'topic': topic});
    }
  }

  Future<void> unsubscribe(String topic) async {
    final cur = _refCounts[topic] ?? 0;
    if (cur <= 1) {
      _refCounts.remove(topic);
      _sendRaw({'op': 'unsubscribe', 'topic': topic});
    } else {
      _refCounts[topic] = cur - 1;
    }
  }

  void _setState(WsConnectionState s) {
    if (_current == s) return;
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  Future<void> _connectLoop() async {
    while (!_disposed) {
      try {
        await _connectOnce();
      } catch (_) {
        _failedConnects += 1;
      }
      if (_disposed) break;
      if (_failedConnects >= 3) {
        _setState(WsConnectionState.fallback);
      }
      await Future.delayed(_backoff());
    }
  }

  Duration _backoff() {
    // 1s -> 30s with jitter
    final base = min(30, pow(2, _failedConnects.clamp(0, 5)).toInt());
    final jitter = Random().nextInt(1000);
    return Duration(milliseconds: base * 1000 + jitter);
  }

  Future<void> _connectOnce() async {
    final base = _baseUrl;
    final tokenProv = _tokenProvider;
    if (base == null || tokenProv == null) {
      throw StateError('ws not configured');
    }
    final token = await tokenProv();
    if (token == null || token.isEmpty) {
      throw StateError('no token');
    }
    final wsBase = base
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceFirst(RegExp(r'^https://'), 'wss://');
    final uri = Uri.parse('$wsBase/ws?token=$token');

    _setState(WsConnectionState.connecting);
    final ch = WebSocketChannel.connect(uri);
    await ch.ready;
    _channel = ch;
    _failedConnects = 0;
    _setState(WsConnectionState.connected);

    // Resubscribe everything on reconnect
    for (final topic in _refCounts.keys) {
      _sendRaw({'op': 'subscribe', 'topic': topic});
    }

    final completer = Completer<void>();
    _channelSub = ch.stream.listen(
      _onMessage,
      onError: (e, _) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    _armPongDeadline();
    await completer.future;
    _channelSub = null;
    _channel = null;
    _pongDeadline?.cancel();
    if (!_disposed) {
      _setState(WsConnectionState.disconnected);
    }
  }

  void _sendRaw(Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(payload));
    } catch (_) {
      // Connection in bad state; loop will reconnect.
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final op = parseServerOp(json['op'] as String?);
    switch (op) {
      case WsServerOp.event:
        if (!_events.isClosed) _events.add(WsEvent.fromJson(json));
        break;
      case WsServerOp.pong:
        _armPongDeadline();
        break;
      case WsServerOp.error:
        if (!_errors.isClosed) _errors.add(WsError.fromJson(json));
        break;
      case WsServerOp.subscribed:
      case WsServerOp.unsubscribed:
      case null:
        break;
    }
  }

  void _armPongDeadline() {
    _pongDeadline?.cancel();
    _pongDeadline = Timer(const Duration(seconds: 90), () {
      // Server didn't ping in 90s; force-close to trigger reconnect.
      try {
        _channel?.sink.close(ws_status.goingAway);
      } catch (_) {}
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pongDeadline?.cancel();
    await _channelSub?.cancel();
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    await _events.close();
    await _errors.close();
    await _state.close();
  }
}
