import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../../../../../shared/widgets/responsive_wrapper.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_routes.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  /// Token reçu depuis l'URL — /register?token=abc123
  /// Pour l'instant on simule avec une valeur fixe
  final String token;

  const RegisterScreen({
    super.key,
    this.token = 'tk_mock_test', // ← simulé, viendra du router plus tard
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Données pré-remplies depuis le token — viendront de validateInvite
  String _prefilledEmail = '';
  String _prefilledRole = '';
  String _expiresAt = '';
  bool _isValidating = true; // true pendant la validation du token
  bool _tokenInvalid = false;
  String _formattedTimeRemaining = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _validateToken();
    });
    
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Valide le token au chargement et pré-remplit les données
  Future<void> _validateToken() async {
    final data = await ref
        .read(authProvider.notifier)
        .validateInvite(token: widget.token);

    if (data != null  && data['email'] != null) {
      final expiresAt = DateTime.parse(data['expires_at']);
      final remaining = expiresAt.difference(DateTime.now());
      setState(() {
        _prefilledEmail = data['email'] ?? '';
        _prefilledRole = data['role'] ?? '';
        _expiresAt = data['expires_at'] ?? '';
        _formattedTimeRemaining = _formatDuration(remaining);
        _isValidating = false;
      });
    } else {
      setState(() {
        _isValidating = false;
        _tokenInvalid = true;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).register(
          token: widget.token,
          fullName: _fullNameController.text.trim(),
          password: _passwordController.text,
        );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'operator':
        return 'Operator';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage ?? 'Account created!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(authProvider.notifier).reset();
        context.go(AppRoutes.login);
        // TOdo naviguer vers dashboard après router
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

    // ── Chargement validation token ──
    if (_isValidating) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // ── Token invalide ──
    if (_tokenInvalid) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: ResponsiveWrapper(
            child: AuthCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link_off_outlined,
                        color: AppColors.error, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Invalid Invitation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This invitation link is invalid, expired, or has already been used.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Please contact your administrator to request a new invitation.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Formulaire principal ──
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ResponsiveWrapper(
            child: Column(
              children: [

                // ── Carte invitation info ──
                _buildInviteInfoCard(),
                const SizedBox(height: 16),

                // ── Header ──
                AuthHeader(
                  icon: Icons.person_add_outlined,
                  title: 'Create Your Account',
                  subtitle: 'Complete your registration to join 3DP PrintAI',
                ),
                const SizedBox(height: 16),

                // ── Timer expiration ──
                _buildExpiryBanner(),
                const SizedBox(height: 20),

                // ── Formulaire ──
                Form(
                  key: _formKey,
                  child: AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Email — lecture seule
                        AuthTextField(
                          label: 'Email Address',
                          hint: _prefilledEmail,
                          controller:
                              TextEditingController(text: _prefilledEmail),
                          readOnly: true,
                          helperText: 'Pre-filled from invitation',
                        ),
                        const SizedBox(height: 16),

                        // Full Name
                        AuthTextField(
                          label: 'Full Name',
                          hint: 'John Doe',
                          controller: _fullNameController,
                          validator: (v) =>
                              Validators.validateRequired(v, 'Full name'),
                        ),
                        const SizedBox(height: 14),

                        // Password
                        AuthTextField(
                          label: 'Password',
                          hint: 'Create a strong password',
                          controller: _passwordController,
                          isPassword: true,
                          helperText:
                              'Minimum 8 characters with uppercase, lowercase, number, and special character',
                          validator: Validators.validatePassword,
                        ),
                        const SizedBox(height: 14),

                        // Confirm Password
                        AuthTextField(
                          label: 'Confirm Password',
                          hint: 'Re-enter your password',
                          controller: _confirmPasswordController,
                          isPassword: true,
                          validator: (v) =>
                              Validators.validateConfirmPassword(
                            v,
                            _passwordController.text,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Token ID
                        Text(
                          'Token ID: ${widget.token}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bouton
                        AuthPrimaryButton(
                          label: 'Accept Invitation & Create Account',
                          icon: Icons.people_outline,
                          isLoading: authState.isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Carte info invitation ─────────────────────────────────────────────
  Widget _buildInviteInfoCard() {
    final roleLabel = _formatRole(_prefilledRole);
    final isAdmin = _prefilledRole == 'admin';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          // Icône rôle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAdmin ? Icons.shield_outlined : Icons.people_outline,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$roleLabel Invitation',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'You\'ve been invited to join the team',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: $roleLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner expiration ─────────────────────────────────────────────────
Widget _buildExpiryBanner() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.accent.withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.access_time_outlined,
          size: 16,
          color: Colors.black87,
        ),
        const SizedBox(width: 8),
        Text(
          'Invitation expires in: $_formattedTimeRemaining',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}
}