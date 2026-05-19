// WebSocket wire protocol — mirrors backend/app/ws/protocol.py.
// All client/server messages are JSON with an `op` field.

class WsEvent {
  final String topic;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const WsEvent({
    required this.topic,
    required this.type,
    required this.timestamp,
    required this.data,
  });

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      topic: json['topic'] as String,
      type: json['type'] as String,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now().toUtc(),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
    );
  }
}

class WsAck {
  final String topic;
  final bool subscribed; // true = subscribed, false = unsubscribed

  const WsAck({required this.topic, required this.subscribed});
}

class WsError {
  final String code;
  final String? topic;
  final String? message;

  const WsError({required this.code, this.topic, this.message});

  factory WsError.fromJson(Map<String, dynamic> json) {
    return WsError(
      code: json['code'] as String? ?? 'unknown',
      topic: json['topic'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// Server → client op kinds.
enum WsServerOp { event, subscribed, unsubscribed, pong, error }

WsServerOp? parseServerOp(String? op) {
  switch (op) {
    case 'event':
      return WsServerOp.event;
    case 'subscribed':
      return WsServerOp.subscribed;
    case 'unsubscribed':
      return WsServerOp.unsubscribed;
    case 'pong':
      return WsServerOp.pong;
    case 'error':
      return WsServerOp.error;
    default:
      return null;
  }
}

/// Topic builders — keep in sync with backend `app/ws/emit.py`.
class WsTopics {
  static String job(String id) => 'job:$id';
  static String stl(String id) => 'stl:$id';
  static String printer(String id) => 'printer:$id';
  static String user(String id) => 'user:$id';
  static const adminJobs = 'admin:jobs';
}
