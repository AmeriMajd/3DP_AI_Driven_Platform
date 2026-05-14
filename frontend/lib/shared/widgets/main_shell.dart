import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../services/storage_service.dart';

// Routes that keep the navbar but hide the shared AppBar.
const _noAppBarRoutes = [
  AppRoutes.fileDetail,
  AppRoutes.recommendForm,
  AppRoutes.recommendResult,
  AppRoutes.recommendHistory,
  AppRoutes.jobQueue,   // JobQueueScreen has its own inline header
  '/jobs/',             // JobDetailScreen has its own nav bar
  AppRoutes.profile,
  AppRoutes.adminUsers, // UsersScreen has its own inline header
];

// Per-screen action slot. Screens push widgets via shellActionsProvider.
final shellActionsProvider = StateProvider<List<Widget>>((_) => const []);

// Unread notification count — wire to real source later.
final unreadNotificationsProvider = StateProvider<int>((_) => 0);

final userFullNameProvider = FutureProvider<String?>((ref) async {
  return await StorageService.getFullName();
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  return await StorageService.getUserRole();
});

class _SectionMeta {
  final String title;
  const _SectionMeta(this.title);
}

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context, {bool isAdmin = false}) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.upload)) return 0;
    if (location.startsWith(AppRoutes.fleet)) return 1;
    if (location.startsWith(AppRoutes.jobQueue)) return 2;
    if (location.startsWith(AppRoutes.monitoring)) return 3;
    if (isAdmin && location.startsWith(AppRoutes.adminUsers)) return 4;
    return 0;
  }

  _SectionMeta _meta(int index) {
    switch (index) {
      case 0:
        return const _SectionMeta('New model');
      case 1:
        return const _SectionMeta('Overview');
      case 2:
        return const _SectionMeta('Queue');
      case 3:
        return const _SectionMeta('Insights');
      case 4:
        return const _SectionMeta('Users');
      default:
        return const _SectionMeta('3DP');
    }
  }

  bool _showAppBar(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('${AppRoutes.fleet}/')) {
      return false;
    }
    return !_noAppBarRoutes.any((r) => location.startsWith(r));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullNameAsync = ref.watch(userFullNameProvider);
    final fullName = fullNameAsync.valueOrNull ?? 'User';
    final isAdmin = ref.watch(userRoleProvider).valueOrNull == 'admin';
    final currentIndex = _currentIndex(context, isAdmin: isAdmin);
    final meta = _meta(currentIndex);
    final showAppBar = _showAppBar(context);
    final extraActions = ref.watch(shellActionsProvider);
    final unread = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: _ShellAppBar(
                title: meta.title,
                extraActions: extraActions,
                unread: unread,
                fullName: fullName,
              ),
            )
          : null,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
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
                  icon: Icons.precision_manufacturing_outlined,
                  activeIcon: Icons.precision_manufacturing,
                  label: 'Fleet',
                  isActive: currentIndex == 1,
                  onTap: () => context.go(AppRoutes.fleet),
                ),
                _NavItem(
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  label: 'Jobs',
                  isActive: currentIndex == 2,
                  onTap: () => context.go(AppRoutes.jobQueue),
                ),
                _NavItem(
                  icon: Icons.monitor_heart_outlined,
                  activeIcon: Icons.monitor_heart_rounded,
                  label: 'Monitoring',
                  isActive: currentIndex == 3,
                  onTap: () => context.go(AppRoutes.monitoring),
                ),
                if (isAdmin)
                  _NavItem(
                    icon: Icons.group_outlined,
                    activeIcon: Icons.group_rounded,
                    label: 'Users',
                    isActive: currentIndex == 4,
                    onTap: () => context.go(AppRoutes.adminUsers),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellAppBar extends StatelessWidget {
  final String title;
  final List<Widget> extraActions;
  final int unread;
  final String fullName;

  const _ShellAppBar({
    required this.title,
    required this.extraActions,
    required this.unread,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundLight,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...extraActions.expand(
                (w) => [w, const SizedBox(width: 6)],
              ),
              _BellButton(unread: unread),
              const SizedBox(width: 8),
              _AvatarMenu(fullName: fullName),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unread;
  const _BellButton({required this.unread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              // TODO: notifications route
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.backgroundLight,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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
          appRouter.push(AppRoutes.profile);
        }
        if (value == 'settings') {
          // TODO → SettingsScreen
        }
        if (value == 'logout') {
          await StorageService.clearAll();
          appRouter.go(AppRoutes.login);
        }
      },
      itemBuilder: (_) => [
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
        const PopupMenuDivider(height: 1, color: Color(0xFF8E8E93)),
        const PopupMenuItem(
          value: 'account',
          height: 44,
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Color(0xFF1C1C1E),
              ),
              SizedBox(width: 10),
              Text(
                'My Account',
                style: TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          height: 44,
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: Color(0xFF1C1C1E)),
              SizedBox(width: 10),
              Text(
                'Settings',
                style: TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1, color: Color(0xFF8E8E93)),
        const PopupMenuItem(
          value: 'logout',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Color(0xFFFF3B30)),
              SizedBox(width: 10),
              Text(
                'Logout',
                style: TextStyle(fontSize: 14, color: Color(0xFFFF3B30)),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.primary,
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
              color: isActive ? AppColors.primary : const Color(0xFF8E8E93),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
