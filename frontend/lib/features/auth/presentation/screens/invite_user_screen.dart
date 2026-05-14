import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/constants/app_strings.dart';
import '../providers/auth_providers.dart';
import '../../domain/auth_state.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';

// ── Screen ──────────────────────────────────────────────────────────────────
class InviteUserScreen extends ConsumerStatefulWidget {
  const InviteUserScreen({super.key});

  @override
  ConsumerState<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends ConsumerState<InviteUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _invitationSent = false;
  String _sentEmail = '';

  // True while a resend HTTP call is in flight. Used to dim the
  // resend buttons in the history list and avoid double-clicks.
  bool _resending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authViewModelProvider.notifier).generateInvite(
          email: _emailController.text.trim(),
          role: 'operator',
        );
  }

  void _sendAnother() {
    setState(() {
      _invitationSent = false;
      _sentEmail = '';
      _emailController.clear();
    });
  }

  Future<void> _resend(String invitationId) async {
    setState(() => _resending = true);
    await ref
        .read(authViewModelProvider.notifier)
        .resendInvite(invitationId: invitationId);
    if (mounted) setState(() => _resending = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    ref.listen<AuthState>(authViewModelProvider, (_, next) {
      if (next.status == AuthStatus.success) {
        final message = next.successMessage ?? '';
        final isCreate = _emailController.text.trim().isNotEmpty &&
            !_invitationSent &&
            message.contains('sent to');

        if (isCreate) {
          setState(() {
            _invitationSent = true;
            _sentEmail = _emailController.text.trim();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.isEmpty ? 'Invitation sent' : message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        ref.invalidate(invitationsProvider);
        ref.read(authViewModelProvider.notifier).reset();
      }

      if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'An error occurred'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(authViewModelProvider.notifier).reset();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _invitationSent
                      ? _buildInvitationResult()
                      : _buildInvitationForm(authState),
                  const SizedBox(height: 20),
                  _buildHistory(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form ─────────────────────────────────────────────────────────────────
  Widget _buildInvitationForm(AuthState authState) {
    return AuthCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Invitation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Enter the operator's email address — we'll email them the invitation link",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            AuthTextField(
              label: 'Email Address',
              hint: 'user@company.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: AppStrings.inviteButton,
              icon: Icons.mail_outline,
              isLoading: authState.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  // ── Result card (email-sent confirmation) ─────────────────────────────────
  Widget _buildInvitationResult() {
    return AuthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_outlined,
                      color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invitation Email Sent',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'We emailed the invitation link to $_sentEmail',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _InfoRow(label: 'Email:', value: _sentEmail),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: Text('Role:',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
              Text(
                'Operator',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: Text('Link expires:',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
              Icon(Icons.access_time_outlined,
                  size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                '48 hours',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Didn't receive it? You can resend from the history list below.",
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AuthPrimaryButton(
            label: 'Send Another Invitation',
            onPressed: _sendAnother,
          ),
        ],
      ),
    );
  }

  // ── History ───────────────────────────────────────────────────────────────
  Widget _buildHistory() {
    final invitationsAsync = ref.watch(invitationsProvider);

    return AuthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitation History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Track all sent invitations and their status',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.invalidate(invitationsProvider),
                icon: const Icon(Icons.refresh_outlined,
                    size: 20, color: AppColors.textSecondary),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          invitationsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load invitations',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error.withValues(alpha: 0.8)),
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No invitations sent yet',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return Column(
                children: items
                    .map((item) => _InviteHistoryTile(
                          item: item,
                          resending: _resending,
                          onResend: () => _resend(item['id'] as String),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person_add_outlined,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite Operator',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Send invitation emails to onboard new operators',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── History Tile ──────────────────────────────────────────────────────────────
class _InviteHistoryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool resending;
  final VoidCallback onResend;

  const _InviteHistoryTile({
    required this.item,
    required this.resending,
    required this.onResend,
  });

  String get _status => item['status'] as String? ?? 'pending';

  Color get _statusColor {
    switch (_status) {
      case 'used':
        return AppColors.success;
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.accent;
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'used':
        return Icons.check_circle_outline;
      case 'expired':
        return Icons.cancel_outlined;
      default:
        return Icons.access_time_outlined;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'used':
        return 'Used';
      case 'expired':
        return 'Expired';
      default:
        return 'Pending';
    }
  }

  String _formatSentDate() {
    try {
      final dt = DateTime.parse(item['created_at'] as String);
      final local = dt.toLocal();
      return '${local.day.toString().padLeft(2, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatTimeInfo() {
    if (_status == 'used') return 'Used';
    if (_status == 'expired') return 'Expired';
    try {
      final expires = DateTime.parse(item['expires_at'] as String).toLocal();
      final remaining = expires.difference(DateTime.now());
      if (remaining.isNegative) return 'Expired';
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      if (hours > 0) return '${hours}h ${minutes}m left';
      return '${minutes}m left';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = item['email'] as String? ?? '';
    final sentDate = _formatSentDate();
    final timeInfo = _formatTimeInfo();
    final canResend = _status != 'used';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Operator • $sentDate • $timeInfo',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (canResend) ...[
              IconButton(
                onPressed: resending ? null : onResend,
                icon: const Icon(Icons.send_outlined, size: 18),
                color: AppColors.primary,
                tooltip: 'Resend invitation',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _statusColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon, size: 12, color: _statusColor),
                  const SizedBox(width: 4),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
