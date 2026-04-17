import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/admin_signup_screen.dart';
import '../../features/auth/presentation/screens/invite_user_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/upload/presentation/screens/upload_screen.dart';
import '../../features/upload/presentation/screens/FileDetailScreen.dart';
import '../../features/recommendation/presentation/screens/recommendation_form_screen.dart';
import '../../features/recommendation/presentation/screens/recommendation_result_screen.dart';
import '../../features/recommendation/domain/recommendation_result.dart';
import '../../shared/widgets/placeholder_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';

import 'app_routes.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: true,
  routerNeglect: false, // logs navigation en console
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    // ── Auth routes (sans navbar) ─────────────────────────────────────────
    // ── Admin Signup ──
    GoRoute(
      path: AppRoutes.adminSignup,
      name: AppRoutes.adminSignup,
      builder: (context, state) => const AdminSignupScreen(),
    ),

    // ── Invite User ──
    GoRoute(
      path: AppRoutes.inviteUser,
      name: AppRoutes.inviteUser,
      builder: (context, state) => const InviteUserScreen(),
    ),

    // ── Register — reçoit le token via query param ──
    // URL : /register?token=abc123xyz
    GoRoute(
      path: AppRoutes.register,
      name: AppRoutes.register,
      builder: (context, state) {
        // Récupère le token depuis l'URL
        final token = state.uri.queryParameters['token'] ?? '';
        return RegisterScreen(token: token);
      },
    ),

    // ── login ──
    GoRoute(
      path: AppRoutes.login,
      name: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),

    // ── forgot Password ──
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: AppRoutes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    GoRoute(
      path: AppRoutes.resetPassword,
      name: AppRoutes.resetPassword,
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return ResetPasswordScreen(token: token);
      },
    ),

    // ── Main routes (avec navbar) ─────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.upload,
          builder: (_, _) => const UploadScreen(),
        ),
        GoRoute(
          path: AppRoutes.fleet,
          builder: (_, _) => const PlaceholderScreen(title: 'Printers'),
        ),
        GoRoute(
          path: AppRoutes.schedule,
          builder: (_, _) => const PlaceholderScreen(title: 'schedule'),
        ),
        GoRoute(
          path: AppRoutes.monitoring,
          builder: (_, _) => const PlaceholderScreen(title: 'Monitoring'),
        ),

        // ── File detail & recommendation — navbar visible, no AppBar ──
        GoRoute(
          path: '/upload/file/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return FileDetailScreen(fileId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.recommendForm,
          name: AppRoutes.recommendForm,
          builder: (context, state) {
            final fileId = state.uri.queryParameters['fileId'] ?? '';
            final indexParam = int.tryParse(
                state.uri.queryParameters['orientation'] ?? '');
            final rank = indexParam != null ? indexParam + 1 : null;
            return RecommendationFormScreen(
              fileId: fileId,
              orientationRank: rank,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.recommendResult,
          name: AppRoutes.recommendResult,
          builder: (context, state) {
            final result = state.extra as RecommendationResult?;
            return RecommendationResultScreen(result: result);
          },
        ),
      ],
    ),
  ],

  // ── Page 404 ──
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found: ${state.uri}',
        style: const TextStyle(fontSize: 16),
      ),
    ),
  ),
);
