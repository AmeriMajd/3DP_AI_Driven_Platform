import 'package:flutter/material.dart';

/// Design tokens for the admin dashboard (light mode only).
/// Mirrors `dashboard/project/tokens.css` `[data-theme="light"]`.
class DT {
  DT._();

  // surfaces
  static const Color bg = Color(0xFFF5F6F9);
  static const Color surface1 = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF8F9FC);
  static const Color surface3 = Color(0xFFEEF0F5);

  // lines
  static const Color border = Color(0xFFE4E7EE);
  static const Color borderSoft = Color(0xFFEEF0F5);
  static const Color divider = Color(0x0F141E32); // rgba(20,30,50,.06)

  // text
  static const Color text = Color(0xFF0F1623);
  static const Color text2 = Color(0xFF4A5568);
  static const Color text3 = Color(0xFF7B8696);
  static const Color textDisabled = Color(0xFFB7BCC7);

  // accent
  static const Color accent = Color(0xFF2563EB);
  static const Color accentHover = Color(0xFF1D4ED8);
  static const Color accentSoft = Color(0x1A2563EB);

  // signals
  static const Color up = Color(0xFF15803D);
  static const Color down = Color(0xFFB91C1C);

  // shadows
  static List<BoxShadow> shadowSm = const [
    BoxShadow(color: Color(0x0F141E32), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static List<BoxShadow> shadowMd = const [
    BoxShadow(color: Color(0x14141E32), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Job status palette — fg + tinted bg.
class StatusColors {
  final Color fg;
  final Color bg;
  const StatusColors(this.fg, this.bg);

  static const Map<String, StatusColors> _map = {
    'printing': StatusColors(Color(0xFF2563EB), Color(0x1A2563EB)),
    'queued': StatusColors(Color(0xFFB45309), Color(0x24F59E0B)),
    'completed': StatusColors(Color(0xFF15803D), Color(0x2422C55E)),
    'failed': StatusColors(Color(0xFFB91C1C), Color(0x1AEF4444)),
    'canceled': StatusColors(Color(0xFF64748B), Color(0x1F64748B)),
    'paused': StatusColors(Color(0xFF7E22CE), Color(0x1FA855F7)),
    'scheduled': StatusColors(Color(0xFF0891B2), Color(0x1F06B6D4)),
  };

  static StatusColors of(String status) =>
      _map[status] ?? const StatusColors(Color(0xFF64748B), Color(0x1F64748B));
}

String statusLabel(String s) => switch (s) {
      'printing' => 'Printing',
      'queued' => 'Queued',
      'scheduled' => 'Scheduled',
      'completed' => 'Completed',
      'failed' => 'Failed',
      'canceled' => 'Canceled',
      'paused' => 'Paused',
      _ => s,
    };

String formatMoney(num n) {
  if (n.abs() >= 1000) return '\$${(n / 1000).toStringAsFixed(1)}k';
  return '\$${n.toStringAsFixed(2)}';
}

String formatMoneyCompact(num n) {
  if (n.abs() >= 1000) return '\$${(n / 1000).toStringAsFixed(1)}k';
  return '\$${n.toStringAsFixed(0)}';
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String timeAgo(DateTime t) {
  final diff = DateTime.now().toUtc().difference(t.toUtc());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Deterministic avatar hue from a name (hash % 360).
int hueOf(String name) {
  if (name.isEmpty) return 200;
  return (name.codeUnitAt(0) * 13) % 360;
}
