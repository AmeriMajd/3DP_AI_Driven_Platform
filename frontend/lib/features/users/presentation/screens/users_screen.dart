import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/storage_service.dart';
import '../../domain/user_item.dart';
import '../providers/users_providers.dart';
import '../widgets/invite_modal.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadCurrentUser() async {
    final id = await StorageService.getUserId();
    if (mounted) setState(() => _currentUserId = id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showInviteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteModal(
        onInviteSent: () => ref.invalidate(pendingInvitationsProvider),
      ),
    );
  }

  List<UserItem> _filtered(List<UserItem> all) {
    var list = all;
    if (_filter == 'active') list = list.where((u) => u.isActive).toList();
    if (_filter == 'inactive') list = list.where((u) => !u.isActive).toList();
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersViewModelProvider);
    final invAsync = ref.watch(pendingInvitationsProvider);

    final pending = invAsync.valueOrNull
            ?.where((i) => i['status'] == 'pending')
            .toList() ??
        [];

    final allUsers = state.users;
    final operators = allUsers.where((u) => u.role == 'operator').length;
    final filtered = _filtered(allUsers);
    final activeCount = allUsers.where((u) => u.isActive).length;
    final inactiveCount = allUsers.where((u) => !u.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(usersViewModelProvider.notifier).loadUsers();
            ref.invalidate(pendingInvitationsProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildStatCards(
                          allUsers.length, operators, pending.length),
                      const SizedBox(height: 16),
                      _buildSearch(),
                      const SizedBox(height: 12),
                      _buildFilterTabs(
                          allUsers.length, activeCount, inactiveCount),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (state.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (state.error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 40),
                        const SizedBox(height: 12),
                        Text(state.error!,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => ref
                              .read(usersViewModelProvider.notifier)
                              .loadUsers(),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(
                      label: 'TEAM MEMBERS',
                      count: '${filtered.length} users',
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: _UserCard(
                          user: user,
                          isCurrentUser: user.id == _currentUserId,
                          isDeleting: state.deletingIds.contains(user.id),
                          onDelete: () => _confirmDelete(user),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
                if (pending.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _SectionHeader(
                        label: 'PENDING INVITATIONS',
                        count: '${pending.length} invited',
                        countColor: AppColors.warning,
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final inv = pending[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _InvitationCard(
                            invitation: inv,
                            onCancel: () => _cancelInvitation(inv),
                          ),
                        );
                      },
                      childCount: pending.length,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Users',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Manage platform access',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _showInviteModal,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text(
            'Invite',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(int total, int operators, int pending) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'TOTAL', value: '$total')),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'OPERATORS',
            value: '$operators',
            valueColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'PENDING',
            value: '$pending',
            valueColor:
                pending > 0 ? AppColors.warning : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Search name or email',
          hintStyle:
              TextStyle(fontSize: 14, color: AppColors.textSecondary),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(int all, int active, int inactive) {
    return Row(
      children: [
        _FilterTab(
          label: 'All',
          count: all,
          selected: _filter == 'all',
          onTap: () => setState(() => _filter = 'all'),
        ),
        const SizedBox(width: 8),
        _FilterTab(
          label: 'Active',
          count: active,
          selected: _filter == 'active',
          onTap: () => setState(() => _filter = 'active'),
        ),
        const SizedBox(width: 8),
        _FilterTab(
          label: 'Inactive',
          count: inactive,
          selected: _filter == 'inactive',
          onTap: () => setState(() => _filter = 'inactive'),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(UserItem user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove user?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          "This will deactivate ${user.fullName}'s access to the platform.",
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(usersViewModelProvider.notifier).deleteUser(user.id);
    }
  }

  Future<void> _cancelInvitation(Map<String, dynamic> inv) async {
    final id = inv['id'] as String;
    final email = inv['email'] as String? ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel invitation?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'The registration link sent to $email will be immediately invalidated.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel invitation'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(usersRepositoryProvider).cancelInvitation(id);
      ref.invalidate(pendingInvitationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ── Shared sub-widgets ───────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String count;
  final Color countColor;

  const _SectionHeader({
    required this.label,
    required this.count,
    this.countColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            count,
            style: TextStyle(
              fontSize: 11,
              color: countColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserItem user;
  final bool isCurrentUser;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.isDeleting,
    required this.onDelete,
  });

  Color get _avatarColor {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF0F766E),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF7C3AED),
    ];
    return colors[user.fullName.codeUnitAt(0) % colors.length];
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _avatarColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.initials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _RoleBadge(role: user.role),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    _StatusBadge(isActive: user.isActive),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Joined ${_formatDate(user.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(
                      ' · ',
                      style:
                          TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      '${user.jobsCount} jobs',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (!isCurrentUser)
                      _DeleteButton(
                        isDeleting: isDeleting,
                        onDelete: onDelete,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final VoidCallback onCancel;

  const _InvitationCard(
      {required this.invitation, required this.onCancel});

  String _expiryLabel() {
    final raw = invitation['expires_at'] as String?;
    if (raw == null) return '';
    final expiresAt = DateTime.tryParse(raw);
    if (expiresAt == null) return '';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours < 1) return 'expires in ${diff.inMinutes}m';
    return 'expires in ${diff.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    final email = invitation['email'] as String? ?? '';
    final role = invitation['role'] as String? ?? '';
    final roleLabel =
        role.isNotEmpty ? '${role[0].toUpperCase()}${role.substring(1)}' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Invited as $roleLabel · ${_expiryLabel()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primaryLight
            : const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Operator',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isAdmin
              ? AppColors.primary
              : const Color(0xFF0F766E),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.success
                : const Color(0xFF9CA3AF),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isActive
                ? AppColors.success
                : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onDelete;

  const _DeleteButton(
      {required this.isDeleting, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
            strokeWidth: 1.5, color: AppColors.error),
      );
    }
    return GestureDetector(
      onTap: onDelete,
      child: const Icon(
        Icons.delete_outline_rounded,
        size: 18,
        color: AppColors.error,
      ),
    );
  }
}
