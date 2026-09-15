import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_role.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoleData();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRoleData() async {
    final provider = context.read<UserProvider>();
    await Future.wait([
      provider.loadRoles(),
      provider.loadUsers(),
    ]);
  }

  Future<void> _openCreateRoleSheet() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const SingleChildScrollView(child: _CreateRoleSheet()),
        ),
      ),
    );

    if (created == true && mounted) {
      await context.read<UserProvider>().loadRoles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final loading = provider.loading || provider.rolesLoading;
    final visibleRoles = provider.roles
        .where((role) => role.name.toLowerCase() != 'super_admin')
        .toList();
    final filteredRoles = visibleRoles.where((role) {
      final text = '${role.name} ${role.displayName}'.toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : _openCreateRoleSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Role'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: _loadRoleData,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 96,
          ),
          children: [
            const SectionHeader(
              title: 'Role Management',
              subtitle: 'Manage system roles, access labels, and assignments',
            ),
            const SizedBox(height: 14),
            _SearchBox(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            _RoleStats(
              roles: visibleRoles,
              assignedRoleCount: provider.users
                  .map((user) => user.role.toLowerCase())
                  .where((role) => role.isNotEmpty && role != 'super_admin')
                  .toSet()
                  .length,
            ),
            const SizedBox(height: 14),
            if (loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            if (provider.rolesError != null || provider.error != null) ...[
              _ErrorBanner(message: provider.rolesError ?? provider.error!),
              const SizedBox(height: 12),
            ],
            if (!loading && filteredRoles.isEmpty)
              EmptyState(
                title: visibleRoles.isEmpty
                    ? 'No roles found'
                    : 'No matching roles',
                message: visibleRoles.isEmpty
                    ? 'Tap Add Role to create the first role.'
                    : 'Try another role name.',
              ),
            ...filteredRoles.map((role) {
              final roleUsers = provider.users
                  .where((user) =>
                      user.role.toLowerCase() == role.name.toLowerCase())
                  .toList();
              return _RoleTile(role: role, userCount: roleUsers.length);
            }),
          ],
        ),
      ),
    );
  }
}

class _CreateRoleSheet extends StatefulWidget {
  const _CreateRoleSheet();

  @override
  State<_CreateRoleSheet> createState() => _CreateRoleSheetState();
}

class _CreateRoleSheetState extends State<_CreateRoleSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<UserProvider>().createRole(_controller.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
      AppToast.success(context, 'Role created successfully');
    } catch (err) {
      setState(() => _error = _messageFromError(err));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Create Role',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              enabled: !_saving,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Role name',
                hintText: 'team coordinator',
                prefixIcon: Icon(Icons.security_outlined),
              ),
              validator: (value) {
                final role = value?.trim() ?? '';
                if (role.isEmpty) return 'Role name is required';
                if (!RegExp(r'^[a-zA-Z0-9 _-]+$').hasMatch(role)) {
                  return 'Use letters, numbers, spaces, hyphens, or underscores';
                }
                return null;
              },
              onFieldSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Role'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageFromError(Object err) {
    final message = err.toString().trim();
    if (message.isEmpty) return 'Something went wrong';
    return message
        .replaceFirst(RegExp(r'^(Exception|ApiException):\s*'), '')
        .trim();
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
        hintText: 'Search roles...',
        prefixIcon: Icon(Icons.search_outlined),
      ),
    );
  }
}

class _RoleStats extends StatelessWidget {
  const _RoleStats({required this.roles, required this.assignedRoleCount});

  final List<AppRole> roles;
  final int assignedRoleCount;

  @override
  Widget build(BuildContext context) {
    final custom = roles.where((role) => !role.isProtected).length;

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Total',
            value: '${roles.length}',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Custom',
            value: '$custom',
            color: const Color(0xFF22C55E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Assigned',
            value: '$assignedRoleCount',
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

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

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.userCount});

  final AppRole role;
  final int userCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: AppTheme.primary,
              child: Text(
                _initial(role.displayName),
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
                    role.displayName,
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
                    role.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RoleTypeChip(protected: role.isProtected),
                      _InfoChip(
                        icon: Icons.people_outline,
                        label: '$userCount user${userCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              role.isProtected ? Icons.lock_outline : Icons.edit_outlined,
              color: role.isProtected ? Colors.grey[600] : AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}

class _RoleTypeChip extends StatelessWidget {
  const _RoleTypeChip({required this.protected});

  final bool protected;

  @override
  Widget build(BuildContext context) {
    final color = protected ? const Color(0xFF64748B) : const Color(0xFF22C55E);
    return _ChipShell(
      color: color,
      child: Text(protected ? 'System' : 'Custom'),
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
