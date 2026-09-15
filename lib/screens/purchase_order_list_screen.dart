import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../utils/roles.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import 'purchase_order_form_screen.dart';
import 'purchase_order_detail_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = const [];
  int? _bankFilter;
  bool _dateAscending = true;

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
      final response = await context.read<ApiClient>().get('/purchase-orders');
      final raw = response is Map ? response['data'] : null;
      final orders = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _orders = orders);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PurchaseOrderFormScreen()),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        Roles.isAdminLike(context.watch<AuthProvider>().currentUser?.role);
    final banks = <int, String>{};
    for (final order in _orders) {
      final category = order['category'];
      final id = int.tryParse('${category is Map ? category['id'] : ''}');
      if (id != null) banks[id] = '${category['name'] ?? '-'}';
    }
    final visibleOrders = (_bankFilter == null
        ? List<Map<String, dynamic>>.from(_orders)
        : _orders.where((order) {
            final category = order['category'];
            return int.tryParse('${category is Map ? category['id'] : ''}') ==
                _bankFilter;
          }).toList())
      ..sort((first, second) {
        final firstDate = DateTime.tryParse('${first['createdat'] ?? ''}');
        final secondDate = DateTime.tryParse('${second['createdat'] ?? ''}');
        if (firstDate == null && secondDate == null) return 0;
        if (firstDate == null) return 1;
        if (secondDate == null) return -1;
        final comparison = firstDate.compareTo(secondDate);
        return _dateAscending ? comparison : -comparison;
      });
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('Create PO'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 96,
          ),
          children: [
            SectionHeader(
              title: 'Purchase Orders',
              subtitle: isAdmin
                  ? 'View purchase orders or create a new one'
                  : 'View assigned purchase orders and update completed work',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 260,
                child: DropdownButtonFormField<int?>(
                  initialValue: _bankFilter,
                  decoration: const InputDecoration(
                    labelText: 'Select Bank',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Banks'),
                    ),
                    ...banks.entries.map((entry) => DropdownMenuItem<int?>(
                          value: entry.key,
                          child: Text(entry.value),
                        )),
                  ],
                  onChanged: (value) => setState(() => _bankFilter = value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            if (!_loading && visibleOrders.isEmpty)
              SizedBox(
                height: 360,
                child: EmptyState(
                  title: 'No purchase orders',
                  message: isAdmin
                      ? 'Tap Create PO to add the first purchase order.'
                      : 'Purchase orders assigned to you will appear here.',
                  icon: Icons.shopping_cart_outlined,
                ),
              )
            else if (!_loading)
              _ordersTable(visibleOrders),
          ],
        ),
      ),
    );
  }

  Widget _ordersTable(List<Map<String, dynamic>> orders) {
    final isAdmin = Roles.isAdminLike(
      context.read<AuthProvider>().currentUser?.role,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(0.45),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.0),
                3: FlexColumnWidth(1.35),
                4: FlexColumnWidth(1.15),
              },
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFE5E7EB)),
                verticalInside: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF3F6FA)),
                  children: [
                    const _CompactTableCell('No.', header: true),
                    const _CompactTableCell('Bank / Branch', header: true),
                    _DateSortHeader(
                      ascending: _dateAscending,
                      compact: true,
                      onPressed: _toggleDateSort,
                    ),
                    const _CompactTableCell('Updates', header: true),
                    const _CompactTableCell('Total', header: true),
                  ],
                ),
                ...orders.asMap().entries.map((entry) {
                  final order = entry.value;
                  final category = order['category'] is Map
                      ? Map<String, dynamic>.from(order['category'])
                      : const <String, dynamic>{};
                  final createdAt =
                      DateTime.tryParse('${order['createdat'] ?? ''}');
                  final total =
                      double.tryParse('${order['totalExpense'] ?? 0}') ?? 0;
                  final orderId = int.parse('${order['id']}');
                  return TableRow(
                    decoration: BoxDecoration(
                      color: entry.key.isEven
                          ? Colors.white
                          : const Color(0xFFFAFBFC),
                    ),
                    children: [
                      _CompactTableCell('${entry.key + 1}'),
                      _CompactTableCell(
                        '${category['name'] ?? '-'}\n${order['branchName'] ?? '-'}',
                      ),
                      _CompactTableCell(
                        createdAt == null
                            ? '-'
                            : DateFormat('dd.MM.yy')
                                .format(createdAt.toLocal()),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: Column(
                          children: [
                            OutlinedButton(
                              onPressed: () => _openOrder(
                                  orderId, PurchaseOrderSection.work),
                              style: _actionButtonStyle(compact: true),
                              child: Text(isAdmin ? 'View Work' : 'Quantity',
                                  style: const TextStyle(fontSize: 10)),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton(
                              onPressed: () => _openOrder(
                                  orderId, PurchaseOrderSection.expenses),
                              style: _actionButtonStyle(compact: true),
                              child: Text(isAdmin ? 'View Expense' : 'Expense',
                                  style: const TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                      ),
                      _CompactTableCell(
                        NumberFormat.compactCurrency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 1,
                        ).format(total),
                        alignEnd: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Sl. No.')),
                const DataColumn(label: Text('Bank')),
                const DataColumn(label: Text('Branch')),
                DataColumn(
                    label: _DateSortHeader(
                  ascending: _dateAscending,
                  onPressed: _toggleDateSort,
                )),
                const DataColumn(label: Text('Update Quantity')),
                const DataColumn(label: Text('Update Expense')),
                const DataColumn(label: Text('Total Expense')),
              ],
              rows: orders.asMap().entries.map((entry) {
                final order = entry.value;
                final category = order['category'] is Map
                    ? Map<String, dynamic>.from(order['category'])
                    : const <String, dynamic>{};
                final createdAt =
                    DateTime.tryParse('${order['createdat'] ?? ''}');
                final total =
                    double.tryParse('${order['totalExpense'] ?? 0}') ?? 0;
                final orderId = int.parse('${order['id']}');
                return DataRow(cells: [
                  DataCell(Text('${entry.key + 1}')),
                  DataCell(Text('${category['name'] ?? '-'}')),
                  DataCell(Text('${order['branchName'] ?? '-'}')),
                  DataCell(Text(createdAt == null
                      ? '-'
                      : DateFormat('dd.MM.yyyy').format(createdAt.toLocal()))),
                  DataCell(OutlinedButton(
                    onPressed: () =>
                        _openOrder(orderId, PurchaseOrderSection.work),
                    style: _actionButtonStyle(),
                    child:
                        Text(isAdmin ? 'View Work List' : 'Update Work List'),
                  )),
                  DataCell(OutlinedButton(
                    onPressed: () =>
                        _openOrder(orderId, PurchaseOrderSection.expenses),
                    style: _actionButtonStyle(),
                    child: Text(isAdmin ? 'View Expense' : 'Update Expense'),
                  )),
                  DataCell(Text(NumberFormat.currency(
                    locale: 'en_IN',
                    symbol: '₹',
                    decimalDigits: 2,
                  ).format(total))),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openOrder(int orderId, PurchaseOrderSection section) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderDetailScreen(
          orderId: orderId,
          initialSection: section,
        ),
      ),
    );
    await _load();
  }

  void _toggleDateSort() {
    setState(() => _dateAscending = !_dateAscending);
  }

  ButtonStyle _actionButtonStyle({bool compact = false}) {
    return OutlinedButton.styleFrom(
      backgroundColor: const Color(0xFFE0F2FE),
      foregroundColor: const Color(0xFF0369A1),
      minimumSize: compact ? const Size(double.infinity, 30) : null,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
          : null,
      tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      visualDensity: compact ? VisualDensity.compact : null,
      side: const BorderSide(color: Color(0xFF7DD3FC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}

class _DateSortHeader extends StatelessWidget {
  const _DateSortHeader({
    required this.ascending,
    required this.onPressed,
    this.compact = false,
  });

  final bool ascending;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 0,
          vertical: compact ? 10 : 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PO Date',
              style: compact
                  ? const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)
                  : null,
            ),
            const SizedBox(width: 2),
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: compact ? 13 : 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactTableCell extends StatelessWidget {
  const _CompactTableCell(this.value,
      {this.header = false, this.alignEnd = false});

  final String value;
  final bool header;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        value,
        textAlign: alignEnd ? TextAlign.end : TextAlign.left,
        style: TextStyle(
          fontSize: header ? 10 : 9,
          fontWeight: header ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}
