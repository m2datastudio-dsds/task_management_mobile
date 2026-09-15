import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bank.dart';
import '../providers/bank_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/organization_terminology.dart';
import '../widgets/empty_state.dart';

class BankManagementScreen extends StatefulWidget {
  const BankManagementScreen({super.key});

  @override
  State<BankManagementScreen> createState() => _BankManagementScreenState();
}

class _BankManagementScreenState extends State<BankManagementScreen> {
  bool get _usesBankLabels => OrganizationTerminology.usesBankLabels(
      context.read<AuthProvider>().currentUser?.organizationName);

  String get _itemLabel => _usesBankLabels ? 'Bank' : 'Category';
  String get _itemsLabel => _usesBankLabels ? 'banks' : 'categories';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BankProvider>();
      if (!provider.loading) provider.load();
    });
  }

  Future<void> _openForm([Bank? bank]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _BankDialog(bank: bank, itemLabel: _itemLabel),
    );
    if (result == null || !mounted) return;
    try {
      final provider = context.read<BankProvider>();
      if (bank == null) {
        await provider.create(result);
        if (mounted)
          AppToast.success(context, '$_itemLabel created successfully');
      } else {
        await provider.update(bank.id, result);
        if (mounted)
          AppToast.success(context, '$_itemLabel updated successfully');
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  Future<void> _deactivate(Bank bank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deactivate ${_itemLabel.toLowerCase()}?'),
        content: Text(
            '${bank.displayName} will no longer be available for new tickets.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<BankProvider>().deactivate(bank.id);
      if (mounted) {
        AppToast.success(context, '$_itemLabel deactivated successfully');
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BankProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_business_outlined),
        label: Text('Add $_itemLabel'),
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: provider.loading && provider.banks.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null && provider.banks.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    EmptyState(
                        title: 'Could not load $_itemsLabel',
                        message: provider.error!),
                  ])
                : provider.banks.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        EmptyState(
                            title: 'No $_itemsLabel yet',
                            message:
                                'Add the first ${_itemLabel.toLowerCase()} for ticket work.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: provider.banks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final bank = provider.banks[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F1EC),
                                child: Icon(Icons.category_outlined,
                                    color: AppTheme.primary),
                              ),
                              title: Text(bank.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: _CategoryDetails(bank: bank),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) => value == 'edit'
                                    ? _openForm(bank)
                                    : _deactivate(bank),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                      value: 'deactivate',
                                      child: Text('Deactivate')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _BankDialog extends StatefulWidget {
  const _BankDialog({this.bank, required this.itemLabel});
  final Bank? bank;
  final String itemLabel;

  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final bank = widget.bank;
    _name = TextEditingController(text: bank?.name);
    _description = TextEditingController(text: bank?.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.bank == null
            ? 'Add ${widget.itemLabel}'
            : 'Edit ${widget.itemLabel}'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(
                    _name, '${widget.itemLabel} name', Icons.category_outlined),
                _field(_description, 'Description', Icons.notes_outlined,
                    required: false, lines: 3),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!_key.currentState!.validate()) return;
              Navigator.pop(context, {
                'name': _name.text.trim(),
                'description': _description.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
      {bool required = true, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
            : null,
      ),
    );
  }
}

class _CategoryDetails extends StatelessWidget {
  const _CategoryDetails({required this.bank});

  final Bank bank;

  @override
  Widget build(BuildContext context) {
    final details = [
      bank.description,
    ].where((value) => (value ?? '').trim().isNotEmpty).join('\n');

    if (details.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        details,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
