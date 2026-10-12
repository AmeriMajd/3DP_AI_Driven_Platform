import 'package:flutter/material.dart';

import 'dashboard_tokens.dart';

class DashAvatar extends StatelessWidget {
  final String name;
  final int? hue;
  final double size;
  const DashAvatar({super.key, required this.name, this.hue, this.size = 32});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final h = (hue ?? hueOf(name)).toDouble();
    final a = HSLColor.fromAHSL(1, h, 0.5, 0.55).toColor();
    final b = HSLColor.fromAHSL(1, (h + 30) % 360, 0.5, 0.45).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
