import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../models/task.dart';
import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/organization_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';
import 'organization_dashboard_screen.dart';
import 'organization_form_screen.dart';
import 'task_form_screen.dart';
import 'user_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _selectedOrganizationId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardData());
  }

  Future<void> _openCreateOrganization() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OrganizationFormScreen()),
    );
    if (mounted) _loadDashboardData();
  }

  Future<void> _openCreateUser() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const UserFormScreen()),
    );
    if (mounted) _loadDashboardData();
  }

  void _openOrganizationDashboard(_OrganizationDashboardSummary summary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: '/organizations/${summary.organization.id}/dashboard',
        ),
        builder: (_) => OrganizationDashboardScreen(
          organization: summary.organization,
        ),
      ),
    );
  }

  void _openOrganizationDashboardById(
    int? organizationId,
    List<_OrganizationDashboardSummary> summaries,
  ) {
    if (organizationId == null || summaries.isEmpty) return;
    for (final summary in summaries) {
      if (summary.organization.id == organizationId) {
        _openOrganizationDashboard(summary);
        return;
      }
    }
  }

  Future<void> _confirmDeleteAdmin(AppUser user) async {
    final displayName = user.name.isEmpty ? user.email : user.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Admin'),
        content: Text(
          'Delete $displayName? This admin will lose access, but existing data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<UserProvider>().deactivateUser(user.id);
      if (mounted) {
        AppToast.success(context, 'Admin deleted');
        _loadDashboardData();
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  Future<void> _editAdminMobile(AppUser user) async {
    final controller = TextEditingController(text: user.mobile);
    final formKey = GlobalKey<FormState>();
    final mobile = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Admin Mobile'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              hintText: 'Enter mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final mobile = value?.trim() ?? '';
              if (mobile.isEmpty) return 'Mobile number is required';
              final valid = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(mobile);
              return valid ? null : 'Enter a valid mobile number';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (mobile == null || mobile == user.mobile || !mounted) return;
    final userProvider = context.read<UserProvider>();
    await Future<void>.delayed(Duration.zero);

    try {
      await userProvider.updateUserMobile(user.id, mobile);
      if (!mounted) return;
      AppToast.success(context, 'Admin mobile number updated');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
  }

  Future<void> _loadDashboardData() async {
    final auth = context.read<AuthProvider>();
    if (auth.isSuperAdmin) {
      await Future.wait([
        context.read<OrganizationProvider>().load(),
        context.read<UserProvider>().loadUsers(),
        context.read<TaskProvider>().loadTasks(
              adminView: true,
              userId: auth.currentUser?.id ?? 0,
              limit: 1000,
            ),
      ]);
      return;
    }
    await context.read<DashboardProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final auth = context.watch<AuthProvider>();
    final orgProvider = context.watch<OrganizationProvider>();
    final userProvider = context.watch<UserProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final organizationSummaries = auth.isSuperAdmin
        ? _buildOrganizationSummaries(
            organizations: orgProvider.organizations,
            users: userProvider.users,
            tasks: taskProvider.tasks,
          )
        : const <_OrganizationDashboardSummary>[];
    final platformOverview = auth.isSuperAdmin
        ? _buildPlatformOverview(
            organizations: orgProvider.organizations,
            users: userProvider.users,
            tasks: taskProvider.tasks,
          )
        : null;
    final adminUsers = auth.isSuperAdmin
        ? (userProvider.users
            .where(
                (user) => !user.isDeleted && user.role.toLowerCase() == 'admin')
            .toList()
          ..sort((a, b) => (a.name.isEmpty ? a.email : a.name)
              .toLowerCase()
              .compareTo((b.name.isEmpty ? b.email : b.name).toLowerCase())))
        : const <AppUser>[];
    final summary =
        provider.overview?['summary'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.paddingOf(context).bottom + 96),
          children: [
            SectionHeader(
              title: auth.isSuperAdmin ? 'Super Admin Dashboard' : 'Dashboard',
              subtitle: auth.isSuperAdmin
                  ? 'Platform overview and organization navigation'
                  : 'Overview of your ticket management system',
              trailing: auth.isSuperAdmin
                  ? OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                    )
                  : null,
            ),
            const SizedBox(height: 18),
            if (auth.isSuperAdmin &&
                (orgProvider.loading ||
                    userProvider.loading ||
                    taskProvider.loading)) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            if (!auth.isSuperAdmin && provider.loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            if (auth.isSuperAdmin &&
                (orgProvider.error != null ||
                    userProvider.error != null ||
                    taskProvider.error != null)) ...[
              _ErrorBanner(
                message: orgProvider.error ??
                    userProvider.error ??
                    taskProvider.error ??
                    'Unable to load platform dashboard',
              ),
              const SizedBox(height: 14),
            ],
            if (!auth.isSuperAdmin && provider.error != null) ...[
              _ErrorBanner(message: provider.error!),
              const SizedBox(height: 14),
            ],
            if (auth.isSuperAdmin) ...[
              _StatsGrid(
                children: [
                  _StatCard(
                    'Organizations',
                    '${platformOverview?.totalOrganizations ?? 0}',
                    Icons.apartment_outlined,
                    const Color(0xFF0EA5E9),
                  ),
                  _StatCard(
                    'Users',
                    '${platformOverview?.totalUsers ?? 0}',
                    Icons.people_outline,
                    const Color(0xFF6366F1),
                  ),
                  _StatCard(
                    'Admins',
                    '${platformOverview?.totalAdmins ?? 0}',
                    Icons.admin_panel_settings_outlined,
                    const Color(0xFF22C55E),
                  ),
                  _StatCard(
                    'Tickets',
                    '${platformOverview?.totalTasks ?? 0}',
                    Icons.list_alt_outlined,
                    const Color(0xFFF59E0B),
                    onTap: () => context.read<AppState>().select(1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _OrganizationSelectionCard(
                organizations: orgProvider.organizations
                    .where((organization) => organization.isActive)
                    .toList()
                  ..sort((a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase())),
                selectedOrganizationId: _selectedOrganizationId,
                loading: orgProvider.loading,
                onChanged: (value) {
                  setState(() => _selectedOrganizationId = value);
                  _openOrganizationDashboardById(value, organizationSummaries);
                },
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardTitle(title: 'Quick Actions'),
                    const SizedBox(height: 14),
                    _ActionGrid(
                      actions: [
                        _ActionItem(
                          label: 'Create User',
                          icon: Icons.person_add_alt_1,
                          filled: true,
                          onTap: _openCreateUser,
                        ),
                        _ActionItem(
                          label: 'Create Organization',
                          icon: Icons.add_business_outlined,
                          onTap: _openCreateOrganization,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _AdminListCard(
                admins: adminUsers,
                loading: userProvider.loading,
                onEditMobile: _editAdminMobile,
                onDelete: _confirmDeleteAdmin,
              ),
            ] else ...[
              _StatsGrid(
                children: [
                  _StatCard(
                    'Tickets',
                    '${summary['totalTasks'] ?? 0}',
                    Icons.dashboard_customize_outlined,
                    const Color(0xFF0EA5E9),
                    onTap: () => context.read<AppState>().select(1),
                  ),
                  _StatCard(
                    'In Progress',
                    '${summary['inProgress'] ?? 0}',
                    Icons.timelapse_outlined,
                    const Color(0xFF22C55E),
                  ),
                  _StatCard(
                    'Done',
                    '${summary['completed'] ?? 0}',
                    Icons.check_circle_outline,
                    const Color(0xFFF59E0B),
                  ),
                  _StatCard(
                    'Overdue',
                    '${summary['overdue'] ?? 0}',
                    Icons.error_outline,
                    const Color(0xFFEF4444),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatusBreakdownCard(
                items: provider.statusBreakdown,
                loading: provider.loading,
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardTitle(title: 'Quick Actions'),
                    const SizedBox(height: 14),
                    _ActionGrid(
                      actions: [
                        _ActionItem(
                          label: 'Create Ticket',
                          icon: Icons.add_task_outlined,
                          filled: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TaskFormScreen(),
                            ),
                          ),
                        ),
                        _ActionItem(
                          label: 'Ticket Management',
                          icon: Icons.list_alt_outlined,
                          onTap: () => context.read<AppState>().select(1),
                        ),
                        _ActionItem(
                          label: 'User Management',
                          icon: Icons.people_outline,
                          onTap: () => context.read<AppState>().select(2),
                        ),
                        _ActionItem(
                          label: 'Role Management',
                          icon: Icons.security_outlined,
                          onTap: () => context.read<AppState>().select(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _TaskDistributionCard(
                items: provider.distribution,
                loading: provider.loading,
              ),
              const SizedBox(height: 16),
              _RecentActivityCard(tasks: provider.recentTasks),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 360 ? 10.0 : 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(
                    width: itemWidth,
                    height: 132,
                    child: child,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.title, this.value, this.icon, this.color, {this.onTap});

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 30, height: 1, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
          fontSize: 19, height: 1.1, fontWeight: FontWeight.w900),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 460 ? 3 : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((action) => SizedBox(width: width, child: action))
              .toList(),
        );
      },
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background = filled ? AppTheme.primary : Colors.white;
    final foreground = filled ? Colors.white : AppTheme.text;
    return Material(
      color: enabled ? background : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 19, color: enabled ? foreground : Colors.grey[500]),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? foreground : Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.items, required this.loading});

  final List<dynamic> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final rows = items.whereType<Map<String, dynamic>>().toList();
    final notStarted =
        _countStatuses(rows, ['not_started', 'created', 'assigned']);
    final inProgress = _countStatuses(rows, ['in_progress']);
    final completed = _countStatuses(rows, ['completed']);
    final closed = _countStatuses(rows, ['closed']);
    final total = notStarted + inProgress + completed + closed;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Ticket Status Breakdown'),
          const SizedBox(height: 10),
          if (rows.isEmpty && !loading)
            Text('No ticket status data yet.',
                style: TextStyle(color: Colors.grey[600]))
          else ...[
            _StatusBreakdownRow(
              label: 'Not Started',
              count: notStarted,
              total: total,
              color: const Color(0xFF9CA3AF),
            ),
            _StatusBreakdownRow(
              label: 'In Progress',
              count: inProgress,
              total: total,
              color: const Color(0xFF3B82F6),
            ),
            _StatusBreakdownRow(
              label: 'Completed',
              count: completed,
              total: total,
              color: const Color(0xFFEAB308),
            ),
            _StatusBreakdownRow(
              label: 'Closed',
              count: closed,
              total: total,
              color: const Color(0xFF22C55E),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBreakdownRow extends StatelessWidget {
  const _StatusBreakdownRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text('$count',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.tasks});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    final recentTasks = [...tasks]..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Recent Activity'),
          const SizedBox(height: 14),
          if (recentTasks.isEmpty)
            Text('No recent activity',
                style: TextStyle(color: Colors.grey[600]))
          else
            ...recentTasks.take(10).map((task) => _ActivityRow(task: task)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 13),
      margin: const EdgeInsets.only(bottom: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.schedule_outlined,
                size: 17, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityMessage(task),
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  task.createdAt == null
                      ? ''
                      : _relativeTime(task.createdAt!.toIso8601String()),
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _activityMessage(TaskItem task) {
  final title = task.title.isEmpty ? 'Untitled ticket' : task.title;
  final status = (task.status ?? '').toLowerCase();
  final assignedName = _userName(task.raw['assignedUser']);
  final creatorName = _userName(task.raw['createdByUser']);

  if (status == 'completed') {
    return assignedName == null
        ? 'Ticket completed: $title'
        : 'Ticket completed by $assignedName: $title';
  }
  if (status == 'closed') {
    return 'Ticket closed: $title';
  }
  if (status == 'revoked') {
    return 'Ticket revoked: $title';
  }
  if (status == 'assigned') {
    return 'New ticket assigned: $title';
  }
  if (status == 'in_progress') {
    return assignedName == null
        ? 'Ticket in progress: $title'
        : '$assignedName started ticket: $title';
  }
  if (status == 'created') {
    return creatorName == null
        ? 'New ticket created: $title'
        : 'Ticket created by $creatorName: $title';
  }
  return 'Ticket updated: $title';
}

String? _userName(dynamic value) {
  if (value is! Map) return null;
  final name = value['name']?.toString();
  if (name != null && name.trim().isNotEmpty) return name;
  final email = value['email']?.toString();
  if (email != null && email.trim().isNotEmpty) return email;
  return null;
}

String _relativeTime(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';

  final now = DateTime.now().toUtc();
  final difference = now.difference(date.toUtc());
  if (difference.inDays >= 365) {
    final years = difference.inDays ~/ 365;
    return '$years year${years == 1 ? '' : 's'} ago';
  }
  if (difference.inDays >= 30) {
    final months = difference.inDays ~/ 30;
    return '$months month${months == 1 ? '' : 's'} ago';
  }
  if (difference.inDays >= 1) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }
  if (difference.inHours >= 1) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  }
  if (difference.inMinutes >= 1) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  }
  return 'Just now';
}

class _TaskDistributionCard extends StatelessWidget {
  const _TaskDistributionCard({required this.items, required this.loading});

  final List<dynamic> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final rows = items.whereType<Map<String, dynamic>>().toList();
    final maxTasks = rows.fold<int>(0, (max, item) {
      final totalTasks = _asInt(item['totalTasks']);
      return totalTasks > max ? totalTasks : max;
    });

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Ticket Distribution by User'),
          const SizedBox(height: 12),
          if (rows.isEmpty && !loading)
            Text('No tickets assigned yet',
                style: TextStyle(color: Colors.grey[600]))
          else
            ...rows.map(
                (item) => _TaskDistributionRow(item: item, maxTasks: maxTasks)),
        ],
      ),
    );
  }
}

class _TaskDistributionRow extends StatelessWidget {
  const _TaskDistributionRow({required this.item, required this.maxTasks});

  final Map<String, dynamic> item;
  final int maxTasks;

  @override
  Widget build(BuildContext context) {
    final name = (item['userName'] ?? item['email'] ?? 'User').toString();
    final email = (item['email'] ?? '').toString();
    final totalTasks = _asInt(item['totalTasks']);
    final activeTasks = _asInt(item['activeTasks']);
    final progress = maxTasks == 0 ? 0.0 : totalTasks / maxTasks;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$totalTasks total',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              color: AppTheme.primary,
              backgroundColor: const Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$activeTasks active ticket${activeTasks == 1 ? '' : 's'}',
            style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

int _countStatuses(List<Map<String, dynamic>> rows, List<String> statuses) {
  return rows.fold<int>(0, (sum, item) {
    final status = (item['statusName'] ?? '').toString().toLowerCase();
    return statuses.contains(status) ? sum + _asInt(item['count']) : sum;
  });
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Color(0xFFB91C1C), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OrganizationDashboardSummary {
  const _OrganizationDashboardSummary({
    required this.organization,
    required this.totalUsers,
    required this.totalTasks,
    required this.pendingTasks,
  });

  final Organization organization;
  final int totalUsers;
  final int totalTasks;
  final int pendingTasks;
}

List<_OrganizationDashboardSummary> _buildOrganizationSummaries({
  required List<Organization> organizations,
  required List<AppUser> users,
  required List<TaskItem> tasks,
}) {
  return organizations.where((org) => org.isActive).map((org) {
    final orgUsers =
        users.where((user) => _userBelongsToOrg(user, org.id)).length;
    final orgTasks =
        tasks.where((task) => task.organizationId == org.id).toList();
    final pending =
        orgTasks.where((task) => _isPendingTask(task.status)).length;
    return _OrganizationDashboardSummary(
      organization: org,
      totalUsers: orgUsers,
      totalTasks: orgTasks.length,
      pendingTasks: pending,
    );
  }).toList()
    ..sort((a, b) => a.organization.name
        .toLowerCase()
        .compareTo(b.organization.name.toLowerCase()));
}

bool _userBelongsToOrg(AppUser user, int organizationId) {
  if (user.organizationId == organizationId) return true;
  return user.organizations.any((item) {
    final id = int.tryParse(
        '${item['id'] ?? item['orgid'] ?? item['organizationId']}');
    return id == organizationId;
  });
}

bool _isPendingTask(String? status) {
  final value = (status ?? '').toLowerCase();
  return value != 'completed' && value != 'closed' && value != 'revoked';
}

class _OrganizationSelectionCard extends StatefulWidget {
  const _OrganizationSelectionCard({
    required this.organizations,
    required this.selectedOrganizationId,
    required this.loading,
    required this.onChanged,
  });

  final List<Organization> organizations;
  final int? selectedOrganizationId;
  final bool loading;
  final ValueChanged<int?> onChanged;

  @override
  State<_OrganizationSelectionCard> createState() =>
      _OrganizationSelectionCardState();
}

class _OrganizationSelectionCardState
    extends State<_OrganizationSelectionCard> {
  final _search = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_expanded) {
        setState(() => _expanded = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _OrganizationSelectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOrganizationId != widget.selectedOrganizationId) {
      _search.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Organization? get _selectedOrganization {
    for (final organization in widget.organizations) {
      if (organization.id == widget.selectedOrganizationId) return organization;
    }
    return null;
  }

  List<Organization> get _filteredOrganizations {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty || !_expanded) return widget.organizations;
    return widget.organizations.where((organization) {
      final name = organization.name.toLowerCase();
      final code = organization.code.toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  void _openDropdown() {
    if (widget.loading) return;
    if (!_expanded) setState(() => _expanded = true);
    _focusNode.requestFocus();
  }

  void _selectOrganization(int? organizationId) {
    setState(() {
      _expanded = false;
      _search.clear();
    });
    _focusNode.unfocus();
    widget.onChanged(organizationId);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOrganization;
    final filtered = _filteredOrganizations;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Organization Selection'),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            focusNode: _focusNode,
            readOnly: widget.loading,
            onTap: _openDropdown,
            onChanged: (_) {
              if (!_expanded) setState(() => _expanded = true);
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Select Organization',
              hintText: _expanded
                  ? 'Search organization'
                  : (selected?.name ?? 'All Organizations'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: _expanded ? 'Close' : 'Open',
                onPressed: widget.loading
                    ? null
                    : () {
                        setState(() {
                          _expanded = !_expanded;
                          _search.clear();
                        });
                        if (_expanded) {
                          _focusNode.requestFocus();
                        } else {
                          _focusNode.unfocus();
                        }
                      },
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  _InlineOrganizationOption(
                    title: 'All Organizations',
                    subtitle:
                        '${widget.organizations.length} active organization${widget.organizations.length == 1 ? '' : 's'}',
                    selected: widget.selectedOrganizationId == null,
                    onTap: () => _selectOrganization(null),
                  ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'No organizations found.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (organization) => _InlineOrganizationOption(
                        title: organization.name,
                        subtitle: organization.code.isEmpty
                            ? 'No code'
                            : organization.code,
                        selected:
                            widget.selectedOrganizationId == organization.id,
                        onTap: () => _selectOrganization(organization.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineOrganizationOption extends StatelessWidget {
  const _InlineOrganizationOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? const Color(0xFFF3F4F6) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.apartment_outlined,
              color: selected ? AppTheme.primary : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminListCard extends StatelessWidget {
  const _AdminListCard({
    required this.admins,
    required this.loading,
    required this.onEditMobile,
    required this.onDelete,
  });

  final List<AppUser> admins;
  final bool loading;
  final ValueChanged<AppUser> onEditMobile;
  final ValueChanged<AppUser> onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Admins'),
          const SizedBox(height: 6),
          Text(
            'Organization admins with platform access.',
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (loading && admins.isEmpty) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],
          if (admins.isEmpty && !loading)
            Text('No admins available.',
                style: TextStyle(color: Colors.grey[600]))
          else
            ...admins.map(
              (admin) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdminSummaryTile(
                  admin: admin,
                  onEditMobile: () => onEditMobile(admin),
                  onDelete: () => onDelete(admin),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminSummaryTile extends StatelessWidget {
  const _AdminSummaryTile({
    required this.admin,
    required this.onEditMobile,
    required this.onDelete,
  });

  final AppUser admin;
  final VoidCallback onEditMobile;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final displayName = admin.name.isEmpty ? admin.email : admin.name;
    final orgText = _adminOrganizationText(admin);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            child: Text(
              displayName.isEmpty ? 'A' : displayName[0].toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primary,
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
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  admin.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (admin.mobile.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    admin.mobile,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  orgText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onEditMobile,
            color: AppTheme.primary,
            icon: const Icon(Icons.phone_android_outlined),
            tooltip: 'Edit mobile number',
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onDelete,
            color: const Color(0xFFDC2626),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete admin',
          ),
        ],
      ),
    );
  }
}

String _adminOrganizationText(AppUser admin) {
  final names = admin.organizations
      .map((item) => item['name']?.toString() ?? '')
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .toList();
  if (names.isNotEmpty) return 'Organizations: ${names.join(', ')}';
  final name = admin.organizationName;
  if (name != null && name.trim().isNotEmpty) return 'Organization: $name';
  return 'No organization assigned';
}

class _PlatformOverview {
  const _PlatformOverview({
    required this.totalOrganizations,
    required this.totalUsers,
    required this.totalAdmins,
    required this.totalTasks,
  });

  final int totalOrganizations;
  final int totalUsers;
  final int totalAdmins;
  final int totalTasks;
}

_PlatformOverview _buildPlatformOverview({
  required List<Organization> organizations,
  required List<AppUser> users,
  required List<TaskItem> tasks,
}) {
  final activeOrganizations = organizations.where((org) => org.isActive).length;
  final activeUsers = users.where((user) => !user.isDeleted).toList();
  final admins = activeUsers.where((user) {
    final role = user.role.toLowerCase();
    return role == 'admin' || role == 'super_admin';
  }).length;
  return _PlatformOverview(
    totalOrganizations: activeOrganizations,
    totalUsers: activeUsers.length,
    totalAdmins: admins,
    totalTasks: tasks.length,
  );
}
