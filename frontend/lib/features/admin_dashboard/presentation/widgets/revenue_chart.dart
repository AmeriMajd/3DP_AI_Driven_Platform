import 'package:flutter/material.dart';

import '../../domain/admin_dashboard_models.dart';
import 'dashboard_tokens.dart';

class RevenueChart extends StatefulWidget {
  final List<RevenuePoint> data;
  final double height;
  const RevenueChart({super.key, required this.data, this.height = 160});
  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _hoverIdx;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _setHover(d.localPosition, context.size),
      onPanUpdate: (d) => _setHover(d.localPosition, context.size),
      onPanEnd: (_) => setState(() => _hoverIdx = null),
      onTapDown: (d) => _setHover(d.localPosition, context.size),
      onTapUp: (_) => setState(() => _hoverIdx = null),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _RevenuePainter(data: widget.data, hoverIdx: _hoverIdx),
        ),
      ),
    );
  }

  void _setHover(Offset pos, Size? size) {
    if (size == null || widget.data.isEmpty) return;
    const padL = 36.0, padR = 14.0;
    final innerW = size.width - padL - padR;
    if (innerW <= 0) return;
    final n = widget.data.length;
    final rel = ((pos.dx - padL) / innerW).clamp(0.0, 1.0);
    final idx = (rel * (n - 1)).round();
    if (idx != _hoverIdx) setState(() => _hoverIdx = idx);
  }
}

class _RevenuePainter extends CustomPainter {
  final List<RevenuePoint> data;
  final int? hoverIdx;
  _RevenuePainter({required this.data, required this.hoverIdx});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const padL = 36.0, padR = 14.0, padT = 14.0, padB = 22.0;
    final innerW = size.width - padL - padR;
    final innerH = size.height - padT - padB;
    final n = data.length;
    final maxV = (data.map((p) => p.value).fold<double>(0.0, (a, b) => a > b ? a : b)) * 1.15;
    final maxSafe = maxV <= 0 ? 1.0 : maxV;

    double xAt(int i) => padL + (n == 1 ? innerW / 2 : (i / (n - 1)) * innerW);
    double yAt(double v) => padT + (1 - v / maxSafe) * innerH;

    // grid + y labels
    final gridPaint = Paint()
      ..color = DT.divider
      ..strokeWidth = 1;
    final textStyle = const TextStyle(color: DT.text3, fontSize: 9);
    for (final t in [0.0, 0.5, 1.0]) {
      final v = maxSafe * t;
      final y = yAt(v);
      if (t == 0) {
        canvas.drawLine(Offset(padL, y), Offset(padL + innerW, y), gridPaint);
      } else {
        _dashLine(canvas, Offset(padL, y), Offset(padL + innerW, y), gridPaint);
      }
      _paintText(
        canvas,
        '\$${v.round()}',
        Offset(padL - 4, y - 5),
        textStyle,
        align: TextAlign.right,
        maxWidth: padL - 6,
      );
    }

    // build catmull-rom smooth path
    final linePath = Path();
    final fillPath = Path();
    linePath.moveTo(xAt(0), yAt(data[0].value));
    fillPath.moveTo(xAt(0), yAt(data[0].value));
    for (int i = 0; i < n - 1; i++) {
      final p0 = data[i == 0 ? i : i - 1].value;
      final p1 = data[i].value;
      final p2 = data[i + 1].value;
      final p3 = data[i + 2 >= n ? n - 1 : i + 2].value;
      final c1x = xAt(i) + (xAt(i + 1) - xAt(i == 0 ? i : i - 1)) / 6;
      final c1y = yAt(p1) + (yAt(p2) - yAt(p0)) / 6;
      final c2x = xAt(i + 1) - (xAt(i + 2 >= n ? n - 1 : i + 2) - xAt(i)) / 6;
      final c2y = yAt(p2) - (yAt(p3) - yAt(p1)) / 6;
      linePath.cubicTo(c1x, c1y, c2x, c2y, xAt(i + 1), yAt(p2));
      fillPath.cubicTo(c1x, c1y, c2x, c2y, xAt(i + 1), yAt(p2));
    }
    fillPath.lineTo(xAt(n - 1), padT + innerH);
    fillPath.lineTo(xAt(0), padT + innerH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [DT.accent.withValues(alpha: 0.35), DT.accent.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(padL, padT, innerW, innerH));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = DT.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // x labels (4 points)
    final labels = <(int, String)>[
      (0, '${n}d ago'),
      ((n * 0.33).floor(), '${(n * 0.66).floor()}d'),
      ((n * 0.66).floor(), '${(n * 0.33).floor()}d'),
      (n - 1, 'today'),
    ];
    for (int k = 0; k < labels.length; k++) {
      final (i, label) = labels[k];
      final align = k == 0
          ? TextAlign.left
          : k == labels.length - 1
              ? TextAlign.right
              : TextAlign.center;
      _paintText(
        canvas,
        label,
        Offset(xAt(i) - 30, size.height - 14),
        textStyle,
        align: align,
        maxWidth: 60,
      );
    }

    // hover
    if (hoverIdx != null && hoverIdx! >= 0 && hoverIdx! < n) {
      final x = xAt(hoverIdx!);
      final y = yAt(data[hoverIdx!].value);
      _dashLine(
        canvas,
        Offset(x, padT),
        Offset(x, padT + innerH),
        Paint()
          ..color = DT.accent.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()..color = DT.bg,
      );
      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()
          ..color = DT.accent
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      final tipX = (x - 32).clamp(padL, size.width - 70);
      final tipY = (y - 36).clamp(2.0, size.height - 30);
      final tipRect = RRect.fromLTRBR(tipX, tipY, tipX + 64, tipY + 24, const Radius.circular(6));
      canvas.drawRRect(
        tipRect,
        Paint()..color = DT.surface3,
      );
      canvas.drawRRect(
        tipRect,
        Paint()
          ..color = DT.border
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
      _paintText(
        canvas,
        'Day ${hoverIdx! + 1}',
        Offset(tipX + 8, tipY + 2),
        const TextStyle(color: DT.text3, fontSize: 8),
        maxWidth: 60,
      );
      _paintText(
        canvas,
        '\$${data[hoverIdx!].value.round()}',
        Offset(tipX + 8, tipY + 11),
        const TextStyle(
          color: DT.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        maxWidth: 60,
      );
    }
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint p) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final dist = (dx * dx + dy * dy);
    final len = dist <= 0 ? 0.0 : (dist).abs();
    if (len == 0) return;
    const dash = 3.0, gap = 3.0;
    final total = (dash + gap);
    final segs = ((a - b).distance / total).floor();
    final ux = dx / (a - b).distance, uy = dy / (a - b).distance;
    var cur = a;
    for (int i = 0; i <= segs; i++) {
      final end = Offset(cur.dx + ux * dash, cur.dy + uy * dash);
      canvas.drawLine(cur, end, p);
      cur = Offset(end.dx + ux * gap, end.dy + uy * gap);
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    TextAlign align = TextAlign.left,
    double maxWidth = 100,
  }) {
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
  bool shouldRepaint(covariant _RevenuePainter old) =>
      old.data != data || old.hoverIdx != hoverIdx;
}
