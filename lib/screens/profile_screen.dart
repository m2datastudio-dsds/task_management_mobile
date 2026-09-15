import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/organization_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/roles.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfileData());
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final futures = <Future<void>>[];
    if (Roles.isSuperAdmin(user.role)) {
      futures.add(context.read<OrganizationProvider>().load());
      futures.add(context.read<UserProvider>().loadUsers());
    } else if (Roles.isAdminLike(user.role)) {
      futures.add(context.read<UserProvider>().loadUsers());
      futures.add(context.read<TaskProvider>().loadTasks(
            adminView: true,
            userId: user.id,
            limit: 1000,
          ));
    } else {
      futures.add(context.read<TaskProvider>().loadTasks(
            adminView: false,
            userId: user.id,
            limit: 1000,
          ));
    }

    await Future.wait(futures.map((future) => future.catchError((_) {})));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final userProvider = context.watch<UserProvider>();
    final organizationProvider = context.watch<OrganizationProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final roleLabel = _formatRole(user.role);
    final organizationName = user.organizationName?.trim() ?? '';
    final organizations = user.organizations;
    final metrics = _metricsFor(
      user: user,
      tasks: taskProvider.tasks,
      users: userProvider.users,
      organizationCount: organizationProvider.organizations
          .where((organization) => organization.isActive)
          .length,
    );
    final loadingMetrics = taskProvider.loading ||
        userProvider.loading ||
        organizationProvider.loading;

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.paddingOf(context).bottom + 96),
        children: [
          const SectionHeader(
            title: 'Profile',
            subtitle: 'Account, role, and organization details',
          ),
          const SizedBox(height: 16),
          _ProfileHeader(user: user, roleLabel: roleLabel),
          const SizedBox(height: 14),
          _MetricGrid(metrics: metrics, loading: loadingMetrics),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle(
                  icon: Icons.badge_outlined,
                  title: 'Account Details',
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: user.name.isEmpty ? 'Not set' : user.name,
                ),
                _DetailRow(
                  icon: Icons.alternate_email_outlined,
                  label: 'Email',
                  value: user.email.isEmpty ? 'Not set' : user.email,
                ),
                _DetailRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Role',
                  value: roleLabel,
                ),
                _DetailRow(
                  icon: user.isDeleted
                      ? Icons.block_outlined
                      : Icons.verified_user_outlined,
                  label: 'Account Status',
                  value: user.isDeleted ? 'Inactive' : 'Active',
                  valueColor: user.isDeleted
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF16A34A),
                ),
                if (user.createdAt != null)
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Joined',
                    value: _formatDate(user.createdAt!),
                    showDivider: false,
                  )
                else
                  const _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Joined',
                    value: 'Not available',
                    showDivider: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle(
                  icon: Icons.apartment_outlined,
                  title: 'Organization Access',
                ),
                const SizedBox(height: 14),
                if (organizationName.isNotEmpty)
                  _OrganizationTile(
                    name: organizationName,
                    active: true,
                  )
                else if (organizations.isEmpty)
                  const _EmptyState(
                    icon: Icons.business_outlined,
                    title: 'No organization selected',
                    subtitle:
                        'Super admin accounts can work without selecting an organization.',
                  ),
                if (organizations.isNotEmpty) ...[
                  if (organizationName.isNotEmpty) const SizedBox(height: 10),
                  ...organizations.map((org) {
                    final name = (org['name'] ?? '').toString();
                    final code = (org['code'] ?? '').toString();
                    final role = (org['role'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OrganizationTile(
                        name: name.isEmpty ? 'Organization' : name,
                        code: code.isEmpty ? null : code,
                        role: role.isEmpty ? null : _formatRole(role),
                        active: name == organizationName ||
                            organizationName.isEmpty,
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle(
                  icon: Icons.settings_outlined,
                  title: 'Session',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: auth.logout,
                    icon: const Icon(Icons.logout_outlined),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.roleLabel});

  final AppUser user;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim()[0].toUpperCase()
        : (user.email.trim().isNotEmpty
            ? user.email.trim()[0].toUpperCase()
            : '?');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Text(
              initial,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? 'User' : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEFF6FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: Text(
                      roleLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.loading});

  final List<_ProfileMetric> metrics;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(metric.icon, color: metric.color, size: 24),
              const Spacer(),
              Text(
                loading ? '...' : '${metric.value}',
                style: const TextStyle(
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                metric.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? AppTheme.text,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider) const Divider(height: 22),
      ],
    );
  }
}

class _OrganizationTile extends StatelessWidget {
  const _OrganizationTile({
    required this.name,
    this.code,
    this.role,
    required this.active,
  });

  final String name;
  final String? code;
  final String? role;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF3F7FF) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.26)
              : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                active ? AppTheme.primary : const Color(0xFFE5E7EB),
            child: Text(
              name.isEmpty ? 'O' : name[0].toUpperCase(),
              style: TextStyle(
                color: active ? Colors.white : AppTheme.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (code != null || role != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [code, role].whereType<String>().join(' - '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (active)
            const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric {
  const _ProfileMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

List<_ProfileMetric> _metricsFor({
  required AppUser user,
  required List<TaskItem> tasks,
  required List<AppUser> users,
  required int organizationCount,
}) {
  final role = user.role.toLowerCase();

  if (role == Roles.superAdmin) {
    return [
      _ProfileMetric(
        label: 'Total Organizations',
        value: organizationCount,
        icon: Icons.apartment_outlined,
        color: AppTheme.primary,
      ),
      _ProfileMetric(
        label: 'Total Users',
        value: users.where((item) => !item.isDeleted).length,
        icon: Icons.people_outline,
        color: const Color(0xFF16A34A),
      ),
    ];
  }

  if (role == Roles.admin) {
    final totalEmployees = users.where((item) {
      final itemRole = item.role.toLowerCase();
      return !item.isDeleted &&
          (itemRole == Roles.employee || itemRole == Roles.intern);
    }).length;
    final activeTasks = tasks.where(_isActiveTask).length;

    return [
      _ProfileMetric(
        label: 'Total Employees',
        value: totalEmployees,
        icon: Icons.groups_outlined,
        color: AppTheme.primary,
      ),
      _ProfileMetric(
        label: 'Total Active Tickets',
        value: activeTasks,
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFFF59E0B),
      ),
    ];
  }

  final assignedTasks = tasks.length;
  final completedTasks = tasks.where((task) {
    final status = (task.status ?? '').toLowerCase();
    return status == 'completed' || status == 'closed';
  }).length;

  return [
    _ProfileMetric(
      label: 'Assigned Tickets Count',
      value: assignedTasks,
      icon: Icons.assignment_ind_outlined,
      color: AppTheme.primary,
    ),
    _ProfileMetric(
      label: 'Completed Tickets Count',
      value: completedTasks,
      icon: Icons.task_alt_outlined,
      color: const Color(0xFF16A34A),
    ),
  ];
}

bool _isActiveTask(TaskItem task) {
  final isActive = task.raw['isactive'];
  if (isActive == false) return false;
  final status = (task.status ?? '').toLowerCase();
  return status != 'completed' && status != 'closed' && status != 'revoked';
}

String _formatRole(String value) {
  final cleaned = value.trim().replaceAll('_', ' ');
  if (cleaned.isEmpty) return 'Not assigned';
  return cleaned
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
