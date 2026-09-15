import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';

class PurchaseOrderFormScreen extends StatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  State<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branch = TextEditingController();
  final _items = TextEditingController();
  int? _userId;
  int? _bankId;
  String? _selectedBranch;
  bool _saving = false;
  List<List<String>> _rows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<UserProvider>().loadUsers();
      context.read<BankProvider>().load();
      context.read<TaskProvider>().loadTasks(
            adminView: true,
            userId: auth.currentUser?.id ?? 0,
            limit: 1000,
            silent: true,
          );
    });
  }

  @override
  void dispose() {
    _branch.dispose();
    _items.dispose();
    super.dispose();
  }

  void _parseItems(String value) {
    final rows = value
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.split('\t').map((cell) => cell.trim()).toList())
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();
    setState(() => _rows = rows);
  }

  Future<void> _create() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_rows.isEmpty) {
      AppToast.error(context, 'Paste at least one item row');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ApiClient>().post('/purchase-orders', {
        'userId': _userId,
        'categoryId': _bankId,
        'branchName': _branch.text.trim(),
        'items': _rows,
      });
      if (!mounted) return;
      AppToast.success(context, 'Purchase order created successfully');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final users = context
        .watch<UserProvider>()
        .users
        .where((user) => !user.isDeleted && user.id != auth.currentUser?.id)
        .toList();
    final banks = context.watch<BankProvider>().banks;
    final tasks = context.watch<TaskProvider>().tasks;
    final selectedBank = banks.where((bank) => bank.id == _bankId).firstOrNull;
    final branchOptionsByName = <String, String>{};
    final storedBranchValues = <String?>[
      selectedBank?.branchName,
      ...tasks
          .where((task) => task.bankId == _bankId)
          .map((task) => task.bankBranchName),
    ];
    for (final storedValue in storedBranchValues) {
      for (final branch in _splitBranchNames(storedValue)) {
        branchOptionsByName.putIfAbsent(branch.toLowerCase(), () => branch);
      }
    }
    final branchOptions = branchOptionsByName.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final columnCount = _rows.fold<int>(
        0, (largest, row) => row.length > largest ? row.length : largest);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Purchase Order')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 16, runSpacing: 16, children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        initialValue: _userId,
                        decoration: const InputDecoration(
                            labelText: 'Select User',
                            prefixIcon: Icon(Icons.person_outline)),
                        items: users
                            .map((user) => DropdownMenuItem(
                                value: user.id,
                                child: Text(user.name.isEmpty
                                    ? user.email
                                    : user.name)))
                            .toList(),
                        onChanged: (value) => setState(() => _userId = value),
                        validator: (value) =>
                            value == null ? 'Select a user' : null,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        initialValue: _bankId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Select Bank',
                            prefixIcon: Icon(Icons.account_balance_outlined)),
                        items: banks
                            .map((bank) => DropdownMenuItem(
                                value: bank.id,
                                child: Text(bank.displayName,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _bankId = value;
                            _selectedBranch = null;
                            _branch.clear();
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Select a bank' : null,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_bankId),
                        initialValue: _selectedBranch,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Branch',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: branchOptions
                            .map((branch) => DropdownMenuItem<String>(
                                  value: branch,
                                  child: Text(
                                    branch,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: _bankId == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedBranch = value;
                                  _branch.text = value ?? '';
                                });
                              },
                        validator: (value) =>
                            value == null ? 'Select a branch' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _items,
                    minLines: 7,
                    maxLines: 14,
                    onChanged: _parseItems,
                    decoration: const InputDecoration(
                      labelText: 'Item List',
                      hintText:
                          'Copy rows and columns from Excel and paste here',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Paste the item list'
                        : null,
                  ),
                  if (_rows.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('${_rows.length} item row(s) detected',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('#')),
                          for (var column = 0; column < columnCount; column++)
                            DataColumn(label: Text('Column ${column + 1}')),
                        ],
                        rows: [
                          for (var index = 0; index < _rows.length; index++)
                            DataRow(cells: [
                              DataCell(Text('${index + 1}')),
                              for (var column = 0;
                                  column < columnCount;
                                  column++)
                                DataCell(Text(column < _rows[index].length
                                    ? _rows[index][column]
                                    : '')),
                            ]),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _create,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(_saving ? 'Creating...' : 'Create PO'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Iterable<String> _splitBranchNames(String? value) sync* {
  if (value == null) return;
  for (final part in value.split(RegExp(r'[\r\n,;]+'))) {
    final branch = part.trim();
    if (branch.isNotEmpty) yield branch;
  }
}
