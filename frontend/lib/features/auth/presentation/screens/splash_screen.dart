import 'dart:math';

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

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigated = false;

  /// Drives the cube rotation + sphere orbits. Slow 14s loop.
  late final AnimationController _spinCtrl;

  /// Drives the indeterminate loading-bar sweep. Fast 1.4s loop.
  late final AnimationController _loadCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      duration: const Duration(seconds: 14),
      vsync: this,
    )..repeat();
    _loadCtrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authViewModelProvider.notifier).checkSession();
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _loadCtrl.dispose();
    super.dispose();
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

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAFAFB), Color(0xFFE4E1EE)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cube + orbiting spheres. Field is oversized so the rotating
              // cube's projected corners never clip.
              SizedBox(
                width: 340,
                height: 340,
                child: AnimatedBuilder(
                  animation: _spinCtrl,
                  builder: (_, _) => _CubeStage(t: _spinCtrl.value),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '3DP',
                style: TextStyle(
                  fontSize: 78,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -4,
                  color: Color(0xFF1A1A2E),
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'AI DRIVEN PLATFORM',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6E6E80),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _loadCtrl,
                builder: (_, _) => _LoadingBar(t: _loadCtrl.value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full splash centrepiece: contact shadow, rotating clay cube, and
/// four spheres orbiting on elliptical paths. [t] is 0..1 loop progress.
class _CubeStage extends StatelessWidget {
  final double t;
  const _CubeStage({required this.t});

  // Each sphere: orbit radii (rx, ry), start phase in turns, size, color.
  static const List<_Orbit> _spheres = [
    _Orbit(rx: 150, ry: 132, phase: 0.90, size: 32, color: Color(0xFFC7F000)),
    _Orbit(rx: 156, ry: 62, phase: 0.50, size: 24, color: Color(0xFF5A52DA)),
    _Orbit(rx: 112, ry: 132, phase: 0.37, size: 20, color: Color(0xFF6B62E8)),
    _Orbit(rx: 150, ry: 84, phase: 0.08, size: 28, color: Color(0xFF4A42C0)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Soft contact shadow under the cube.
        Transform.translate(
          offset: const Offset(0, 118),
          child: Container(
            width: 168,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius:
                  const BorderRadius.all(Radius.elliptical(84, 18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 34,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        ),
        // The rotating clay cube.
        _Cube3D(spin: -30 + t * 360),
        // Orbiting spheres on top.
        for (final o in _spheres)
          Transform.translate(
            offset: o.at(t),
            child: _sphere(size: o.size, color: o.color),
          ),
      ],
    );
  }

  static Widget _sphere({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.95,
          colors: [Colors.white, color],
          stops: const [0.0, 0.9],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

/// Elliptical orbit description for a single sphere.
class _Orbit {
  final double rx, ry, phase, size;
  final Color color;
  const _Orbit({
    required this.rx,
    required this.ry,
    required this.phase,
    required this.size,
    required this.color,
  });

  /// Position offset from stage centre at loop progress [t].
  Offset at(double t) {
    final a = (phase + t) * 2 * pi;
    return Offset(cos(a) * rx, sin(a) * ry);
  }
}

/// Soft-clay 3D cube built from 6 gradient faces stacked with Matrix4
/// transforms. [spin] is the Y-axis rotation in degrees.
class _Cube3D extends StatelessWidget {
  final double spin;
  static const double edge = 142;

  const _Cube3D({required this.spin});

  @override
  Widget build(BuildContext context) {
    const half = edge / 2;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012) // perspective
        ..rotateX(-22 * pi / 180)
        ..rotateY(spin * pi / 180),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden faces — darker, drawn first.
          _face(
            const [Color(0xFF14104A), Color(0xFF0E0B38)],
            Matrix4.identity()..rotateY(pi)..translate(0.0, 0.0, half),
          ),
          _face(
            const [Color(0xFF221C7E), Color(0xFF1A1565)],
            Matrix4.identity()..rotateX(-pi / 2)..translate(0.0, 0.0, half),
          ),
          _face(
            const [Color(0xFF3F37C9), Color(0xFF2A24A0)],
            Matrix4.identity()..rotateY(-pi / 2)..translate(0.0, 0.0, half),
          ),
          // Right face — in shadow.
          _face(
            const [Color(0xFF3A33BE), Color(0xFF241E90)],
            Matrix4.identity()..rotateY(pi / 2)..translate(0.0, 0.0, half),
          ),
          // Top face — lit, lightest.
          _face(
            const [Color(0xFF9089F5), Color(0xFF7B72F0)],
            Matrix4.identity()..rotateX(pi / 2)..translate(0.0, 0.0, half),
          ),
          // Front face — mid tone.
          _face(
            const [Color(0xFF6B62E8), Color(0xFF453CC4)],
            Matrix4.identity()..translate(0.0, 0.0, half),
          ),
        ],
      ),
    );
  }

  Widget _face(List<Color> colors, Matrix4 transform) {
    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Container(
        width: edge,
        height: edge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

/// Indeterminate loading bar — a gradient segment sweeping across a faint
/// track. [t] is 0..1 loop progress.
class _LoadingBar extends StatelessWidget {
  final double t;
  const _LoadingBar({required this.t});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            // Faint track.
            Container(color: const Color(0xFFD8D5E4)),
            // Sweeping gradient segment.
            Align(
              alignment: Alignment(-1 + 2 * t, 0),
              child: FractionallySizedBox(
                widthFactor: 0.42,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3F37C9), Color(0xFFC7F000)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
