import 'package:flutter/material.dart';

import '../../domain/admin_dashboard_models.dart';
import 'dashboard_tokens.dart';

class JobsStackedChart extends StatelessWidget {
  final List<JobsByStatusPoint> data;
  final double height;
  const JobsStackedChart({super.key, required this.data, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _JobsBarPainter(data: data)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              _LegendDot(color: Color(0xFF15803D), label: 'Completed'),
              _LegendDot(color: Color(0xFFB91C1C), label: 'Failed'),
              _LegendDot(color: Color(0xFF64748B), label: 'Canceled'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: DT.text2, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _JobsBarPainter extends CustomPainter {
  final List<JobsByStatusPoint> data;
  _JobsBarPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const padL = 30.0, padR = 8.0, padT = 10.0, padB = 22.0;
    final innerW = size.width - padL - padR;
    final innerH = size.height - padT - padB;
    final n = data.length;
    final totals = data.map((d) => d.completed + d.failed + d.canceled).toList();
    final maxV = (totals.fold<int>(0, (a, b) => a > b ? a : b)).toDouble() * 1.1;
    final maxSafe = maxV <= 0 ? 1.0 : maxV;

    const gap = 2.0;
    final bw = (innerW / n) - gap;

    final grid = Paint()
      ..color = DT.divider
      ..strokeWidth = 1;
    final textStyle = const TextStyle(color: DT.text3, fontSize: 9);

    for (final t in [0.0, 0.5, 1.0]) {
      final yv = padT + (1 - t) * innerH;
      if (t == 0) {
        canvas.drawLine(Offset(padL, yv), Offset(padL + innerW, yv), grid);
      } else {
        _dashLine(canvas, Offset(padL, yv), Offset(padL + innerW, yv), grid);
      }
      _paintText(canvas, '${(maxSafe * t).round()}', Offset(padL - 28, yv - 5),
          textStyle, align: TextAlign.right, maxWidth: 24);
    }

    final completedPaint = Paint()..color = const Color(0xFF15803D);
    final failedPaint = Paint()..color = const Color(0xFFB91C1C);
    final canceledPaint = Paint()..color = const Color(0xFF64748B);

    for (int i = 0; i < n; i++) {
      final d = data[i];
      final x = padL + i * (bw + gap);
      final completedH = (d.completed / maxSafe) * innerH;
      final failedH = (d.failed / maxSafe) * innerH;
      final canceledH = (d.canceled / maxSafe) * innerH;
      var y = padT + innerH;
      // completed bottom
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(x, y - completedH, x + bw, y,
            bottomLeft: const Radius.circular(1), bottomRight: const Radius.circular(1)),
        completedPaint,
      );
      y -= completedH;
      canvas.drawRect(Rect.fromLTRB(x, y - failedH, x + bw, y), failedPaint);
      y -= failedH;
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(x, y - canceledH, x + bw, y,
            topLeft: const Radius.circular(1), topRight: const Radius.circular(1)),
        canceledPaint,
      );
    }

    // x-axis labels
    final marks = <(int, String)>[
      (0, '${n}d'),
      ((n * 0.33).floor(), '${(n * 0.66).floor()}d'),
      ((n * 0.66).floor(), '${(n * 0.33).floor()}d'),
      (n - 1, 'today'),
    ];
    for (final (i, label) in marks) {
      final x = padL + i * (bw + gap) + bw / 2;
      _paintText(canvas, label, Offset(x - 22, size.height - 14), textStyle,
          align: TextAlign.center, maxWidth: 44);
    }
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 3.0, gap = 3.0;
    final total = (b - a).distance;
    final dx = (b.dx - a.dx) / total, dy = (b.dy - a.dy) / total;
    var cur = a;
    var drawn = 0.0;
    while (drawn < total) {
      final end = Offset(cur.dx + dx * dash, cur.dy + dy * dash);
      canvas.drawLine(cur, end, p);
      cur = Offset(end.dx + dx * gap, end.dy + dy * gap);
      drawn += dash + gap;
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style,
      {TextAlign align = TextAlign.left, double maxWidth = 100}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    final dx = align == TextAlign.right
        ? offset.dx + (maxWidth - tp.width)
        : align == TextAlign.center
            ? offset.dx + (maxWidth - tp.width) / 2
            : offset.dx;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _JobsBarPainter old) => old.data != data;
}
