import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../providers/job_providers.dart';

class SubmitJobDialog extends ConsumerStatefulWidget {
  final String stlFileId;
  final String? recommendationId;
  final String? stlFileName;

  const SubmitJobDialog({
    super.key,
    required this.stlFileId,
    this.recommendationId,
    this.stlFileName,
  });

  static Future<void> show(
    BuildContext context, {
    required String stlFileId,
    String? recommendationId,
    String? stlFileName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubmitJobDialog(
        stlFileId: stlFileId,
        recommendationId: recommendationId,
        stlFileName: stlFileName,
      ),
    );
  }

  @override
  ConsumerState<SubmitJobDialog> createState() => _SubmitJobDialogState();
}

class _SubmitJobDialogState extends ConsumerState<SubmitJobDialog> {
  int _priority = 3;
  bool _loading = false;

  static const _priorityLabels = ['', 'Low', 'Low', 'Normal', 'High', 'Urgent'];
  static const _priorityColors = [
    Colors.transparent,
    Color(0xFF34C759),
    Color(0xFF4B6BFB),
    Color(0xFF4B6BFB),
    Color(0xFFFF9500),
    Color(0xFFFF3B30),
  ];

  Color get _activeColor => _priorityColors[_priority];
  String get _activeLabel => _priorityLabels[_priority];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 40 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: const Color(0x1A3C3C43),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Submit to Print',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B6BFB).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.view_in_ar_rounded,
                              color: Color(0xFF4B6BFB), size: 15),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.stlFileName ?? 'model.stl',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF8E8E93)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF8E8E93)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Priority selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Priority',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
              Text('$_activeLabel · $_priority',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _activeColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final n = i + 1;
              final active = n <= _priority;
              final col = _priorityColors[n];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 7 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 42,
                      decoration: BoxDecoration(
                        color: active ? col : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(11),
                        border: active
                            ? null
                            : Border.all(color: const Color(0x1A3C3C43), width: 1.5),
                      ),
                      child: Center(
                        child: Text('$n',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : const Color(0xFF8E8E93))),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Low', style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                Text('Urgent', style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _SummaryRow(label: 'Printer', value: 'Auto-assign'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Divider(height: 0.5, color: Color(0x1A3C3C43)),
                ),
                _SummaryRow(label: 'Est. time', value: '~2h 30m'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Divider(height: 0.5, color: Color(0x1A3C3C43)),
                ),
                _SummaryRow(label: 'Est. cost', value: '3.50 TND'),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                    side: const BorderSide(color: Color(0x1A3C3C43), width: 1.5),
                    foregroundColor: const Color(0xFF8E8E93),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4B6BFB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                    shadowColor:
                        const Color(0xFF4B6BFB).withValues(alpha: 0.38),
                    elevation: 8,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Job',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(jobRepositoryProvider).submitJob(
            stlFileId: widget.stlFileId,
            recommendationId: widget.recommendationId,
            stlFileName: widget.stlFileName,
            priority: _priority,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ref.invalidate(myJobsProvider);
        context.go(AppRoutes.jobQueue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job submitted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit job: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
      ],
    );
  }
}
