import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';
import 'role_management_screen.dart';
import 'task_list_screen.dart';
import 'user_management_screen.dart';

class OrganizationDashboardScreen extends StatefulWidget {
  const OrganizationDashboardScreen({super.key, required this.organization});

  final Organization organization;

  @override
  State<OrganizationDashboardScreen> createState() =>
      _OrganizationDashboardScreenState();
}

class _OrganizationDashboardScreenState
    extends State<OrganizationDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      context.read<UserProvider>().loadUsers(),
      context.read<TaskProvider>().loadTasks(
            adminView: true,
            userId: auth.currentUser?.id ?? 0,
            limit: 1000,
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final org = widget.organization;
    final orgUsers = userProvider.users
        .where((user) => _userBelongsToOrg(user, org.id))
        .toList();
    final orgTasks = taskProvider.tasks
        .where((task) => task.organizationId == org.id)
        .toList();
    final distributionRows = _distributionRows(orgUsers, orgTasks);
    final loading = userProvider.loading || taskProvider.loading;
    final notStarted = orgTasks.where((task) => _isNotStartedTask(task)).length;
    final inProgress =
        orgTasks.where((task) => _status(task) == 'in_progress').length;
    final completed =
        orgTasks.where((task) => _status(task) == 'completed').length;
    final closed = orgTasks.where((task) => _status(task) == 'closed').length;
    final pending = orgTasks.where((task) => _isPendingTask(task)).length;

    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(org))),
      bottomNavigationBar: _OrganizationFooterNav(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                children: [
                  SectionHeader(
                    title: '${org.name} Dashboard',
                    subtitle:
                        'Organization-only users, tickets, pending work, and activity',
                  ),
                  const SizedBox(height: 18),
                  if (loading) ...[
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 14),
                  ],
                  if (userProvider.error != null ||
                      taskProvider.error != null) ...[
                    _ErrorBanner(
                      message: userProvider.error ??
                          taskProvider.error ??
                          'Unable to load organization dashboard',
                    ),
                    const SizedBox(height: 14),
                  ],
                  _StatsGrid(
                    children: [
                      _StatCard('Users', '${orgUsers.length}',
                          Icons.people_outline, const Color(0xFF0EA5E9)),
                      _StatCard('Tickets', '${orgTasks.length}',
                          Icons.list_alt_outlined, const Color(0xFF6366F1)),
                      _StatCard(
                          'Pending',
                          '$pending',
                          Icons.pending_actions_outlined,
                          const Color(0xFFF59E0B)),
                      _StatCard('Completed', '$completed',
                          Icons.check_circle_outline, const Color(0xFF22C55E)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardTitle(title: 'Ticket Status Breakdown'),
                        const SizedBox(height: 10),
                        _StatusRow(
                          label: 'Not Started',
                          count: notStarted,
                          total: orgTasks.length,
                          color: const Color(0xFF9CA3AF),
                        ),
                        _StatusRow(
                          label: 'In Progress',
                          count: inProgress,
                          total: orgTasks.length,
                          color: const Color(0xFF3B82F6),
                        ),
                        _StatusRow(
                          label: 'Completed',
                          count: completed,
                          total: orgTasks.length,
                          color: const Color(0xFF22C55E),
                        ),
                        _StatusRow(
                          label: 'Closed',
                          count: closed,
                          total: orgTasks.length,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OrgQuickActionsCard(
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardTitle(title: 'Ticket Distribution by User'),
                        const SizedBox(height: 12),
                        if (distributionRows.isEmpty)
                          Text('No users in this organization yet.',
                              style: TextStyle(color: Colors.grey[600]))
                        else
                          ...distributionRows
                              .map((row) => _DistributionRow(row: row)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardTitle(title: 'Recent Activity'),
                        const SizedBox(height: 14),
                        if (orgTasks.isEmpty)
                          Text('No recent activity',
                              style: TextStyle(color: Colors.grey[600]))
                        else
                          ...(_sortedRecent(orgTasks)
                              .take(10)
                              .map((task) => _ActivityTile(task: task))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TaskListScreen(
            adminView: true,
            organizationId: org.id,
            organizationName: org.name,
          ),
          UserManagementScreen(
            organizationId: org.id,
            organizationName: org.name,
          ),
          const RoleManagementScreen(),
        ],
      ),
    );
  }

  String _titleForIndex(Organization organization) {
    switch (_selectedIndex) {
      case 1:
        return '${organization.name} Tickets';
      case 2:
        return '${organization.name} Users';
      case 3:
        return 'Role Management';
      default:
        return organization.name;
    }
  }
}

class _DistributionData {
  const _DistributionData({
    required this.name,
    required this.email,
    required this.totalTasks,
    required this.activeTasks,
  });

  final String name;
  final String email;
  final int totalTasks;
  final int activeTasks;
}

List<_DistributionData> _distributionRows(
    List<AppUser> users, List<TaskItem> tasks) {
  final rows = <_DistributionData>[];
  for (final user in users.where((user) => !user.isDeleted)) {
    final assignedTasks =
        tasks.where((task) => task.assignedUserId == user.id).toList();
    if (assignedTasks.isEmpty) continue;
    rows.add(_DistributionData(
      name: user.name.isEmpty ? user.email : user.name,
      email: user.email,
      totalTasks: assignedTasks.length,
      activeTasks: assignedTasks.where(_isPendingTask).length,
    ));
  }
  rows.sort((a, b) => b.totalTasks.compareTo(a.totalTasks));
  return rows;
}

List<TaskItem> _sortedRecent(List<TaskItem> tasks) {
  return [...tasks]..sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
}

bool _userBelongsToOrg(AppUser user, int organizationId) {
  if (user.organizationId == organizationId) return true;
  return user.organizations.any((item) {
    final id = int.tryParse(
        '${item['id'] ?? item['orgid'] ?? item['organizationId']}');
    return id == organizationId;
  });
}

String _status(TaskItem task) => (task.status ?? '').toLowerCase();

bool _isPendingTask(TaskItem task) {
  final status = _status(task);
  return status != 'completed' && status != 'closed' && status != 'revoked';
}

bool _isNotStartedTask(TaskItem task) {
  final status = _status(task);
  return status.isEmpty || status == 'created' || status == 'assigned';
}

String _prettyStatus(String status) {
  if (status.isEmpty) return 'Unknown';
  return status
      .split('_')
      .map((part) =>
          part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _relativeTime(DateTime? date) {
  if (date == null) return '';
  final difference = DateTime.now().difference(date);
  if (difference.inDays >= 1) return '${difference.inDays}d ago';
  if (difference.inHours >= 1) return '${difference.inHours}h ago';
  if (difference.inMinutes >= 1) return '${difference.inMinutes}m ago';
  return 'Just now';
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
              .map((child) =>
                  SizedBox(width: itemWidth, height: 132, child: child))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.title, this.value, this.icon, this.color);

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 30, height: 1, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 7),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 19, height: 1.1, fontWeight: FontWeight.w900));
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
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
          Row(children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.w900))
          ]),
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

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.row});
  final _DistributionData row;

  @override
  Widget build(BuildContext context) {
    final progress =
        row.totalTasks == 0 ? 0.0 : row.activeTasks / row.totalTasks;
    final color =
        row.totalTasks == 0 ? const Color(0xFFE5E7EB) : AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      row.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${row.totalTasks} total tickets',
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 9,
              color: color,
              backgroundColor: const Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${row.activeTasks} active tickets',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 13),
      margin: const EdgeInsets.only(bottom: 13),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999)),
              child: const Icon(Icons.schedule_outlined,
                  size: 17, color: Color(0xFF2563EB))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title.isEmpty ? 'Untitled ticket' : task.title,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    '${_prettyStatus(_status(task))} - ${_relativeTime(task.createdAt)}',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
          border: Border.all(color: const Color(0xFFFECACA))),
      child: Text(message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
    );
  }
}

class _OrgQuickActionsCard extends StatelessWidget {
  const _OrgQuickActionsCard({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Quick Actions'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickActionButton(
                label: 'Ticket Monitoring',
                icon: Icons.list_alt_outlined,
                filled: true,
                onTap: () => onSelected(1),
              ),
              _QuickActionButton(
                label: 'Users',
                icon: Icons.people_outline,
                onTap: () => onSelected(2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled ? AppTheme.primary : Colors.white;
    final foreground = filled ? Colors.white : AppTheme.text;
    return SizedBox(
      width: 148,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: filled ? null : Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizationFooterNav extends StatelessWidget {
  const _OrganizationFooterNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.list_alt_outlined),
          label: 'Tickets',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          label: 'Users',
        ),
        NavigationDestination(
          icon: Icon(Icons.security_outlined),
          label: 'Roles',
        ),
      ],
    );
  }
}
