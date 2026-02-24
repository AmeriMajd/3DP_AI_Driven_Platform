import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../shared/widgets/responsive_wrapper.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';

class AdminSignupScreen extends ConsumerStatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  ConsumerState<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends ConsumerState<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).adminSignup(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage ?? 'Success'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(authProvider.notifier).reset();
        /// TOdo naviguer vers dashboard
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
        child:Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ResponsiveWrapper(
            child: Column(
              children: [
                // ── Header hors carte ──
                AuthHeader(
                  icon: Icons.shield_outlined,
                  title: 'System Setup',
                  subtitle: 'First Admin Registration',
                  badgeText: "You're creating the first admin account for this system",
                  badgeDescription:
                      'This account will have full system access and control over user invitations.',
                ),
                const SizedBox(height: 20),

                // ── Formulaire dans carte ──
                Form(
                  key: _formKey,
                  child: AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Full Name ──
                        AuthTextField(
                          label: AppStrings.fieldFullName,
                          hint: AppStrings.hintFullName,
                          controller: _fullNameController,
                          validator: (v) =>
                              Validators.validateRequired(v, 'Full name'),
                        ),
                        const SizedBox(height: 16),

                        // ── Email ──
                        AuthTextField(
                          label: AppStrings.fieldEmail,
                          hint: 'admin@company.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 16),

                        // ── Password ──
                        AuthTextField(
                          label: AppStrings.fieldPassword,
                          hint: AppStrings.hintPassword,
                          controller: _passwordController,
                          isPassword: true,
                          helperText:
                              'At least 8 characters with uppercase, lowercase, and numbers',
                          validator: Validators.validatePassword,
                        ),
                        const SizedBox(height: 16),

                        // ── Confirm Password ──
                        AuthTextField(
                          label: AppStrings.fieldConfirmPassword,
                          hint: AppStrings.hintConfirmPassword,
                          controller: _confirmPasswordController,
                          isPassword: true,
                          validator: (v) =>
                              Validators.validateConfirmPassword(
                            v,
                            _passwordController.text,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Footer note dans carte ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.shield_outlined,
                                  size: 16, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'After this, all users must be invited by an administrator. Only admins can generate invitation tokens.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Submit Button ──
                        AuthPrimaryButton(
                          label: 'Create Admin Account & Initialize System',
                          icon: Icons.check_circle_outline,
                          isLoading: authState.isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Footer bas de page ──
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.print_outlined,
                        size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'PrintAI 3D Lab Management System',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}