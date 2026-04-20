import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../services/storage_service.dart';

// Routes that keep the navbar but hide the shared AppBar.
const _noAppBarRoutes = [
  AppRoutes.fileDetail,
  AppRoutes.recommendForm,
  AppRoutes.recommendResult,
];

// ── Provider pour le fullName ─────────────────────────────────────────────────
final userFullNameProvider = FutureProvider<String?>((ref) async {
  return await StorageService.getFullName();
});

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.upload)) return 0;
    if (location.startsWith(AppRoutes.fleet)) return 1;
    if (location.startsWith(AppRoutes.schedule)) return 2;
    if (location.startsWith(AppRoutes.monitoring)) return 3;
    return 0;
  }

  String _currentTitle(int index) {
    switch (index) {
      case 0: return 'Upload Model';
      case 1: return 'Fleet';
      case 2: return 'Schedule';
      case 3: return 'Monitoring';
      default: return '3DP Platform';
    }
  }

  bool _showAppBar(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return !_noAppBarRoutes.any((r) => location.startsWith(r));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final fullNameAsync = ref.watch(userFullNameProvider);
    final showAppBar = _showAppBar(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),

      // ── AppBar partagée ───────────────────────────────────────────────
      appBar: showAppBar ? AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          _currentTitle(currentIndex),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          // 🔔 Notifications
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              size: 22,
              color: Color(0xFF1C1C1E),
            ),
            onPressed: () {
              // TODO — NotificationsScreen Sprint 5
            },
          ),

          // 👤 Avatar avec initiales
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: fullNameAsync.when(
              data: (name) => _AvatarMenu(fullName: name ?? 'User'),
              loading: () => const _AvatarMenu(fullName: 'User'),
              error: (_, __) => const _AvatarMenu(fullName: 'User'),
            ),
          ),
        ],
      ) : null,

      body: child,

      // ── Bottom Navbar ─────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.upload_file_outlined,
                  activeIcon: Icons.upload_file_rounded,
                  label: 'Upload',
                  isActive: currentIndex == 0,
                  onTap: () => context.go(AppRoutes.upload),
                ),
                _NavItem(
                  icon: Icons.print_outlined,
                  activeIcon: Icons.print_rounded,
                  label: 'Fleet',
                  isActive: currentIndex == 1,
                  onTap: () => context.go(AppRoutes.fleet),
                ),
                _NavItem(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today_rounded,
                  label: 'Schedule',
                  isActive: currentIndex == 2,
                  onTap: () => context.go(AppRoutes.schedule),
                ),
                _NavItem(
                  icon: Icons.monitor_heart_outlined,
                  activeIcon: Icons.monitor_heart_rounded,
                  label: 'Monitoring',
                  isActive: currentIndex == 3,
                  onTap: () => context.go(AppRoutes.monitoring),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar avec popup menu ────────────────────────────────────────────────────
class _AvatarMenu extends ConsumerWidget {
  final String fullName;
  const _AvatarMenu({required this.fullName});

  String get _initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      offset: const Offset(-7, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      color: Colors.white,
      onSelected: (value) async {
        if (value == 'account') {
          // TODO → AccountScreen
        }
        if (value == 'settings') {
          // TODO → SettingsScreen
        }
        if (value == 'logout') {
          // TODO — appeler authProvider.logout() puis rediriger
          // await ref.read(authProvider.notifier).logout();
          context.go(AppRoutes.login);
        }
      },
      itemBuilder: (_) => [
        // Header — nom complet + role
        PopupMenuItem(
          enabled: false,
          height: 40,
          child: FutureBuilder<String?>(
            future: StorageService.getUserRole(),
            builder: (context, snapshot) {
              final role = snapshot.data ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  if (role.isNotEmpty)
                    Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8E8E93),
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        const PopupMenuDivider(height: 1, color:Color(0xFF8E8E93)),

        // My Account
        const PopupMenuItem(
          value: 'account',
          height: 44,
          child: Row(children: [
            Icon(Icons.person_outline_rounded,
                size: 18, color: Color(0xFF1C1C1E)),
            SizedBox(width: 10),
            Text('My Account',
                style: TextStyle(fontSize: 14, color: Color(0xFF1C1C1E))),
          ]),
        ),

        // Settings
        const PopupMenuItem(
          value: 'settings',
          height: 44,
          child: Row(children: [
            Icon(Icons.settings_outlined,
                size: 18, color: Color(0xFF1C1C1E)),
            SizedBox(width: 10),
            Text('Settings',
                style: TextStyle(fontSize: 14, color: Color(0xFF1C1C1E))),
          ]),
        ),

        const PopupMenuDivider(height: 1, color:Color(0xFF8E8E93)),

        // Logout
        const PopupMenuItem(
          value: 'logout',
          height: 40,
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 18, color: Color(0xFFFF3B30)),
            SizedBox(width: 10),
            Text('Logout',
                style: TextStyle(fontSize: 14, color: Color(0xFFFF3B30))),
          ]),
        ),
      ],
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFF4B6BFB),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _initials,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 23,
              color: isActive
                  ? const Color(0xFF4B6BFB)
                  : const Color(0xFF8E8E93),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? const Color(0xFF4B6BFB)
                    : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }
}