import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/admin_signup_screen.dart';
import '../../features/auth/presentation/screens/invite_user_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import 'app_routes.dart';

/// Router principal de l'application.
///
/// Gère la navigation entre toutes les screens.
/// Le token d'invitation est passé via query parameter :
/// /register?token=abc123
final appRouter = GoRouter(
  initialLocation: AppRoutes.adminSignup,
  debugLogDiagnostics: true, // logs navigation en console
  routes: [

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