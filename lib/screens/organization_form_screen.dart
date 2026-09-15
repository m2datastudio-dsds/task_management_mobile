import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../providers/organization_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class OrganizationFormScreen extends StatefulWidget {
  const OrganizationFormScreen({super.key, this.organization});

  final Organization? organization;

  @override
  State<OrganizationFormScreen> createState() => _OrganizationFormScreenState();
}

class _OrganizationFormScreenState extends State<OrganizationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _description;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _addressLine1;
  late final TextEditingController _addressLine2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _postalCode;
  final List<int> _adminIds = [];
  int _step = 1;
  bool _saving = false;

  bool get _editing => widget.organization != null;

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    _name = TextEditingController(text: org?.name ?? '');
    _code = TextEditingController(text: org?.code ?? '');
    _description = TextEditingController(text: org?.description ?? '');
    _email = TextEditingController(text: org?.email ?? '');
    _phone = TextEditingController(text: org?.phone ?? '');
    _website = TextEditingController(text: org?.website ?? '');
    _addressLine1 = TextEditingController(text: org?.addressLine1 ?? '');
    _addressLine2 = TextEditingController(text: org?.addressLine2 ?? '');
    _city = TextEditingController(text: org?.city ?? '');
    _state = TextEditingController(text: org?.state ?? '');
    _country = TextEditingController(text: org?.country ?? '');
    _postalCode = TextEditingController(text: org?.postalCode ?? '');
    _adminIds.addAll(_readAdminIds(org));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final users = context.read<UserProvider>();
      if (users.admins.isEmpty) users.loadAdmins();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    _email.dispose();
    _phone.dispose();
    _website.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final admins = context.read<UserProvider>().admins;
    final adminNames = _adminIds
        .map((id) => _findAdmin(admins, id))
        .whereType<AppUser>()
        .map((admin) => admin.name)
        .where((name) => name.trim().isNotEmpty)
        .toList();

    final payload = {
      'name': _name.text.trim(),
      'code': _code.text.trim(),
      'description': _description.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'website': _website.text.trim(),
      'addressLine1': _addressLine1.text.trim(),
      'addressLine2': _addressLine2.text.trim(),
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'country': _country.text.trim(),
      'postalCode': _postalCode.text.trim(),
      if (!_editing) 'adminNames': adminNames,
    };

    try {
      final provider = context.read<OrganizationProvider>();
      final message = _editing
          ? 'Organization updated successfully'
          : 'Organization created successfully';
      if (!_editing) {
        await provider.create(payload);
      } else {
        await provider.update(widget.organization!.id, payload);
      }
      if (mounted) {
        AppToast.success(context, message);
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

  AppUser? _findAdmin(List<AppUser> admins, int id) {
    for (final admin in admins) {
      if (admin.id == id) return admin;
    }
    return null;
  }

  void _addAdmin(int? id) {
    if (id == null || _adminIds.contains(id) || _editing) return;
    setState(() => _adminIds.add(id));
  }

  void _removeAdmin(int id) {
    if (_editing) return;
    setState(() => _adminIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>();
    final availableAdmins =
        users.admins.where((admin) => !_adminIds.contains(admin.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Organization' : 'Create Organization'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (_step == 2) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => setState(() => _step = 1),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : _step == 1
                        ? () {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _step = 2);
                            }
                          }
                        : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_step == 1
                        ? Icons.arrow_forward
                        : Icons.business_outlined),
                label: Text(_saving
                    ? 'Saving...'
                    : _step == 1
                        ? 'Next'
                        : (_editing
                            ? 'Update Organization'
                            : 'Create Organization')),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.paddingOf(context).bottom + 96),
          children: [
            SectionHeader(
              title: _editing ? 'Edit Organization' : 'Create New Organization',
              subtitle: _step == 1
                  ? 'Fill in the organization details to continue'
                  : 'Add address details and assign admins',
            ),
            const SizedBox(height: 14),
            _StepIndicator(step: _step),
            const SizedBox(height: 14),
            if (_step == 1)
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Field(
                      controller: _name,
                      label: 'Name',
                      hint: 'e.g. Innovate Inc.',
                      icon: Icons.business_outlined,
                      requiredMessage: 'Name is required',
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _code,
                      label: 'Code',
                      hint: 'e.g. INVT01',
                      icon: Icons.tag_outlined,
                      requiredMessage: 'Code is required',
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _email,
                      label: 'Email',
                      hint: 'contact@company.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _phone,
                      label: 'Phone',
                      hint: '+91 98765 43210',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _website,
                      label: 'Website',
                      hint: 'https://company.com',
                      icon: Icons.language_outlined,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Short description...',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Field(
                      controller: _addressLine1,
                      label: 'Address Line 1',
                      hint: 'Street, Building',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _addressLine2,
                      label: 'Address Line 2',
                      hint: 'Area, Landmark',
                      icon: Icons.map_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _city,
                            label: 'City',
                            hint: 'Chennai',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Field(
                            controller: _state,
                            label: 'State',
                            hint: 'Tamil Nadu',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _country,
                            label: 'Country',
                            hint: 'India',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Field(
                            controller: _postalCode,
                            label: 'Postal Code',
                            hint: '600001',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _AdminSelector(
                      admins: users.admins,
                      availableAdmins: availableAdmins,
                      selectedIds: _adminIds,
                      loading: users.admins.isEmpty,
                      locked: _editing,
                      onAdd: _addAdmin,
                      onRemove: _removeAdmin,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<int> _readAdminIds(Organization? org) {
    if (org == null) return const [];
    return org.organizationUserMap
        .where((item) =>
            (item['role'] ?? '').toString().toLowerCase() == 'admin' &&
            item['isactive'] != false)
        .map((item) {
          final user = item['user'];
          return int.tryParse(
              '${item['userid'] ?? (user is Map ? user['id'] : null)}');
        })
        .whereType<int>()
        .toList();
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StepPill(label: 'Details', active: step == 1)),
        const SizedBox(width: 8),
        Expanded(child: _StepPill(label: 'Address & Admin', active: step == 2)),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? AppTheme.primary : AppTheme.border,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? AppTheme.primary : Colors.grey[700],
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.requiredMessage,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? requiredMessage;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      validator: requiredMessage == null
          ? null
          : (value) =>
              value == null || value.trim().isEmpty ? requiredMessage : null,
    );
  }
}

class _AdminSelector extends StatelessWidget {
  const _AdminSelector({
    required this.admins,
    required this.availableAdmins,
    required this.selectedIds,
    required this.loading,
    required this.locked,
    required this.onAdd,
    required this.onRemove,
  });

  final List<AppUser> admins;
  final List<AppUser> availableAdmins;
  final List<int> selectedIds;
  final bool loading;
  final bool locked;
  final ValueChanged<int?> onAdd;
  final ValueChanged<int> onRemove;

  AppUser? _findAdmin(int id) {
    for (final admin in admins) {
      if (admin.id == id) return admin;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (selectedIds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedIds.map((id) {
              final admin = _findAdmin(id);
              final label = admin == null
                  ? '$id'
                  : (admin.name.isEmpty ? admin.email : admin.name);
              return InputChip(
                label: Text(label),
                onDeleted: locked ? null : () => onRemove(id),
              );
            }).toList(),
          )
        else
          Text(
            'No admin selected',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('admin-selector-${selectedIds.join(',')}'),
          initialValue: null,
          decoration: InputDecoration(
            labelText: locked ? 'Admin assignment locked' : 'Select Admin',
            helperText: loading
                ? 'Loading admins...'
                : locked
                    ? 'Admin reassignment is disabled on edit, same as web app.'
                    : null,
            prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          items: availableAdmins
              .map(
                (admin) => DropdownMenuItem<int>(
                  value: admin.id,
                  child: Text(admin.name.isEmpty ? admin.email : admin.name),
                ),
              )
              .toList(),
          onChanged: locked ? null : onAdd,
        ),
      ],
    );
  }
}
