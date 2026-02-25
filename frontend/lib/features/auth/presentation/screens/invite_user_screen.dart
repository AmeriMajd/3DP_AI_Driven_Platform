import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';

// ── Modèle mock pour l'historique ──────────────────────────────────────────
enum InviteStatus { pending, used, expired }

class InviteHistoryItem {
  final String email;
  final String role;
  final String sentDate;
  final String timeInfo;
  final bool timeIsColored; // true = afficher en bleu (temps restant)
  final InviteStatus status;

  const InviteHistoryItem({
    required this.email,
    required this.role,
    required this.sentDate,
    required this.timeInfo,
    this.timeIsColored = false,
    required this.status,
  });
}

// ── Screen ──────────────────────────────────────────────────────────────────
class InviteUserScreen extends ConsumerStatefulWidget {
  const InviteUserScreen({super.key});

   @override
  ConsumerState<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends ConsumerState<InviteUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // Rôle sélectionné — 'admin' ou 'operator'
  String _selectedRole = 'operator';

  // ── État invitation générée ──
  bool _invitationGenerated = false;
  String _generatedEmail = '';
  String _generatedRole = '';
  String _generatedLink = '';

   // ── Liste Des Données ──────────────────────────
  List<InviteHistoryItem> _history = [
    const InviteHistoryItem(
      email: 'sarah@company.com',
      role: 'Admin',
      sentDate: '21-02-2026',
      timeInfo: 'Expired',
      status: InviteStatus.expired,
    ),
    const InviteHistoryItem(
      email: 'mike@company.com',
      role: 'Operator',
      sentDate: '22-02-2026',
      timeInfo: '13 hours',
      timeIsColored: true,
      status: InviteStatus.pending,
    ),
    const InviteHistoryItem(
      email: 'lisa@company.com',
      role: 'Operator',
      sentDate: '10-02-2026',
      timeInfo: 'Expired',
      status: InviteStatus.expired,
    ),
    const InviteHistoryItem(
      email: 'john@company.com',
      role: 'Admin',
      sentDate: '18-02-2026',
      timeInfo: 'Used',
      status: InviteStatus.used,
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).generateInvite(
          email: _emailController.text.trim(),
          role: _selectedRole,
        );
  }

  void _sendAnother(){
    setState(() {
      _invitationGenerated= false;
      _generatedEmail='';
      _generatedRole = '';
     _generatedLink = '';
     _emailController.clear();
     _selectedRole= 'operator';

    });
  }
  
  @override
  Widget build(BuildContext context){
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      print('>>> STATUS: ${next.status}');
      print('>>> SUCCESS MSG: ${next.successMessage}');
      if (next.status == AuthStatus.success){
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        setState(() {
          _history.insert(0, 
          InviteHistoryItem(email: _emailController.text.trim(),
        role: _selectedRole == 'admin' ? 'Admin' : 'Operator',
        sentDate: dateStr,
        timeInfo: '48 hours',
        timeIsColored: true,
        status: InviteStatus.pending,
        ),
        );
        
        _invitationGenerated = true;
          _generatedEmail = _emailController.text.trim();
          _generatedRole = _selectedRole;
          //remplacer par response.data['link'] du backend
          _generatedLink = 'https://printai.app/invite?token=abc123xyz';
          
        });
        ref.read(authProvider.notifier).reset();
      }

      if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'An error occurred'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(authProvider.notifier).reset();
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

                  // ── Header ──────────────────────────────────────────────
                  _buildHeader(),
                  const SizedBox(height: 20),

                  // ── Section 1 : Formulaire ou Résultat Invitation ────────────────────────
                  _invitationGenerated ? _buildInvitationResult() 
                      : _buildInvitationForm(authState),
                  const SizedBox(height: 20),

                  // ── Section 2 : Invitation History ───────────────────────
                  _buildHistory(),      
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// ── Formulaire d'invitation ──────────────────────────────────────────────
  Widget _buildInvitationForm(AuthState authState) {
    return AuthCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Titre section
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
                            'Enter user details and select their access level',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email
                          AuthTextField(
                            label: 'Email Address',
                            hint: 'user@company.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.validateEmail,
                          ),
                          const SizedBox(height: 20),

                          // Role selector
                          const Text(
                            'Role',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Carte Administrator
                          _RoleCard(
                            title: 'Administrator',
                            description:
                                'Manage users, printers, settings, analytics, and create invitations',
                            icon: Icons.shield_outlined,
                            value: 'admin',
                            groupValue: _selectedRole,
                            onTap: () =>
                                setState(() => _selectedRole = 'admin'),
                          ),
                          const SizedBox(height: 10),

                          // Carte Operator
                          _RoleCard(
                            title: 'Operator',
                            description:
                                'Upload models, schedule prints, monitor jobs, and view fleet',
                            icon: Icons.people_outline,
                            value: 'operator',
                            groupValue: _selectedRole,
                            onTap: () =>
                                setState(() => _selectedRole = 'operator'),
                          ),
                          const SizedBox(height: 24),

                          // Bouton
                          AuthPrimaryButton(
                            label: AppStrings.inviteButton,
                            icon: Icons.person_add_outlined,
                            isLoading: authState.isLoading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  );
  }
  // ── Carte résultat après génération ────────────────────────────────────
  Widget _buildInvitationResult() {
    final roleLabel = _generatedRole =='admin' ? 'Administrator' : 'Operator';

    return AuthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Vert
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2)),
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
                  child: const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invitation Generated',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'Share this link with $_generatedEmail',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Infos ──
          _InfoRow(label: 'Email:', value: _generatedEmail),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Role:',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
              Text(
                roleLabel,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              // Badge Pending
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: Text('Expires:',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
              Icon(Icons.access_time_outlined,
                  size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                '48 hours',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Lien copiable ──
          const Text(
            'Invitation Link',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _generatedLink,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _generatedLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Icon(Icons.copy_outlined,
                        size: 16, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Bouton QR ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TOdo afficher QR code
              },
              icon: const Icon(Icons.qr_code_outlined,
                  size: 18, color: AppColors.textPrimary),
              label: const Text(
                'Show QR Code',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Bouton Send Another ──
          AuthPrimaryButton(
            label: 'Send Another Invitation',
            onPressed: _sendAnother,
          ),
        ],

    ),
    );
  }

   // ── Historique ───────────────────────────────────────────────────────────
  Widget _buildHistory() {
    return AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invitation History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Track all sent invitations and their status',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Liste mockée
                        ..._history.map(
                          (item) => _InviteHistoryTile(item: item),
                        ),
                      ],
                    ),
                  );
  }
  // ── Header widget ──────────────────────────────────────────────────────
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
        Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Invite New User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Generate secure invitation tokens for new team members',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        ),
      ],
    );
  }
}
// ── Info Row ─────────────────────────────────────────────────────────────────
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

// ── Role Card Widget ────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String value;
  final String groupValue;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  bool get _isSelected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isSelected
              ? AppColors.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isSelected ? AppColors.primary : AppColors.borderLight,
            width: _isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Bullet / radio indicator
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: _isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Icône droite
            Icon(icon,
                color: _isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 20),
          ],
        ),
      ),
    );
  }
}

// ── History Tile Widget ─────────────────────────────────────────────────────
class _InviteHistoryTile extends StatelessWidget {
  final InviteHistoryItem item;

  const _InviteHistoryTile({required this.item});

  Color get _statusColor {
    switch (item.status) {
      case InviteStatus.used:
        return AppColors.success;
      case InviteStatus.pending:
        return AppColors.accent;
      case InviteStatus.expired:
        return AppColors.error;
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case InviteStatus.used:
        return Icons.check_circle_outline;
      case InviteStatus.pending:
        return Icons.access_time_outlined;
      case InviteStatus.expired:
        return Icons.cancel_outlined;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case InviteStatus.used:
        return 'Used';
      case InviteStatus.pending:
        return 'Pending';
      case InviteStatus.expired:
        return 'Expired';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    Text(
                      item.email,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.role} • ${item.sentDate} • ${item.timeInfo}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
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