import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_providers.dart';

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
          _go(AppRoutes.login);
        case SessionStatus.authenticated:
          _go(AppRoutes.upload);
        case SessionStatus.unknown:
          break;
      }
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
