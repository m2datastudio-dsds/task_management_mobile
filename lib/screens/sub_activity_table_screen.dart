import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sub_activity.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../utils/app_toast.dart';
import '../utils/roles.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class SubActivityTableScreen extends StatefulWidget {
  const SubActivityTableScreen({super.key});

  @override
  State<SubActivityTableScreen> createState() => _SubActivityTableScreenState();
}

class _SubActivityTableScreenState extends State<SubActivityTableScreen> {
  final List<_SubActivityRowData> _rows = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final taskProvider = context.read<TaskProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final adminView = Roles.isAdminLike(user.role);
      await taskProvider.loadTasks(
        adminView: adminView,
        userId: user.id,
        limit: 100,
        silent: true,
      );
      final visibleTasks = adminView
          ? taskProvider.tasks
          : taskProvider.tasks
              .where((task) => task.assignedUserId == user.id)
              .toList();
      final rows = <_SubActivityRowData>[];
      for (final task in visibleTasks) {
        final activities = await taskProvider.loadSubActivities(task.id);
        rows.addAll(activities.map(
          (activity) => _SubActivityRowData(task: task, activity: activity),
        ));
      }
      if (mounted) {
        setState(() {
          _rows
            ..clear()
            ..addAll(rows);
        });
      }
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final isAdmin = Roles.isAdminLike(user.role);
    final tasks = context.read<TaskProvider>().tasks.where((task) {
      final status = (task.status ?? '').toLowerCase();
      if (['completed', 'closed'].contains(status)) return false;
      if (isAdmin) return !auth.isSuperAdmin;
      return task.assignedUserId == user.id && status == 'in_progress';
    }).toList();

    final data = await showDialog<_SubActivityInput>(
      context: context,
      builder: (_) => _SubActivityDialog(tasks: tasks),
    );
    if (data == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final provider = context.read<TaskProvider>();
      for (final title in _parseActivityNames(data.title)) {
        await provider.createSubActivity(data.taskId, {
          'title': title,
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

  Future<void> _edit(_SubActivityRowData row, bool isAdmin) async {
    final data = await showDialog<_SubActivityInput>(
      context: context,
      builder: (_) => _SubActivityDialog(
        tasks: [row.task],
        activity: row.activity,
        fixedTaskId: row.task.id,
        canEditTitle: isAdmin,
        canEditStatus: !isAdmin,
      ),
    );
    if (data == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<TaskProvider>().updateSubActivity(row.activity.id, {
        if (isAdmin) 'title': data.title,
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

  Future<void> _delete(_SubActivityRowData row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete list of ticket?'),
        content: Text(row.activity.title),
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
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<TaskProvider>().deleteSubActivity(row.activity.id);
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

  Set<String> _parseActivityNames(String value) {
    return value
        .split(RegExp(r'[\r\n]+'))
        .map((line) {
          final cells = line.contains('\t')
              ? line
                  .split('\t')
                  .map((cell) => cell.trim())
                  .where((cell) => cell.isNotEmpty)
                  .toList()
              : [line.trim()];
          return cells.join(' - ').trim();
        })
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  void _showError(Object error) {
    if (mounted) {
      AppToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final user = auth.currentUser;
    final isAdmin =
        Roles.isAdminLike(user?.role) && !Roles.isSuperAdmin(user?.role);
    final canModify = user != null && !auth.isSuperAdmin;
    final canAdd = user != null &&
        !auth.isSuperAdmin &&
        (isAdmin ||
            taskProvider.tasks.any((task) =>
                task.assignedUserId == user.id &&
                (task.status ?? '').toLowerCase() == 'in_progress'));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: _saving ? null : _add,
              tooltip: 'Add list of ticket',
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 96,
          ),
          children: [
            SectionHeader(
              title: 'List of Ticket',
              subtitle: isAdmin
                  ? 'Add, edit, and monitor list of ticket'
                  : 'Update progress on your assigned list of ticket',
            ),
            const SizedBox(height: 12),
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              const SizedBox(height: 12),
            ],
            if (!_loading && _rows.isEmpty)
              EmptyState(
                title: 'No list of ticket',
                message: canModify
                    ? 'Tap the add button to create a list of ticket.'
                    : 'List of ticket will appear here.',
              )
            else
              AppCard(
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF9FAFB),
                    ),
                    columns: const [
                      DataColumn(label: Text('Ticket')),
                      DataColumn(label: Text('List of Ticket')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Remarks')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: _rows.map((row) {
                      final taskStatus = (row.task.status ?? '').toLowerCase();
                      final finished =
                          ['completed', 'closed'].contains(taskStatus);
                      final employeeCanEdit =
                          row.task.assignedUserId == user?.id &&
                              taskStatus == 'in_progress';
                      final canEdit = canModify &&
                          !finished &&
                          (isAdmin || employeeCanEdit);
                      final canDelete = canEdit &&
                          (isAdmin || row.activity.createdBy == user.id);

                      return DataRow(cells: [
                        DataCell(SizedBox(
                          width: 170,
                          child: Text(row.task.title,
                              overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(SizedBox(
                          width: 190,
                          child: Text(row.activity.title,
                              overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(StatusBadge(status: row.activity.status)),
                        DataCell(SizedBox(
                          width: 180,
                          child: Text(
                            row.activity.remarks ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Update',
                              onPressed: canEdit && !_saving
                                  ? () => _edit(row, isAdmin)
                                  : null,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: canDelete && !_saving
                                  ? () => _delete(row)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                              color: const Color(0xFFB91C1C),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubActivityRowData {
  const _SubActivityRowData({required this.task, required this.activity});

  final TaskItem task;
  final SubActivity activity;
}

class _SubActivityInput {
  const _SubActivityInput({
    required this.taskId,
    required this.title,
    required this.status,
    required this.remarks,
  });

  final int taskId;
  final String title;
  final String status;
  final String remarks;
}

class _SubActivityDialog extends StatefulWidget {
  const _SubActivityDialog({
    required this.tasks,
    this.activity,
    this.fixedTaskId,
    this.canEditTitle = true,
    this.canEditStatus = true,
  });

  final List<TaskItem> tasks;
  final SubActivity? activity;
  final int? fixedTaskId;
  final bool canEditTitle;
  final bool canEditStatus;

  @override
  State<_SubActivityDialog> createState() => _SubActivityDialogState();
}

class _SubActivityDialogState extends State<_SubActivityDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _remarks;
  late String _status;
  int? _taskId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.activity?.title);
    _remarks = TextEditingController(text: widget.activity?.remarks);
    _status = widget.activity?.status ?? 'pending';
    _taskId = widget.fixedTaskId ??
        (widget.tasks.isEmpty ? null : widget.tasks.first.id);
  }

  @override
  void dispose() {
    _title.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.activity == null ? 'Add List of Ticket' : 'Update List of Ticket'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.fixedTaskId == null)
                  DropdownButtonFormField<int>(
                    initialValue: _taskId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ticket',
                      prefixIcon: Icon(Icons.list_alt_outlined),
                    ),
                    items: widget.tasks
                        .map((task) => DropdownMenuItem<int>(
                              value: task.id,
                              child: Text(task.title,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _taskId = value),
                    validator: (value) =>
                        value == null ? 'Select a ticket' : null,
                  ),
                if (widget.fixedTaskId == null) const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  enabled: widget.canEditTitle,
                  minLines: widget.activity == null ? 3 : 1,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: widget.activity == null
                        ? 'Activity names (one per line or pasted table rows)'
                        : 'Activity name',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Activity name is required'
                      : null,
                ),
                if (widget.activity != null && widget.canEditStatus) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.tasks.isEmpty
              ? null
              : () {
                  if (!_key.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _SubActivityInput(
                      taskId: _taskId!,
                      title: _title.text.trim(),
                      status: _status,
                      remarks: _remarks.text.trim(),
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
