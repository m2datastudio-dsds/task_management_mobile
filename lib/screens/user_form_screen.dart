import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  String? _roleName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _roleName =
        context.read<AuthProvider>().isSuperAdmin ? 'admin' : 'employee';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadRoles();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<UserProvider>().createUser({
        'name': _name.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'mobile': _mobile.text.trim(),
        'password': _password.text,
        'roleName': _roleName,
      });
      if (mounted) {
        AppToast.success(context, 'User created successfully');
        Navigator.pop(context);
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = context.watch<AuthProvider>().isSuperAdmin;
    final roleProvider = context.watch<UserProvider>();
    final roleOptions = _roleOptions(roleProvider, isSuperAdmin);
    if (_roleName != null && !roleOptions.contains(_roleName)) {
      _roleName = roleOptions.isEmpty ? null : roleOptions.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add User')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add_alt_1),
          label: Text(_saving ? 'Creating...' : 'Create User'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.paddingOf(context).bottom + 92),
          children: [
            const SectionHeader(
              title: 'Create User',
              subtitle: 'Add a team member and assign their access role',
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter user name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter email address',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Email is required';
                      final valid =
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
                      return valid ? null : 'Invalid email format';
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      hintText: 'Enter mobile number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      final mobile = value?.trim() ?? '';
                      if (mobile.isEmpty) return 'Mobile number is required';
                      final valid =
                          RegExp(r'^\+?[0-9]{7,15}$').hasMatch(mobile);
                      return valid ? null : 'Enter a valid mobile number';
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 5) {
                        return 'Password must be at least 5 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _roleName,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    hint: const Text('Select a role'),
                    items: roleOptions
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(_roleLabel(role)),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Please select a role' : null,
                    onChanged: (value) => setState(() => _roleName = value),
                  ),
                  if (roleProvider.rolesLoading) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _RolePolicyNote(isSuperAdmin: isSuperAdmin),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  List<String> _roleOptions(UserProvider provider, bool isSuperAdmin) {
    if (isSuperAdmin) return const ['admin'];

    final roles = provider.roles
        .map((role) => role.name)
        .where((role) => role != 'super_admin' && role != 'admin')
        .toSet()
        .toList()
      ..sort();

    if (roles.isEmpty) return const ['employee', 'intern'];
    return roles;
  }
}

class _RolePolicyNote extends StatelessWidget {
  const _RolePolicyNote({required this.isSuperAdmin});

  final bool isSuperAdmin;

  @override
  Widget build(BuildContext context) {
    final text = isSuperAdmin
        ? 'Super admin can create organization admins only.'
        : 'Admin can create employee or intern users for the selected organization.';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
