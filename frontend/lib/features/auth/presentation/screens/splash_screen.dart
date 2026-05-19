import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_providers.dart';
import '../../../../../main.dart' as app_main show initialWebRoute, pendingPushRoute;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authViewModelProvider.notifier).checkSession();
    });
  }

  void _go(String route) {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authViewModelProvider, (_, next) {
      switch (next.sessionStatus) {
        case SessionStatus.notInitialized:
          _go(AppRoutes.adminSignup);
        case SessionStatus.unauthenticated:
          // Honour invite / reset-password links even when not logged in
          if (app_main.initialWebRoute.startsWith(AppRoutes.register) ||
              app_main.initialWebRoute.startsWith(AppRoutes.resetPassword)) {
            _go(app_main.initialWebRoute);
          } else {
            _go(AppRoutes.login);
          }
        case SessionStatus.authenticated:
          // Don't override public token-based routes (invite, reset-password)
          if (app_main.initialWebRoute.startsWith(AppRoutes.register) ||
              app_main.initialWebRoute.startsWith(AppRoutes.resetPassword)) {
            _go(app_main.initialWebRoute);
          } else if (app_main.pendingPushRoute.isNotEmpty) {
            // Cold-start push tap — deep-link instead of the default landing.
            final target = app_main.pendingPushRoute;
            app_main.pendingPushRoute = '';
            _go(target);
          } else {
            _go(AppRoutes.upload);
          }
        case SessionStatus.unknown:
          break;
      }
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
