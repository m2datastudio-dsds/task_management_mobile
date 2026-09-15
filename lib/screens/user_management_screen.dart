import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import 'user_form_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    this.organizationId,
    this.organizationName,
  });

  final int? organizationId;
  final String? organizationName;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCreateUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserFormScreen()),
    );
    if (mounted) context.read<UserProvider>().loadUsers();
  }

  Future<void> _confirmDeactivate(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text(
          'Are you sure you want to deactivate ${user.name.isEmpty ? user.email : user.name}? They will lose access, but data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<UserProvider>().deactivateUser(user.id);
      if (!mounted) return;
      AppToast.success(context, 'User deactivated successfully');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  Future<void> _editMobile(AppUser user) async {
    final controller = TextEditingController(text: user.mobile);
    final formKey = GlobalKey<FormState>();
    final mobile = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Mobile Number'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
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
      AppToast.success(context, 'Mobile number updated successfully');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final auth = context.watch<AuthProvider>();
    final scopedUsers = provider.users.where((user) {
      final organizationId = widget.organizationId;
      return organizationId == null || _userBelongsToOrg(user, organizationId);
    }).toList();
    final filteredUsers = scopedUsers.where((user) {
      final text =
          '${user.name} ${user.email} ${user.role} ${user.organizationName ?? ''}'
              .toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.organizationId == null
          ? FloatingActionButton.extended(
              onPressed: _openCreateUser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add User'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: provider.loadUsers,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.paddingOf(context).bottom + 96),
          children: [
            SectionHeader(
              title: widget.organizationName == null
                  ? 'User Management'
                  : '${widget.organizationName} Users',
              subtitle: widget.organizationName == null
                  ? 'Manage system users, roles, access, and workload'
                  : 'Only users assigned to this organization',
            ),
            const SizedBox(height: 14),
            _SearchBox(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            _UserStats(users: scopedUsers),
            const SizedBox(height: 14),
            if (provider.loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            if (provider.error != null) ...[
              _ErrorBanner(message: provider.error!),
              const SizedBox(height: 12),
            ],
            if (!provider.loading && filteredUsers.isEmpty)
              EmptyState(
                title: 'No users found',
                message: widget.organizationName == null
                    ? 'Try another name, email, role, or organization.'
                    : 'No users found in this organization.',
              ),
            ...filteredUsers.map(
              (user) => _UserTile(
                user: user,
                taskCount: provider.taskCounts[user.id] ?? 0,
                canDeactivate: _canDeactivate(auth, user),
                canEditMobile: _canEditMobile(auth, user),
                onEditMobile: () => _editMobile(user),
                onDeactivate: () => _confirmDeactivate(user),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _userBelongsToOrg(AppUser user, int organizationId) {
    if (user.organizationId == organizationId) return true;
    return user.organizations.any((item) {
      final id = int.tryParse(
          '${item['id'] ?? item['orgid'] ?? item['organizationId']}');
      return id == organizationId;
    });
  }

  bool _canDeactivate(AuthProvider auth, AppUser user) {
    if (user.isDeleted) return false;
    if (auth.currentUser?.id == user.id) return false;
    if (user.role == 'super_admin') return false;
    if (auth.isSuperAdmin) return true;
    return user.role == 'employee' || user.role == 'intern';
  }

  bool _canEditMobile(AuthProvider auth, AppUser user) {
    if (user.isDeleted) return false;
    if (auth.isSuperAdmin) {
      return user.role == 'admin' || auth.currentUser?.id == user.id;
    }
    return user.role == 'employee' || user.role == 'intern';
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Search users by name, email, role, or organization...',
        prefixIcon: Icon(Icons.search_outlined),
      ),
    );
  }
}

class _UserStats extends StatelessWidget {
  const _UserStats({required this.users});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    final active = users.where((user) => !user.isDeleted).length;
    final inactive = users.where((user) => user.isDeleted).length;
    final admins = users.where((user) => user.role == 'admin').length;

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Active',
            value: '$active',
            color: const Color(0xFF22C55E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Inactive',
            value: '$inactive',
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Admins',
            value: '$admins',
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.taskCount,
    required this.canDeactivate,
    required this.canEditMobile,
    required this.onEditMobile,
    required this.onDeactivate,
  });

  final AppUser user;
  final int taskCount;
  final bool canDeactivate;
  final bool canEditMobile;
  final VoidCallback onEditMobile;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final displayName = user.name.isEmpty ? user.email : user.name;
    final created = user.createdAt == null
        ? 'Unknown'
        : DateFormat('dd MMM yyyy').format(user.createdAt!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    (displayName.isNotEmpty ? displayName[0] : '?')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
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
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((user.organizationName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          user.organizationName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (user.mobile.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          user.mobile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit mobile number',
                  onPressed: canEditMobile ? onEditMobile : null,
                  icon: const Icon(Icons.phone_android_outlined),
                  color: AppTheme.primary,
                ),
                IconButton(
                  tooltip: 'Deactivate user',
                  onPressed: canDeactivate ? onDeactivate : null,
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RoleChip(role: user.role),
                _StatusChip(active: !user.isDeleted),
                _InfoChip(
                  icon: Icons.task_alt_outlined,
                  label: '$taskCount ticket${taskCount == 1 ? '' : 's'}',
                ),
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: created,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin' || role == 'super_admin';
    return _ChipShell(
      color: isAdmin ? AppTheme.primary : const Color(0xFF64748B),
      child: Text(_label(role)),
    );
  }

  String _label(String value) {
    if (value.trim().isEmpty) return 'No role';
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      color: active ? const Color(0xFF22C55E) : const Color(0xFF64748B),
      child: Text(active ? 'Active' : 'Inactive'),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ChipShell extends StatelessWidget {
  const _ChipShell({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
        child: child,
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
