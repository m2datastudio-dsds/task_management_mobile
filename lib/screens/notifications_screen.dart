import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../utils/app_theme.dart';
import '../utils/status_style.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import 'task_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _readIds = {};
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadReadIds();
      await _loadNotifications();
    });
  }

  Future<void> _loadReadIds() async {
    final userId = context.read<AuthProvider>().currentUser?.id ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('notificationReadIds:$userId') ?? [];
    if (!mounted) return;
    setState(() {
      _readIds
        ..clear()
        ..addAll(ids);
      _loadingPrefs = false;
    });
  }

  Future<void> _saveReadIds() async {
    final userId = context.read<AuthProvider>().currentUser?.id ?? 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notificationReadIds:$userId', _readIds.toList());
  }

  Future<void> _loadNotifications() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    await context.read<TaskProvider>().loadTasks(
          adminView: auth.isAdmin,
          userId: currentUser.id,
          limit: 100,
        );
  }

  Future<void> _markAsRead(_TaskNotification notification) async {
    setState(() => _readIds.add(notification.id));
    await _saveReadIds();
  }

  Future<void> _markAllAsRead(List<_TaskNotification> notifications) async {
    setState(() => _readIds.addAll(notifications.map((item) => item.id)));
    await _saveReadIds();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final notifications = _buildNotifications(
      tasks: taskProvider.tasks,
      isAdmin: auth.isAdmin,
      currentUserId: auth.currentUser?.id,
    );
    final unreadCount =
        notifications.where((item) => !_readIds.contains(item.id)).length;

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(
            title: 'Notifications',
            subtitle: unreadCount == 0
                ? 'Ticket updates and system activity'
                : '$unreadCount unread ticket update${unreadCount == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 14),
          if (taskProvider.loading || _loadingPrefs) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],
          if (taskProvider.error != null) ...[
            _ErrorBanner(message: taskProvider.error!),
            const SizedBox(height: 12),
          ],
          if (notifications.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: unreadCount == 0
                    ? null
                    : () => _markAllAsRead(notifications),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark all read'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!taskProvider.loading && notifications.isEmpty)
            const EmptyState(
              title: 'No notifications',
              message: 'You are all caught up. Ticket alerts will appear here.',
              icon: Icons.notifications_none,
            )
          else
            ...notifications.map(
              (item) => _NotificationTile(
                notification: item,
                read: _readIds.contains(item.id),
                onTap: () async {
                  await _markAsRead(item);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(task: item.task),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<_TaskNotification> _buildNotifications({
    required List<TaskItem> tasks,
    required bool isAdmin,
    required int? currentUserId,
  }) {
    final now = DateTime.now();
    final items = <_TaskNotification>[];

    for (final task in tasks) {
      final status = (task.status ?? '').toLowerCase();
      final assignedToMe =
          currentUserId != null && task.assignedUserId == currentUserId;
      final createdByMe =
          currentUserId != null && task.createdBy == currentUserId;
      final actor = isAdmin ? _assignedUserName(task) : 'Admin';

      if (!isAdmin && assignedToMe) {
        final title =
            status == 'reassign' ? 'Ticket reassigned' : 'Ticket assigned';
        items.add(_TaskNotification(
          id: '${task.id}:assigned:${task.assignedUserId}:${task.createdAt?.millisecondsSinceEpoch ?? 0}',
          task: task,
          title: title,
          message: '${task.title} is assigned to you.',
          icon: Icons.assignment_ind_outlined,
          color: AppTheme.primary,
          createdAt: task.updatedAt ?? task.createdAt,
        ));
      }

      if (isAdmin && !createdByMe && task.assignedUserId != null) {
        items.add(_TaskNotification(
          id: '${task.id}:team-status:$status:${task.pickedUpAt?.millisecondsSinceEpoch ?? task.completedAt?.millisecondsSinceEpoch ?? task.updatedAt?.millisecondsSinceEpoch ?? 0}',
          task: task,
          title: 'Team ticket update',
          message:
              '$actor has ${StatusStyle.label(status).toLowerCase()} ticket ${task.title}.',
          icon: Icons.groups_2_outlined,
          color: StatusStyle.color(status),
          createdAt: task.pickedUpAt ??
              task.completedAt ??
              task.updatedAt ??
              task.createdAt,
        ));
      }

      if (status == 'in_progress') {
        items.add(_TaskNotification(
          id: '${task.id}:in-progress:${task.pickedUpAt?.millisecondsSinceEpoch ?? 0}',
          task: task,
          title: 'Ticket in progress',
          message: isAdmin
              ? '$actor picked up ${task.title}.'
              : '${task.title} is now in progress.',
          icon: Icons.play_circle_outline,
          color: const Color(0xFF3B82F6),
          createdAt: task.pickedUpAt ?? task.createdAt,
        ));
      }

      if (status == 'on_hold') {
        items.add(_TaskNotification(
          id: '${task.id}:hold:${task.updatedAt?.millisecondsSinceEpoch ?? 0}',
          task: task,
          title: 'Ticket on hold',
          message: '${task.title} is currently on hold.',
          icon: Icons.pause_circle_outline,
          color: const Color(0xFFF97316),
          createdAt: task.updatedAt ?? task.createdAt,
        ));
      }

      if (status == 'completed' || status == 'closed') {
        items.add(_TaskNotification(
          id: '${task.id}:completed:${task.completedAt?.millisecondsSinceEpoch ?? 0}',
          task: task,
          title: status == 'closed' ? 'Ticket closed' : 'Ticket completed',
          message: isAdmin
              ? '$actor completed ${task.title}.'
              : '${task.title} has been ${StatusStyle.label(status).toLowerCase()}.',
          icon: Icons.task_alt_outlined,
          color: const Color(0xFF22C55E),
          createdAt: task.completedAt ?? task.updatedAt ?? task.createdAt,
        ));
      }

      final due = task.dueDate;
      if (due != null && status != 'completed' && status != 'closed') {
        final days = DateTime(due.year, due.month, due.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        if (days < 0) {
          items.add(_TaskNotification(
            id: '${task.id}:overdue:${due.millisecondsSinceEpoch}',
            task: task,
            title: 'Ticket overdue',
            message:
                '${task.title} was due ${DateFormat('dd MMM yyyy').format(due.toLocal())}.',
            icon: Icons.warning_amber_outlined,
            color: const Color(0xFFEF4444),
            createdAt: due,
          ));
        } else if (days <= 1) {
          items.add(_TaskNotification(
            id: '${task.id}:due-soon:${due.millisecondsSinceEpoch}',
            task: task,
            title: days == 0 ? 'Due today' : 'Due tomorrow',
            message: '${task.title} is due ${_formatDue(due)}.',
            icon: Icons.event_available_outlined,
            color: const Color(0xFFF59E0B),
            createdAt: due,
          ));
        }
      }
    }

    final unique = <String, _TaskNotification>{};
    for (final item in items) {
      unique[item.id] = item;
    }

    final list = unique.values.toList();
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  String _assignedUserName(TaskItem task) {
    final assigned = task.raw['assignedUser'];
    if (assigned is Map) {
      final name = assigned['name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name;
      final email = assigned['email']?.toString();
      if (email != null && email.trim().isNotEmpty) return email;
    }
    return 'User ${task.assignedUserId ?? ''}'.trim();
  }

  String _formatDue(DateTime value) {
    final time = DateFormat('h:mm a').format(value.toLocal());
    final hasTime = value.hour != 0 || value.minute != 0;
    return hasTime
        ? '${DateFormat('dd MMM yyyy').format(value.toLocal())} at $time'
        : DateFormat('dd MMM yyyy').format(value.toLocal());
  }
}

class _TaskNotification {
  const _TaskNotification({
    required this.id,
    required this.task,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.createdAt,
  });

  final String id;
  final TaskItem task;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime? createdAt;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.read,
    required this.onTap,
  });

  final _TaskNotification notification;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final createdAt = notification.createdAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: notification.color.withValues(alpha: 0.12),
                child: Icon(notification.icon, color: notification.color),
              ),
              if (!read)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: read ? FontWeight.w800 : FontWeight.w900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('dd MMM yyyy, h:mm a')
                        .format(createdAt.toLocal()),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
        ),
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
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
