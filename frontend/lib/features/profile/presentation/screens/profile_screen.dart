import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/profile_user.dart';
import '../../domain/profile_state.dart';
import '../providers/profile_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

enum _SubScreen { main, editName, editEmail, changePwd }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _SubScreen _current = _SubScreen.main;

  // edit name
  final _nameCtrl = TextEditingController();

  // edit email
  final _emailCtrl = TextEditingController();
  final _emailPwdCtrl = TextEditingController();

  // change password
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _confirmRevokeVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileViewModelProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _emailPwdCtrl.dispose();
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  void _goTo(_SubScreen s) => setState(() => _current = s);

  void _handleBack() {
    if (_current != _SubScreen.main) {
      setState(() => _current = _SubScreen.main);
    } else {
      context.pop();
    }
  }

  String _subTitle(_SubScreen s) {
    switch (s) {
      case _SubScreen.editName:
        return 'Edit Name';
      case _SubScreen.editEmail:
        return 'Change Email';
      case _SubScreen.changePwd:
        return 'Change Password';
      default:
        return 'Account';
    }
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      _showSnack('Name must be at least 2 characters', isError: true);
      return;
    }
    await ref.read(profileViewModelProvider.notifier).updateName(name);
    if (!mounted) return;
    final state = ref.read(profileViewModelProvider);
    if (state.status == ProfileStatus.success) {
      _nameCtrl.clear();
      setState(() => _current = _SubScreen.main);
      _showSnack(state.successMessage ?? 'Name updated');
    } else if (state.errorMessage != null) {
      _showSnack(state.errorMessage!, isError: true);
    }
  }

  Future<void> _saveEmail() async {
    if (_emailPwdCtrl.text.isEmpty) {
      _showSnack('Enter your current password to confirm', isError: true);
      return;
    }
    await ref.read(profileViewModelProvider.notifier).updateEmail(_emailCtrl.text.trim());
    if (!mounted) return;
    final state = ref.read(profileViewModelProvider);
    if (state.status == ProfileStatus.success) {
      _emailCtrl.clear();
      _emailPwdCtrl.clear();
      setState(() => _current = _SubScreen.main);
      _showSnack(state.successMessage ?? 'Email updated');
    } else if (state.errorMessage != null) {
      _showSnack(state.errorMessage!, isError: true);
    }
  }

  Future<void> _savePassword() async {
    if (_oldPwdCtrl.text.isEmpty ||
        _newPwdCtrl.text.isEmpty ||
        _confirmPwdCtrl.text.isEmpty) {
      _showSnack('Please fill all fields', isError: true);
      return;
    }
    if (_newPwdCtrl.text != _confirmPwdCtrl.text) {
      _showSnack('Passwords do not match', isError: true);
      return;
    }
    if (_newPwdCtrl.text.length < 8) {
      _showSnack('Password too short (min 8 chars)', isError: true);
      return;
    }
    await ref.read(profileViewModelProvider.notifier).changePassword(
          currentPassword: _oldPwdCtrl.text,
          newPassword: _newPwdCtrl.text,
        );
    if (!mounted) return;
    final state = ref.read(profileViewModelProvider);
    if (state.status == ProfileStatus.success) {
      _oldPwdCtrl.clear();
      _newPwdCtrl.clear();
      _confirmPwdCtrl.clear();
      setState(() => _current = _SubScreen.main);
      _showSnack(state.successMessage ?? 'Password changed');
    } else if (state.errorMessage != null) {
      _showSnack(state.errorMessage!, isError: true);
    }
  }

  Future<void> _revokeAllSessions() async {
    setState(() => _confirmRevokeVisible = false);
    await ref.read(profileViewModelProvider.notifier).revokeAllSessions();
    if (!mounted) return;
    final state = ref.read(profileViewModelProvider);
    if (state.status == ProfileStatus.success) {
      _showSnack(state.successMessage ?? 'All sessions revoked');
    } else if (state.errorMessage != null) {
      _showSnack(state.errorMessage!, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileViewModelProvider);
    final isLoading = profileState.status == ProfileStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F0F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          color: const Color(0xFF0F0E1A),
          onPressed: _handleBack,
        ),
        title: Text(
          _subTitle(_current),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F0E1A),
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (profileState.status == ProfileStatus.loading && profileState.user == null)
            const Center(child: CircularProgressIndicator())
          else if (profileState.status == ProfileStatus.error && profileState.user == null)
            _ErrorRetry(
              message: profileState.errorMessage ?? 'Failed to load profile',
              onRetry: () => ref.read(profileViewModelProvider.notifier).loadProfile(),
            )
          else ...[
            _currentView(profileState.user, isLoading),
            if (_confirmRevokeVisible) _RevokeConfirmSheet(
              onConfirm: _revokeAllSessions,
              onCancel: () => setState(() => _confirmRevokeVisible = false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _currentView(ProfileUser? user, bool isLoading) {
    switch (_current) {
      case _SubScreen.editName:
        return _EditNameView(
          ctrl: _nameCtrl,
          isLoading: isLoading,
          onSave: _saveName,
        );
      case _SubScreen.editEmail:
        return _EditEmailView(
          emailCtrl: _emailCtrl,
          pwdCtrl: _emailPwdCtrl,
          isLoading: isLoading,
          onSave: _saveEmail,
        );
      case _SubScreen.changePwd:
        return _ChangePwdView(
          oldCtrl: _oldPwdCtrl,
          newCtrl: _newPwdCtrl,
          confirmCtrl: _confirmPwdCtrl,
          showOld: _showOld,
          showNew: _showNew,
          showConfirm: _showConfirm,
          onToggleOld: () => setState(() => _showOld = !_showOld),
          onToggleNew: () => setState(() => _showNew = !_showNew),
          onToggleConfirm: () => setState(() => _showConfirm = !_showConfirm),
          isLoading: isLoading,
          onSave: _savePassword,
        );
      default:
        return _MainView(
          user: user,
          onEditName: () {
            _nameCtrl.text = user?.fullName ?? '';
            _goTo(_SubScreen.editName);
          },
          onEditEmail: () {
            _emailCtrl.text = user?.email ?? '';
            _goTo(_SubScreen.editEmail);
          },
          onChangePwd: () => _goTo(_SubScreen.changePwd),
          onRevokeAll: () => setState(() => _confirmRevokeVisible = true),
          onInvite: () => context.push(AppRoutes.inviteUser),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main view
// ─────────────────────────────────────────────────────────────────────────────

class _MainView extends StatelessWidget {
  final ProfileUser? user;
  final VoidCallback onEditName;
  final VoidCallback onEditEmail;
  final VoidCallback onChangePwd;
  final VoidCallback onRevokeAll;
  final VoidCallback onInvite;

  const _MainView({
    required this.user,
    required this.onEditName,
    required this.onEditEmail,
    required this.onChangePwd,
    required this.onRevokeAll,
    required this.onInvite,
  });

  String get _initials {
    final parts = (user?.fullName ?? 'U').trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return (user?.fullName ?? 'U')[0].toUpperCase();
  }

  String _memberSince() {
    if (user == null) return '—';
    final d = user!.createdAt;
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _lastLogin() {
    if (user?.lastLogin == null) return 'Unknown';
    final diff = DateTime.now().difference(user!.lastLogin!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = user?.role == 'admin';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Hero card ──────────────────────────────────────────────────────
        _Card(
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.27),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? '—',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F0E1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6A7A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (user?.role ?? 'operator').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Stats row ──────────────────────────────────────────────────────
        Row(
          children: [
            _StatCard(
              value: '${user?.stats.filesUploaded ?? 0}',
              label: 'Files uploaded',
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              value: '${user?.stats.recommendationsCount ?? 0}',
              label: 'Recommendations',
              color: const Color(0xFFF5A623),
            ),
            const SizedBox(width: 8),
            _StatCard(
              value: '${user?.stats.jobsSubmitted ?? 0}',
              label: 'Jobs submitted',
              color: AppColors.success,
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Last login ─────────────────────────────────────────────────────
        _Card(
          child: Row(
            children: [
              _IconBg(
                child: Icon(Icons.access_time_rounded,
                    size: 16, color: const Color(0xFF9998AA)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Last login',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B6A7A)),
              ),
              const Spacer(),
              Text(
                _lastLogin(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F0E1A),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Personal information ───────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(icon: Icons.person_outline_rounded, title: 'Personal Information'),
              _InfoRow(
                label: 'Full Name',
                value: user?.fullName ?? '—',
                onEdit: onEditName,
              ),
              _InfoRow(
                label: 'Email Address',
                value: user?.email ?? '—',
                onEdit: onEditEmail,
              ),
              _InfoRow(
                label: 'Role',
                value: user?.role == 'admin' ? 'Administrator' : 'Operator',
              ),
              _InfoRow(
                label: 'Member Since',
                value: _memberSince(),
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Security ───────────────────────────────────────────────────────
        _Card(
          child: Column(
            children: [
              _SectionHeader(icon: Icons.shield_outlined, title: 'Security'),
              _RowTile(
                icon: Icons.key_outlined,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: onChangePwd,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Invite operators (admin only) ──────────────────────────────────
        if (isAdmin) ...[
          GestureDetector(
            onTap: onInvite,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3D35D9), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.person_add_outlined,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Operators',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Send an invitation to new team members',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xBFFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Color(0xCCFFFFFF)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Sign out everywhere ────────────────────────────────────────────
        _Card(
          child: _RowTile(
            icon: Icons.phone_android_rounded,
            title: 'Sign Out Everywhere',
            subtitle: 'Revoke all active sessions',
            titleColor: AppColors.error,
            iconBgColor: const Color(0xFFFEF2F2),
            iconColor: AppColors.error,
            onTap: onRevokeAll,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Name view
// ─────────────────────────────────────────────────────────────────────────────

class _EditNameView extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isLoading;
  final VoidCallback onSave;

  const _EditNameView({
    required this.ctrl,
    required this.isLoading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update your display name. This is visible to all team members.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6A7A),
                      height: 1.5),
                ),
                const SizedBox(height: 20),
                _Field(label: 'Full Name', ctrl: ctrl, placeholder: 'Your full name'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Save Changes',
            isLoading: isLoading,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Email view
// ─────────────────────────────────────────────────────────────────────────────

class _EditEmailView extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController pwdCtrl;
  final bool isLoading;
  final VoidCallback onSave;

  const _EditEmailView({
    required this.emailCtrl,
    required this.pwdCtrl,
    required this.isLoading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Changing your email requires confirmation with your current password for security.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF6B6A7A), height: 1.5),
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'New Email Address',
                  ctrl: emailCtrl,
                  placeholder: 'new@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                _Field(
                  label: 'Current Password',
                  ctrl: pwdCtrl,
                  placeholder: 'Enter your password',
                  obscure: true,
                  hint: 'Required to confirm email change',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Update Email',
            isLoading: isLoading,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Password view
// ─────────────────────────────────────────────────────────────────────────────

class _ChangePwdView extends StatelessWidget {
  final TextEditingController oldCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final bool showOld;
  final bool showNew;
  final bool showConfirm;
  final VoidCallback onToggleOld;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final bool isLoading;
  final VoidCallback onSave;

  const _ChangePwdView({
    required this.oldCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
    required this.showOld,
    required this.showNew,
    required this.showConfirm,
    required this.onToggleOld,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.isLoading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a strong password of at least 8 characters.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF6B6A7A), height: 1.5),
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'Current Password',
                  ctrl: oldCtrl,
                  placeholder: 'Your current password',
                  obscure: !showOld,
                  trailing: IconButton(
                    icon: Icon(
                      showOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: const Color(0xFF9998AA),
                    ),
                    onPressed: onToggleOld,
                  ),
                ),
                _Field(
                  label: 'New Password',
                  ctrl: newCtrl,
                  placeholder: 'At least 8 characters',
                  obscure: !showNew,
                  trailing: IconButton(
                    icon: Icon(
                      showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: const Color(0xFF9998AA),
                    ),
                    onPressed: onToggleNew,
                  ),
                ),
                _Field(
                  label: 'Confirm New Password',
                  ctrl: confirmCtrl,
                  placeholder: 'Repeat new password',
                  obscure: !showConfirm,
                  trailing: IconButton(
                    icon: Icon(
                      showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: const Color(0xFF9998AA),
                    ),
                    onPressed: onToggleConfirm,
                  ),
                ),
                _StrengthBar(ctrl: newCtrl),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Change Password',
            isLoading: isLoading,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Revoke confirm bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RevokeConfirmSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _RevokeConfirmSheet({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onCancel,
          child: Container(color: Colors.black54),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sign Out Everywhere?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F0E1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will revoke all active sessions across all your devices. '
                  "You'll need to log in again on each device.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6A7A),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: Color(0xFFE8E8F0), width: 1.5),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B6A7A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Sign Out All',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B6A7A),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F0E1A),
              ),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.onEdit,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE8E8F0), width: 1),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9998AA),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: onEdit != null
                          ? const Color(0xFF0F0E1A)
                          : const Color(0xFF6B6A7A),
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_outlined,
                      size: 15, color: AppColors.primary),
                ),
              ),
          ],
        ),
      );
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconBgColor;
  final Color? iconColor;

  const _RowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconBgColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor ?? const Color(0xFFF4F4F8),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  size: 18, color: iconColor ?? const Color(0xFF0F0E1A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF0F0E1A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9998AA),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: const Color(0xFF9998AA)),
          ],
        ),
      );
}

class _IconBg extends StatelessWidget {
  final Widget child;
  const _IconBg({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: child),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String placeholder;
  final bool obscure;
  final String? hint;
  final Widget? trailing;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.placeholder,
    this.obscure = false,
    this.hint,
    this.trailing,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6A7A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(
                  fontSize: 15, color: Color(0xFF0F0E1A)),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(
                    color: Color(0xFF9998AA), fontSize: 15),
                filled: true,
                fillColor: const Color(0xFFF4F4F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFFE8E8F0), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFFE8E8F0), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                suffixIcon: trailing,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9998AA))),
            ],
          ],
        ),
      );
}

class _StrengthBar extends StatefulWidget {
  final TextEditingController ctrl;
  const _StrengthBar({required this.ctrl});

  @override
  State<_StrengthBar> createState() => _StrengthBarState();
}

class _StrengthBarState extends State<_StrengthBar> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.ctrl.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.ctrl.text.length;
    if (len == 0) return const SizedBox.shrink();

    final Color barColor;
    final String strengthLabel;
    if (len < 6) {
      barColor = AppColors.error;
      strengthLabel = 'Weak';
    } else if (len < 10) {
      barColor = const Color(0xFFF5A623);
      strengthLabel = 'Moderate';
    } else {
      barColor = AppColors.success;
      strengthLabel = 'Strong';
    }

    final filled = (len / 3).floor().clamp(0, 4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < filled ? barColor : const Color(0xFFE8E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
          const SizedBox(height: 4),
          Text(
            strengthLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      );
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF6B6A7A), fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
}
