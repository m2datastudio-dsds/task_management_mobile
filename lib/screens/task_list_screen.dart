import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/task_provider.dart';
import '../utils/roles.dart';
import '../utils/status_style.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({
    super.key,
    required this.adminView,
    this.organizationId,
    this.organizationName,
  });

  final bool adminView;
  final int? organizationId;
  final String? organizationName;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  int? _bankFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant TaskListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminView != widget.adminView ||
        oldWidget.organizationId != widget.organizationId) {
      _bankFilter = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final adminView =
        widget.adminView && Roles.isAdminLike(auth.currentUser?.role);
    final bankProvider = context.read<BankProvider>();
    if (!auth.isSuperAdmin &&
        bankProvider.banks.isEmpty &&
        !bankProvider.loading) {
      await bankProvider.load();
    }
    if (!mounted) return;
    await context.read<TaskProvider>().loadTasks(
          adminView: adminView,
          userId: auth.currentUser?.id ?? 0,
          categoryId: _bankFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final auth = context.watch<AuthProvider>();
    final bankProvider = context.watch<BankProvider>();
    final adminView =
        widget.adminView && Roles.isAdminLike(auth.currentUser?.role);
    final currentUserId = auth.currentUser?.id ?? 0;
    final visibleTasks = adminView
        ? provider.tasks
        : provider.tasks
            .where((task) =>
                task.assignedUserId == currentUserId &&
                task.status?.toLowerCase() != 'closed')
            .toList();
    final scopedTasks = widget.organizationId == null
        ? visibleTasks
        : visibleTasks
            .where((task) => task.organizationId == widget.organizationId)
            .toList();
    final tasks = scopedTasks;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: adminView && !auth.isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskFormScreen()),
              ).then((_) => _load()),
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Create Ticket'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: widget.organizationName != null
                          ? '${widget.organizationName} Tickets'
                          : adminView
                              ? (auth.isSuperAdmin
                                  ? 'Ticket Monitoring'
                                  : 'Ticket Management')
                              : 'My Tickets',
                      subtitle: widget.organizationName != null
                          ? 'Only tickets from this organization'
                          : adminView
                              ? (auth.isSuperAdmin
                                  ? 'Monitor platform ticket activity'
                                  : 'Create, assign, and manage organization tickets')
                              : 'Tickets assigned to you',
                    ),
                    const SizedBox(height: 12),
                    if (!auth.isSuperAdmin) ...[
                      DropdownButtonFormField<int?>(
                        initialValue: _bankFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Bank / All',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Banks'),
                          ),
                          ...bankProvider.banks.map(
                            (bank) => DropdownMenuItem<int?>(
                              value: bank.id,
                              child: Text(bank.displayName,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _bankFilter = value);
                          _load();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (provider.loading) ...[
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 12),
                    ],
                    if (provider.error != null) ...[
                      Text(
                        provider.error!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            if (!provider.loading && tasks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.paddingOf(context).bottom + 96,
                  ),
                  child: EmptyState(
                    title: adminView
                        ? 'No managed tickets'
                        : 'No assigned tickets',
                    message: adminView
                        ? 'Create a ticket and assign it to a team member.'
                        : 'Tickets assigned to you will appear here.',
                  ),
                ),
              )
            else if (tasks.isNotEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.paddingOf(context).bottom + 96,
                  ),
                  child: _TicketTable(tasks: tasks, onChanged: _load),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketTable extends StatefulWidget {
  const _TicketTable({required this.tasks, required this.onChanged});

  final List<TaskItem> tasks;
  final Future<void> Function() onChanged;

  @override
  State<_TicketTable> createState() => _TicketTableState();
}

class _TicketTableState extends State<_TicketTable> {
  String? _statusFilter;
  _TicketSortColumn? _sortColumn;
  bool _sortAscending = true;

  static const _headerColor = Color(0xFFF3F6FA);
  static const _columnFlex = <int>[1, 2, 3, 2, 2];
  static const _columnLabels = [
    'Sl. No.',
    'Bank',
    'Location',
    'Ticket Date',
    'Status',
  ];

  Future<void> _openTicket(TaskItem task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
    );
    await widget.onChanged();
  }

  String _normalizedStatus(TaskItem task) =>
      (task.displayStatus ?? '').trim().toLowerCase();

  void _sortBy(_TicketSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<TaskItem> get _displayedTasks {
    final rows = widget.tasks
        .where((task) =>
            _statusFilter == null || _normalizedStatus(task) == _statusFilter)
        .toList();

    rows.sort((a, b) {
      int comparison;
      switch (_sortColumn) {
        case _TicketSortColumn.ticketDate:
          final aDate = a.issueDate ?? a.createdAt;
          final bDate = b.issueDate ?? b.createdAt;
          comparison = _compareNullableDates(aDate, bDate);
        case _TicketSortColumn.status:
          comparison = _normalizedStatus(a).compareTo(_normalizedStatus(b));
        case null:
          final aPending = _normalizedStatus(a) == 'pending' ? 0 : 1;
          final bPending = _normalizedStatus(b) == 'pending' ? 0 : 1;
          return aPending.compareTo(bPending);
      }
      return _sortAscending ? comparison : -comparison;
    });
    return rows;
  }

  int _compareNullableDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Widget _headerCell(int index) {
    final sortColumn = switch (index) {
      3 => _TicketSortColumn.ticketDate,
      4 => _TicketSortColumn.status,
      _ => null,
    };
    final label = Text(
      _columnLabels[index],
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
    );

    return Expanded(
      flex: _columnFlex[index],
      child: InkWell(
        onTap: sortColumn == null ? null : () => _sortBy(sortColumn),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: sortColumn == null
                ? label
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: label),
                      const SizedBox(width: 2),
                      Icon(
                        _sortColumn == sortColumn
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.unfold_more,
                        size: 16,
                        color: _sortColumn == sortColumn
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black54,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses = widget.tasks
        .map(_normalizedStatus)
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final activeFilter =
        statuses.contains(_statusFilter) ? _statusFilter : null;
    if (activeFilter != _statusFilter) _statusFilter = activeFilter;
    final displayedTasks = _displayedTasks;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: DropdownButtonFormField<String?>(
              initialValue: activeFilter,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Filter by status',
                prefixIcon: Icon(Icons.filter_list, size: 20),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...statuses.map(
                  (status) => DropdownMenuItem<String?>(
                    value: status,
                    child: Text(StatusStyle.label(status)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _statusFilter = value),
            ),
          ),
          Material(
            color: _headerColor,
            child: SizedBox(
              height: 48,
              child: Row(
                children: List.generate(_columnLabels.length, _headerCell),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Scrollbar(
              thumbVisibility: displayedTasks.length > 8,
              child: SingleChildScrollView(
                child: displayedTasks.isEmpty
                    ? const SizedBox(
                        height: 96,
                        child: Center(
                          child: Text('No tickets match this status.'),
                        ),
                      )
                    : Column(
                        children: List.generate(displayedTasks.length, (index) {
                          final task = displayedTasks[index];
                          final date = task.issueDate ?? task.createdAt;
                          final isEven = index.isEven;
                          return Material(
                            color:
                                isEven ? Colors.white : const Color(0xFFFAFBFC),
                            child: InkWell(
                              onTap: () => _openTicket(task),
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: _columnFlex[0],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text('${index + 1}',
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: _columnFlex[1],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          task.bankName ?? '-',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: _columnFlex[2],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          task.bankBranchName ?? '-',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: _columnFlex[3],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          date == null
                                              ? '-'
                                              : DateFormat('dd.MM.yy')
                                                  .format(date.toLocal()),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: _columnFlex[4],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        child: _TicketStatus(
                                          status: task.displayStatus,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TicketSortColumn { ticketDate, status }

class _TicketStatus extends StatelessWidget {
  const _TicketStatus({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = (status ?? '').toLowerCase();
    if (normalizedStatus == 'pending') {
      return _statusBox(
        backgroundColor: const Color(0xFFD32F2F),
        textColor: Colors.white,
      );
    }
    if (normalizedStatus != 'assigned') {
      return StatusBadge(status: status);
    }

    return _statusBox(
      backgroundColor: Colors.white,
      textColor: const Color(0xFFD32F2F),
      borderColor: const Color(0xFFD32F2F),
    );
  }

  Widget _statusBox({
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Text(
        StatusStyle.label(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          height: 1.1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
