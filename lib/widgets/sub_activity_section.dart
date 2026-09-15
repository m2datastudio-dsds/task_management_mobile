import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sub_activity.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/roles.dart';
import 'app_card.dart';

class SubActivitySection extends StatefulWidget {
  const SubActivitySection({super.key, required this.task, this.taskStatus});

  final TaskItem task;
  final String? taskStatus;

  @override
  State<SubActivitySection> createState() => _SubActivitySectionState();
}

class _SubActivitySectionState extends State<SubActivitySection> {
  List<SubActivity> _activities = [];
  List<List<String>> _tableRows = [];
  List<List<String>> _originalTableRows = [];
  final Set<int> _selectedTableRows = {};
  bool _loading = true;
  bool _saving = false;
  bool _tableDirty = false;
  String? _error;

  String get _taskStatus =>
      (widget.taskStatus ?? widget.task.status ?? '').toLowerCase().trim();

  bool get _finished => ['completed', 'closed'].contains(_taskStatus);

  bool get _started => _taskStatus == 'in_progress';

  List<SubActivity> get _tableActivities =>
      _activities.where((item) => item.isTableFormat).toList();

  List<SubActivity> get _normalActivities =>
      _activities.where((item) => !item.isTableFormat).toList();

  bool get _tableMode => _tableActivities.isNotEmpty;

  List<String> get _tableColumns =>
      _tableActivities.isEmpty ? const [] : _tableActivities.first.tableColumns;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await context.read<TaskProvider>().loadSubActivities(widget.task.id);
      if (mounted) {
        setState(() {
          _activities = data;
          _syncTableRows();
        });
      }
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncTableRows() {
    final columns = _tableColumns;
    _tableRows = _tableActivities
        .map((activity) => _normalizeCells(activity.tableCells, columns.length))
        .toList();
    _originalTableRows =
        _tableRows.map((row) => List<String>.from(row)).toList();
    _selectedTableRows.clear();
    _tableDirty = false;
  }

  List<String> _normalizeCells(List<String> cells, int count) {
    return List.generate(
        count, (index) => index < cells.length ? cells[index] : '');
  }

  Future<void> _addNormal() async {
    final data = await showDialog<_ActivityInput>(
      context: context,
      builder: (_) => const _ActivityDialog(),
    );
    if (data == null || !mounted) return;
    final names = _parseActivityNames(data.title);
    if (names.isEmpty) return;

    setState(() => _saving = true);
    try {
      final provider = context.read<TaskProvider>();
      for (final name in names) {
        await provider.createSubActivity(widget.task.id, {
          'title': name,
          'remarks': data.remarks,
        });
      }
      await _load();
      if (mounted) AppToast.success(context, 'List of ticket added successfully');
    } catch (err) {
      _showError(err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editNormal(SubActivity activity) async {
    final data = await showDialog<_ActivityInput>(
      context: context,
      builder: (_) => _ActivityDialog(activity: activity),
    );
    if (data == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<TaskProvider>().updateSubActivity(activity.id, {
        'title': data.title,
        'status': data.status,
        'remarks': data.remarks,
      });
      await _load();
      if (mounted) {
        AppToast.success(context, 'List of ticket updated successfully');
      }
    } catch (err) {
      _showError(err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteNormal(SubActivity activity) async {
    final confirmed = await _confirmDelete(activity.title);
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<TaskProvider>().deleteSubActivity(activity.id);
      await _load();
      if (mounted) {
        AppToast.success(context, 'List of ticket deleted successfully');
      }
    } catch (err) {
      _showError(err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addTableRow() {
    if (_tableColumns.isEmpty) return;
    setState(() {
      _tableRows.add(List.generate(_tableColumns.length, (_) => ''));
      _tableDirty = true;
    });
  }

  void _updateTableCell(int rowIndex, int columnIndex, String value) {
    if (rowIndex >= _tableRows.length ||
        columnIndex >= _tableRows[rowIndex].length) {
      return;
    }
    if (!_isEditableColumn(columnIndex)) return;
    setState(() {
      _tableRows[rowIndex][columnIndex] = value;
      _tableDirty = true;
    });
  }

  String _normalizedColumn(int index) => index < _tableColumns.length
      ? _tableColumns[index].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
      : '';

  bool _isQuantityColumn(int index) => const {
        'qty',
        'quantity',
        'qtynumber',
        'quantitynumber'
      }.contains(_normalizedColumn(index));

  bool _isEditableColumn(int index) => const {
        'workcontent',
        'work',
        'content',
        'qty',
        'quantity',
        'qtynumber',
        'quantitynumber'
      }.contains(_normalizedColumn(index));

  Future<void> _deleteSelectedTableRows() async {
    if (_selectedTableRows.isEmpty) return;
    final confirmed = await _confirmDelete(
      '${_selectedTableRows.length} selected row${_selectedTableRows.length == 1 ? '' : 's'}',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final provider = context.read<TaskProvider>();
      final existingRows = _tableActivities;
      for (final rowIndex in _selectedTableRows.toList()
        ..sort((a, b) => b.compareTo(a))) {
        if (rowIndex < existingRows.length) {
          await provider.deleteSubActivity(existingRows[rowIndex].id);
        }
        if (rowIndex < _tableRows.length) _tableRows.removeAt(rowIndex);
      }
      _selectedTableRows.clear();
      await _load();
      if (mounted) {
        AppToast.success(context, 'Selected rows deleted successfully');
      }
    } catch (err) {
      _showError(err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveTable() async {
    final columns = _tableColumns;
    if (columns.isEmpty) return;

    for (var row = 0; row < _tableRows.length; row++) {
      for (var column = 0; column < columns.length; column++) {
        if (!_isQuantityColumn(column)) continue;
        final oldQty = double.tryParse(_originalTableRows[row][column]);
        final newQty = double.tryParse(_tableRows[row][column]);
        if (newQty == null ||
            newQty < 0 ||
            (oldQty != null && newQty > oldQty)) {
          _showError('Quantity can only be reduced, including to zero');
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final provider = context.read<TaskProvider>();
      final existingRows = _tableActivities;
      for (var index = 0; index < _tableRows.length; index++) {
        final cells = _normalizeCells(_tableRows[index], columns.length);
        final title = cells.where((cell) => cell.trim().isNotEmpty).join(' - ');
        if (title.trim().isEmpty) continue;
        final remarks = existingRows.isNotEmpty
            ? existingRows.first.tableRemarksFor(cells)
            : null;

        if (index < existingRows.length) {
          await provider.updateSubActivity(existingRows[index].id, {
            'title': title,
            'remarks': remarks,
          });
        } else {
          await provider.createSubActivity(widget.task.id, {
            'title': title,
            'remarks': remarks,
          });
        }
      }
      await _load();
      if (mounted) AppToast.success(context, 'Table saved successfully');
    } catch (err) {
      _showError(err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDelete(String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete list of ticket?'),
        content: Text(label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(Object error) {
    if (mounted) {
      AppToast.error(context, error);
    }
  }

  List<String> _parseActivityNames(String value) {
    return value
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isEmployee = user != null &&
        !Roles.isAdminLike(user.role) &&
        !Roles.isSuperAdmin(user.role);
    final canModify = !_finished && _started && isEmployee;
    final completed =
        _activities.where((item) => item.status == 'completed').length;
    final progress = _activities.isEmpty ? 0.0 : completed / _activities.length;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_outlined, color: AppTheme.primary),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'List of Ticket',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('$completed of ${_activities.length} completed',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: progress, minHeight: 7),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(children: [
                const Expanded(
                  child: Text(
                    'Unable to load list of ticket. Tap refresh to try again.',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh list of ticket',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ]),
            )
          else if (_activities.isEmpty)
            Text(
              'No list of ticket added.',
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w600),
            )
          else if (_tableMode) ...[
            _TableSubActivities(
              columns: _tableColumns,
              rows: _tableRows,
              editableColumns:
                  List.generate(_tableColumns.length, _isEditableColumn),
              canModify: canModify,
              saving: _saving,
              dirty: _tableDirty,
              onCellChanged: (row, column, value) =>
                  _updateTableCell(row, column, value),
              onSave: _saveTable,
            ),
            if (_normalActivities.isNotEmpty) ...[
              const SizedBox(height: 14),
              ..._normalActivities.map((activity) {
                return _ActivityRow(
                  activity: activity,
                  canEdit: false,
                  canDelete: false,
                  onEdit: () => _editNormal(activity),
                  onDelete: () => _deleteNormal(activity),
                );
              }),
            ],
          ] else
            ..._normalActivities.map((activity) {
              return _ActivityRow(
                activity: activity,
                canEdit: false,
                canDelete: false,
                onEdit: () => _editNormal(activity),
                onDelete: () => _deleteNormal(activity),
              );
            }),
        ],
      ),
    );
  }
}

class _TableSubActivities extends StatelessWidget {
  const _TableSubActivities({
    required this.columns,
    required this.rows,
    required this.editableColumns,
    required this.canModify,
    required this.saving,
    required this.dirty,
    required this.onCellChanged,
    required this.onSave,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final List<bool> editableColumns;
  final bool canModify;
  final bool saving;
  final bool dirty;
  final void Function(int row, int column, String value) onCellChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            columns: [
              ...columns.map((column) => DataColumn(label: Text(column))),
            ],
            rows: List.generate(rows.length, (rowIndex) {
              return DataRow(
                cells: [
                  ...List.generate(columns.length, (columnIndex) {
                    final value = columnIndex < rows[rowIndex].length
                        ? rows[rowIndex][columnIndex]
                        : '';
                    return DataCell(
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          initialValue: value,
                          enabled: canModify &&
                              !saving &&
                              editableColumns[columnIndex],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                          ),
                          onChanged: (text) =>
                              onCellChanged(rowIndex, columnIndex, text),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ),
        ),
        if (canModify) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: saving || !dirty ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving...' : 'Save Changes'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final SubActivity activity;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = activity.status.replaceAll('_', ' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            activity.status == 'completed'
                ? Icons.check_circle
                : activity.status == 'in_progress'
                    ? Icons.timelapse
                    : Icons.radio_button_unchecked,
            color: activity.status == 'completed'
                ? const Color(0xFF15803D)
                : AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                if (activity.displayRemarks?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(activity.displayRemarks!,
                      style: TextStyle(color: Colors.grey[700])),
                ],
              ],
            ),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Update')),
                if (canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityInput {
  const _ActivityInput(this.title, this.status, this.remarks);
  final String title;
  final String status;
  final String remarks;
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({this.activity});
  final SubActivity? activity;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _remarks;
  late String _status;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.activity?.title);
    _remarks = TextEditingController(text: widget.activity?.displayRemarks);
    _status = widget.activity?.status ?? 'pending';
  }

  @override
  void dispose() {
    _title.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.activity == null
            ? 'Add List of Ticket'
            : 'Update List of Ticket'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _title,
                  minLines: widget.activity == null ? 3 : 1,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: widget.activity == null
                        ? 'Activity names (one per line)'
                        : 'Activity name',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Activity name is required'
                      : null,
                ),
                if (widget.activity != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('In Progress')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Completed')),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarks,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    alignLabelWithHint: true,
                  ),
                ),
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
              Navigator.pop(
                context,
                _ActivityInput(
                    _title.text.trim(), _status, _remarks.text.trim()),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
}
