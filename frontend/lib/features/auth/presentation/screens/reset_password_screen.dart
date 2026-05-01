import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/router/app_routes.dart';
import '../providers/auth_providers.dart';
import '../../domain/auth_state.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/login_text_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;

  const ResetPasswordScreen({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isValidating = true;
  bool _tokenInvalid = false;
  bool _resetSuccess = false;
  String _prefilledEmail = '';
  String _formattedTimeRemaining = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateToken();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final data = await ref
          .read(authViewModelProvider.notifier)
          .validateResetToken(token: widget.token);

      if (!mounted) return;

      if (data != null && data['email'] != null) {
        final expiresAt = DateTime.parse(data['expires_at']);
        final remaining = expiresAt.difference(DateTime.now());
        setState(() {
          _prefilledEmail = data['email'] ?? '';
          _formattedTimeRemaining = _formatDuration(remaining);
          _isValidating = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isValidating = false;
          _tokenInvalid = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _tokenInvalid = true;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authViewModelProvider.notifier).resetPassword(
          token: widget.token,
          newPassword: _passwordController.text,
        );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '$minutes minutes';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    ref.listen<AuthState>(authViewModelProvider, (_, next) {
      if (next.status == AuthStatus.success) {
        setState(() => _resetSuccess = true);
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(10, 200, 240, 10),
              Color(0xFFF5F5FF),
              Color.fromARGB(20, 62, 55, 201),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _isValidating
                    ? _buildLoading()
                    : _tokenInvalid
                        ? _buildInvalidToken()
                        : _resetSuccess
                            ? _buildSuccess()
                            : _buildForm(authState),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  // ── Token invalide ───────────────────────────────────────────────────────
  Widget _buildInvalidToken() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.link_off_outlined,
            color: AppColors.error,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Link Expired',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This reset link is invalid, expired, or has already been used.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        AuthPrimaryButton(
          label: 'Request a New Link',
          icon: Icons.refresh_outlined,
          onPressed: () => context.go(AppRoutes.forgotPassword),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.go(AppRoutes.login),
          child: const Text(
            'Back to Login',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Formulaire ───────────────────────────────────────────────────────────
  Widget _buildForm(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Back
        GestureDetector(
          onTap: () => context.go(AppRoutes.login),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.arrow_back_ios_new_outlined,
                  size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'Back to Login',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // Icône
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_open_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Titre
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Create a new password for $_prefilledEmail',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),

        // Expiry banner
        _buildExpiryBanner(),
        const SizedBox(height: 28),

        // Form
        Form(
          key: _formKey,
          child: Column(
            children: [
              LoginTextField(
                label: 'New Password',
                hint: 'Create a strong password',
                controller: _passwordController,
                isPassword: true,
                prefixIcon: Icons.lock_outline,
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 16),
              LoginTextField(
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                controller: _confirmPasswordController,
                isPassword: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) => Validators.validateConfirmPassword(
                  v,
                  _passwordController.text,
                ),
              ),
              const SizedBox(height: 28),
              AuthPrimaryButton(
                label: 'Reset Password',
                icon: Icons.check_outlined,
                isLoading: authState.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Succès ───────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Password Reset!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your password has been updated successfully. You can now sign in with your new password.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        AuthPrimaryButton(
          label: 'Sign In',
          icon: Icons.login_outlined,
          onPressed: () => context.go(AppRoutes.login),
        ),
      ],
    );
  }

  // ── Expiry banner ────────────────────────────────────────────────────────
  Widget _buildExpiryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_outlined,
              size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            'Link expires in: $_formattedTimeRemaining',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}