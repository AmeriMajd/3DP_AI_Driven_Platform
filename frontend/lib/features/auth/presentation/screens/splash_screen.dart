import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/services/storage_service.dart';
import '../../data/auth_repository_impl.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authRepo = AuthRepositoryImpl();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  void _go(String route) {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(route);
  }

  Future<void> _checkSession() async {
    try {
      final accessToken = await StorageService.getToken();
      final refreshToken = await StorageService.getRefreshToken();

      if (accessToken == null || accessToken.isEmpty) {
        _go(AppRoutes.login);
        return;
      }

      bool expired;
      try {
        expired = JwtDecoder.isExpired(accessToken);
      } catch (e) {
        await StorageService.clearAll();
        _go(AppRoutes.login);
        return;
      }
      if (!expired) {}

      if (refreshToken == null || refreshToken.isEmpty) {
        await StorageService.clearAll();
        _go(AppRoutes.login);
        return;
      }
      final refreshed = await _authRepo.tryRefreshSession();

      if (refreshed) {
        _go(AppRoutes.upload);
      } else {
        await StorageService.clearAll();
        _go(AppRoutes.login);
      }
    } catch (e, st) {
      await StorageService.clearAll();
      _go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
