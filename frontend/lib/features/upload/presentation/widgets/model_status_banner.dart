import 'package:flutter/material.dart';

class ModelStatusBanner extends StatelessWidget {
  final String status;
  const ModelStatusBanner({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final config = _StatusConfig.of(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          // Icône ou spinner
          if (status == 'analyzing')
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(config.color),
              ),
            )
          else
            Icon(config.icon, size: 18, color: config.color),

          const SizedBox(width: 10),

          // Label + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: config.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  config.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: config.color.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),

          // Badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: config.color.withOpacity(0.35)),
            ),
            child: Text(
              config.badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: config.color,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Config interne ─────────────────────────────────────────────────────────────

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;
  final String description;
  final String badge;

  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
    required this.description,
    required this.badge,
  });

  factory _StatusConfig.of(String status) {
    switch (status) {
      case 'analyzing':
        return const _StatusConfig(
          color: Color(0xFF3B82F6), // blue
          icon: Icons.hourglass_top_outlined,
          label: 'Analyzing model',
          description: 'Extracting geometry features — this may take a few seconds',
          badge: 'IN PROGRESS',
        );
      case 'ready':
        return const _StatusConfig(
          color: Color(0xFF22C55E), // green
          icon: Icons.check_circle_outline_rounded,
          label: 'Analysis complete',
          description: 'Geometry extracted — model ready for AI recommendation',
          badge: 'READY',
        );
      case 'error':
        return const _StatusConfig(
          color: Color(0xFFEF4444), // red
          icon: Icons.error_outline_rounded,
          label: 'Analysis failed',
          description: 'An error occurred during geometry extraction',
          badge: 'ERROR',
        );
      default: // 'uploaded'
        return const _StatusConfig(
          color: Color(0xFF8B5CF6), // purple
          icon: Icons.cloud_done_outlined,
          label: 'File uploaded',
          description: 'Waiting for geometry analysis to start',
          badge: 'QUEUED',
        );
    }
  }
}