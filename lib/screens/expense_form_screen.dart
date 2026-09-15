import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/task_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  static const _categories = <String>[
    'Civil',
    'Carpentry',
    'Plumbing',
    'Electrical',
    'Others',
  ];

  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  DateTime _expenseDate = DateTime.now();
  final Set<int> _selectedTaskIds = {};
  String _descriptionMode = 'normal';
  bool _saving = false;
  bool _loadingTasks = false;

  @override
  void initState() {
    super.initState();
    _description.addListener(_onDescriptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTasks());
  }

  @override
  void dispose() {
    _description.removeListener(_onDescriptionChanged);
    _title.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    if (mounted) setState(() {});
  }

  List<_ExpenseTableRow> _parseDescriptionRows() {
    return _description.text
        .split(RegExp(r'[\r\n]+'))
        .map((line) {
          final cells = line.contains('\t')
              ? line.split('\t').map((value) => value.trim()).toList()
              : [line.trim()];
          return _ExpenseTableRow(cells);
        })
        .where((row) => row.cells.any((cell) => cell.isNotEmpty))
        .toList();
  }

  String _descriptionPayload() {
    if (_descriptionMode != 'table') return _description.text.trim();

    final rows = _parseDescriptionRows();
    if (rows.isEmpty) return '';
    final columnCount = rows.fold<int>(
      1,
      (count, row) => row.cells.length > count ? row.cells.length : count,
    );
    final columns = rows.length > 1
        ? _normalizeCells(rows.first.cells, columnCount)
        : List.generate(columnCount, (index) => 'Column ${index + 1}');
    final dataRows = rows.length > 1 ? rows.skip(1) : rows;

    return jsonEncode({
      'expenseDescriptionFormat': 'table',
      'columns': columns,
      'rows': dataRows
          .map((row) => _normalizeCells(row.cells, columnCount))
          .toList(),
    });
  }

  List<String> _normalizeCells(List<String> cells, int count) {
    return List.generate(
      count,
      (index) => index < cells.length ? cells[index] : '',
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_selectedTaskIds.isEmpty) {
      AppToast.error(context, 'Select at least one ticket');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ExpenseProvider>().create({
        'title': _title.text.trim(),
        'category': _category,
        'amount': double.parse(_amount.text.trim()),
        'description': _descriptionPayload(),
        'expenseDate': _expenseDate.toIso8601String(),
        'taskIds': _selectedTaskIds.toList(),
      });
      if (mounted) {
        AppToast.success(context, 'Expense submitted successfully');
        Navigator.pop(context, true);
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadTasks() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    setState(() => _loadingTasks = true);
    try {
      await context.read<TaskProvider>().loadTasks(
            adminView: false,
            userId: user.id,
            limit: 100,
            silent: true,
          );
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>().tasks;
    final descriptionRows = _parseDescriptionRows();
    return Scaffold(
      backgroundColor: AppTheme.workspace,
      appBar: AppBar(title: const Text('Add Expense')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Expense title',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Expense title is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    hint: const Text('Select category'),
                    items: _categories
                        .map((category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _category = value),
                    validator: (value) =>
                        value == null ? 'Select a category' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee_outlined),
                    ),
                    validator: (value) {
                      final amount = double.tryParse((value ?? '').trim());
                      if (amount == null || amount <= 0) {
                        return 'Enter an amount greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(DateFormat('dd MMM yyyy').format(_expenseDate)),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'normal',
                        icon: Icon(Icons.notes_outlined),
                        label: Text('Normal Text'),
                      ),
                      ButtonSegment(
                        value: 'table',
                        icon: Icon(Icons.table_chart_outlined),
                        label: Text('Excel/Table'),
                      ),
                    ],
                    selected: {_descriptionMode},
                    onSelectionChanged: (value) =>
                        setState(() => _descriptionMode = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    minLines: _descriptionMode == 'table' ? 6 : 3,
                    maxLines: _descriptionMode == 'table' ? 10 : 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter description or paste Excel rows',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_descriptionMode == 'table' &&
                      descriptionRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ExpenseTablePreview(rows: descriptionRows),
                  ],
                  const SizedBox(height: 16),
                  _TaskSelector(
                    tasks: tasks,
                    selectedTaskIds: _selectedTaskIds,
                    loading: _loadingTasks,
                    onChanged: (taskId, selected) {
                      setState(() {
                        if (selected) {
                          _selectedTaskIds.add(taskId);
                        } else {
                          _selectedTaskIds.remove(taskId);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Submit Expense'),
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

class _ExpenseTableRow {
  const _ExpenseTableRow(this.cells);

  final List<String> cells;
}

class _ExpenseTablePreview extends StatelessWidget {
  const _ExpenseTablePreview({required this.rows});

  final List<_ExpenseTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final columnCount = rows.fold<int>(
      1,
      (count, row) => row.cells.length > count ? row.cells.length : count,
    );
    final dataRows = rows.length > 1 ? rows.skip(1).toList() : rows;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_outlined,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                '${dataRows.length} row${dataRows.length == 1 ? '' : 's'} ready',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columns: List.generate(
                columnCount,
                (index) => DataColumn(
                  label: Text(
                    rows.length > 1 && index < rows.first.cells.length
                        ? rows.first.cells[index]
                        : 'Column ${index + 1}',
                  ),
                ),
              ),
              rows: dataRows.take(5).map((row) {
                return DataRow(
                  cells: List.generate(
                    columnCount,
                    (index) => DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          index < row.cells.length ? row.cells[index] : '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSelector extends StatelessWidget {
  const _TaskSelector({
    required this.tasks,
    required this.selectedTaskIds,
    required this.loading,
    required this.onChanged,
  });

  final List<TaskItem> tasks;
  final Set<int> selectedTaskIds;
  final bool loading;
  final void Function(int taskId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Map Tickets',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!loading && tasks.isEmpty)
            Text(
              'No assigned tickets found.',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...tasks.map((task) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selectedTaskIds.contains(task.id),
                onChanged: (value) => onChanged(task.id, value == true),
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  task.status?.replaceAll('_', ' ') ?? 'No status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
        ],
      ),
    );
  }
}
