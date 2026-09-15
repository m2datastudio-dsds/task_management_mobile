import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/roles.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<ExpenseProvider>().load(status: _statusFilter);
  }

  Future<void> _review(Expense expense, String status) async {
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewExpenseDialog(status: status),
    );
    if (remarks == null || !mounted) return;

    try {
      await context.read<ExpenseProvider>().review(
            id: expense.id,
            status: status,
            adminRemarks: remarks,
          );
      if (mounted) AppToast.success(context, 'Expense $status successfully');
      await _load();
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin =
        Roles.isAdminLike(auth.currentUser?.role) && !auth.isSuperAdmin;
    return Scaffold(
      backgroundColor: Colors.transparent,
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
              title: 'Expenses',
              subtitle: isAdmin
                  ? 'Review employee expense submissions'
                  : 'Submit and track your expense approvals',
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _statusFilter == null,
                    onTap: () {
                      setState(() => _statusFilter = null);
                      _load();
                    },
                  ),
                  for (final status in ['pending', 'approved', 'rejected'])
                    _FilterChip(
                      label: status,
                      selected: _statusFilter == status,
                      onTap: () {
                        setState(() => _statusFilter = status);
                        _load();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (provider.loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            if (provider.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh expenses',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!provider.loading &&
                provider.error == null &&
                provider.expenses.isEmpty)
              EmptyState(
                title: 'No expenses found',
                message: isAdmin
                    ? 'Employee expense requests will appear here.'
                    : 'Daily expenses added to purchase orders will appear here.',
              )
            else
              _ExpenseDataGrid(
                expenses: provider.expenses,
                isAdmin: isAdmin,
                onReview: _review,
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDataGrid extends StatelessWidget {
  const _ExpenseDataGrid({
    required this.expenses,
    required this.isAdmin,
    required this.onReview,
  });

  final List<Expense> expenses;
  final bool isAdmin;
  final Future<void> Function(Expense expense, String status) onReview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
          columns: [
            const DataColumn(label: Text('Bank')),
            const DataColumn(label: Text('Branch')),
            const DataColumn(label: Text('Category')),
            const DataColumn(label: Text('Amount'), numeric: true),
            const DataColumn(label: Text('Status')),
            if (isAdmin) const DataColumn(label: Text('Action')),
          ],
          rows: expenses.map((expense) {
            final amount = NumberFormat.currency(
              locale: 'en_IN',
              symbol: 'Rs. ',
            ).format(expense.amount);
            return DataRow(cells: [
              DataCell(Text(expense.bankNames)),
              DataCell(Text(expense.branchNames)),
              DataCell(Text(expense.category ?? '-')),
              DataCell(Text(amount)),
              DataCell(StatusBadge(status: expense.status)),
              if (isAdmin)
                DataCell(
                  expense.status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Approve',
                              onPressed: () => onReview(expense, 'approved'),
                              icon: const Icon(Icons.check_circle_outline,
                                  color: Color(0xFF15803D)),
                            ),
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () => onReview(expense, 'rejected'),
                              icon: const Icon(Icons.cancel_outlined,
                                  color: Color(0xFFB91C1C)),
                            ),
                          ],
                        )
                      : const Text('Reviewed'),
                ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// Retained for the detailed card presentation if it is needed on compact views.
// ignore: unused_element
class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.isAdmin,
    required this.onApprove,
    required this.onReject,
  });

  final Expense expense;
  final bool isAdmin;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
    ).format(expense.amount);
    final employee = expense.userName?.isNotEmpty == true
        ? expense.userName!
        : expense.userEmail ?? 'Employee';
    final remarks = expense.adminRemarks?.isNotEmpty == true
        ? expense.adminRemarks!
        : expense.description;
    final tableDescription = _ExpenseDescriptionTable.tryParse(remarks);

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
                Expanded(
                  child: Text(
                    expense.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                StatusBadge(status: expense.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.currency_rupee_outlined,
                  label: amount,
                ),
                _InfoPill(
                  icon: Icons.event_outlined,
                  label: expense.expenseDate == null
                      ? 'No date'
                      : DateFormat('dd MMM yyyy').format(expense.expenseDate!),
                ),
                if (expense.category?.isNotEmpty == true)
                  _InfoPill(
                    icon: Icons.category_outlined,
                    label: expense.category!,
                  ),
                if (isAdmin)
                  _InfoPill(
                    icon: Icons.person_outline,
                    label: employee,
                  ),
              ],
            ),
            if (expense.tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.task_alt_outlined,
                      size: 17, color: Colors.grey[700]),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      expense.tasks.map((task) => task.title).join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
            if (remarks?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              if (tableDescription != null)
                _ExpenseDescriptionTableView(table: tableDescription)
              else
                Text(
                  remarks!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
            ],
            if (isAdmin) ...[
              const SizedBox(height: 12),
              expense.status == 'pending'
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Approve'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Reviewed',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpenseDescriptionTable {
  const _ExpenseDescriptionTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  static _ExpenseDescriptionTable? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map ||
          decoded['expenseDescriptionFormat'] != 'table' ||
          decoded['columns'] is! List ||
          decoded['rows'] is! List) {
        return null;
      }
      final columns = (decoded['columns'] as List)
          .map((item) => item?.toString() ?? '')
          .toList();
      final rows = (decoded['rows'] as List)
          .whereType<List>()
          .map((row) => row.map((item) => item?.toString() ?? '').toList())
          .toList();
      if (columns.isEmpty || rows.isEmpty) return null;
      return _ExpenseDescriptionTable(columns: columns, rows: rows);
    } catch (_) {
      return null;
    }
  }
}

class _ExpenseDescriptionTableView extends StatelessWidget {
  const _ExpenseDescriptionTableView({required this.table});

  final _ExpenseDescriptionTable table;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 32,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          columns: table.columns
              .map((column) => DataColumn(label: Text(column)))
              .toList(),
          rows: table.rows.take(5).map((row) {
            return DataRow(
              cells: List.generate(table.columns.length, (index) {
                return DataCell(
                  SizedBox(
                    width: 110,
                    child: Text(
                      index < row.length ? row[index] : '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewExpenseDialog extends StatefulWidget {
  const _ReviewExpenseDialog({required this.status});

  final String status;

  @override
  State<_ReviewExpenseDialog> createState() => _ReviewExpenseDialogState();
}

class _ReviewExpenseDialogState extends State<_ReviewExpenseDialog> {
  final _remarks = TextEditingController();

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approving = widget.status == 'approved';
    return AlertDialog(
      title: Text(approving ? 'Approve Expense' : 'Reject Expense'),
      content: TextField(
        controller: _remarks,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Admin remarks',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _remarks.text.trim()),
          icon: Icon(
              approving ? Icons.check_circle_outline : Icons.cancel_outlined),
          label: Text(approving ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? AppTheme.primaryDark : const Color(0xFF4B5563),
        ),
        selectedColor: const Color(0xFFE8EEFF),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFFC7D2FE) : AppTheme.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
