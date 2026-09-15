import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../utils/app_toast.dart';
import '../utils/roles.dart';
import '../widgets/app_card.dart';

enum PurchaseOrderSection { work, expenses }

class PurchaseOrderDetailScreen extends StatefulWidget {
  const PurchaseOrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialSection = PurchaseOrderSection.work,
  });
  final int orderId;
  final PurchaseOrderSection initialSection;

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _saving = false;
  final Map<int, List<TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final row in _controllers.values) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context
          .read<ApiClient>()
          .get('/purchase-orders/${widget.orderId}');
      final data = Map<String, dynamic>.from(res['data']);
      for (final row in _controllers.values) {
        for (final c in row) {
          c.dispose();
        }
      }
      _controllers.clear();
      for (final raw in (data['items'] as List? ?? const [])) {
        final item = Map<String, dynamic>.from(raw);
        final original =
            (item['values'] as List? ?? const []).map((e) => '$e').toList();
        final completed = item['completedValues'] is List
            ? (item['completedValues'] as List).map((e) => '$e').toList()
            : const <String>[];
        _controllers[int.parse('${item['id']}')] = List.generate(
          original.length,
          (i) {
            if (i != original.length - 1) {
              return TextEditingController(text: original[i]);
            }
            final saved = i < completed.length ? completed[i].trim() : '';
            return TextEditingController(
              text:
                  saved.isNotEmpty && saved != original[i].trim() ? saved : '',
            );
          },
        );
      }
      if (mounted) setState(() => _order = data);
    } catch (e) {
      if (mounted) AppToast.error(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _items =>
      (_order?['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  bool get _completed => _order?['completedat'] != null;
  bool get _expensesCompleted => _order?['expensesCompletedat'] != null;
  bool get _canEdit =>
      !Roles.isAdminLike(context.read<AuthProvider>().currentUser?.role);

  Future<bool> _saveWork() async {
    setState(() => _saving = true);
    try {
      await context
          .read<ApiClient>()
          .put('/purchase-orders/${widget.orderId}/work', {
        'items': _items.map((item) {
          final original = (item['values'] as List? ?? const [])
              .map((value) => '$value')
              .toList();
          final current = item['completedValues'] is List
              ? (item['completedValues'] as List)
                  .map((value) => '$value')
                  .toList()
              : original;
          final controls = _controllers[int.parse('${item['id']}')]!;
          final values = List<String>.generate(original.length, (index) {
            if (index != original.length - 1) return original[index];
            final entered = controls[index].text.trim();
            return entered.isEmpty
                ? (index < current.length ? current[index] : original[index])
                : entered;
          });
          return {'id': item['id'], 'values': values};
        }).toList()
      });
      if (mounted) AppToast.success(context, 'Work quantities updated');
      await _load();
      return true;
    } catch (e) {
      if (mounted) AppToast.error(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _complete() async {
    final saved = await _saveWork();
    if (!saved) return;
    if (!mounted) return;
    try {
      await context
          .read<ApiClient>()
          .put('/purchase-orders/${widget.orderId}/complete', {});
      if (mounted) AppToast.success(context, 'Purchase order completed');
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, e);
    }
  }

  Future<void> _addExpense() async {
    final entry = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const _PoExpenseDialog());
    if (entry == null || !mounted) return;
    try {
      await context
          .read<ApiClient>()
          .post('/purchase-orders/${widget.orderId}/expenses', entry);
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, e);
    }
  }

  Future<void> _completeExpenses() async {
    try {
      await context
          .read<ApiClient>()
          .put('/purchase-orders/${widget.orderId}/expenses/complete', {});
      if (mounted) AppToast.success(context, 'Expenses completed');
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, e);
    }
  }

  Future<void> _pdf() async {
    final bytes = await _reportBytes();
    await Printing.layoutPdf(
        name: 'PO-${widget.orderId}-work-completion.pdf',
        onLayout: (_) async => bytes);
  }

  Future<Uint8List> _reportBytes() async {
    final doc = pw.Document();
    final category =
        _order?['category'] is Map ? _order!['category']['name'] : '-';
    final user = _order?['user'] is Map
        ? Map<String, dynamic>.from(_order!['user'])
        : const <String, dynamic>{};
    final employeeName = '${user['name'] ?? user['email'] ?? '-'}';
    final startedAt = DateTime.tryParse('${_order?['createdat'] ?? ''}');
    final completedAt = DateTime.tryParse('${_order?['completedat'] ?? ''}');
    final columnCount = _items.fold<int>(0, (count, item) {
      final values = item['values'] as List? ?? const [];
      return values.length > count ? values.length : count;
    });
    final headers = _columnHeaders(columnCount);
    final reportRows = _items.asMap().entries.map((entry) {
      final item = entry.value;
      final original = (item['values'] as List? ?? const [])
          .map((value) => '$value')
          .toList();
      final current = item['completedValues'] is List
          ? (item['completedValues'] as List).map((value) => '$value').toList()
          : original;
      final controls = _controllers[int.parse('${item['id']}')]!;
      final values = List<String>.generate(original.length, (index) {
        if (index != original.length - 1) return original[index];
        final entered = controls[index].text.trim();
        return entered.isEmpty
            ? (index < current.length ? current[index] : original[index])
            : entered;
      });
      return List<String>.generate(columnCount, (column) {
        if (column < values.length) return values[column];
        return '';
      });
    }).toList();
    final labelStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    final valueStyle = const pw.TextStyle(fontSize: 9);
    pw.Widget detail(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: '$label: ', style: labelStyle),
              pw.TextSpan(text: value, style: valueStyle),
            ]),
          ),
        );
    doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Aashritha Technology Pvt.Ltd',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ),
        build: (_) => [
              pw.SizedBox(height: 8),
              pw.Center(
                  child: pw.Text('$category - Work Completion Report',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 18),
              detail('Task', 'PO #${widget.orderId}'),
              detail('Branch', '${_order?['branchName'] ?? '-'}'),
              detail('Assigned employee', employeeName),
              detail('Date of commencement', _reportDate(startedAt)),
              detail('Date of work completion', _reportDate(completedAt)),
              pw.SizedBox(height: 14),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: reportRows,
                headerStyle:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                border: pw.TableBorder.all(width: .6),
                cellPadding: const pw.EdgeInsets.all(4),
              ),
              pw.SizedBox(height: 18),
              pw.Text('Work Completed:  Satisfactory / Unsatisfactory',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 30),
              pw.Row(children: [
                pw.Expanded(
                    child: pw.Text('Employee Signature: ____________________',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.SizedBox(width: 20),
                pw.Expanded(
                    child: pw.Text('Authorized Signature: __________________',
                        style: const pw.TextStyle(fontSize: 9))),
              ]),
            ]));
    return doc.save();
  }

  String _reportDate(DateTime? date) =>
      date == null ? '-' : DateFormat('dd/MM/yyyy').format(date.toLocal());

  List<String> _columnHeaders(int count) {
    if (count == 5) {
      return const ['Sl. No.', 'RC No.', 'Work', 'Unit', 'OLD QUANTITY'];
    }
    return List.generate(
      count,
      (index) => index == count - 1 ? 'OLD QUANTITY' : 'Column ${index + 1}',
    );
  }

  Widget _workTable() {
    final columnCount = _items.fold<int>(0, (count, item) {
      final values = item['values'] as List? ?? const [];
      return values.length > count ? values.length : count;
    });
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            for (final header in _columnHeaders(columnCount))
              DataColumn(label: Text(header)),
            const DataColumn(
              label: Text(
                'QUANTITY',
                style: TextStyle(
                  color: Color(0xFFD00000),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          rows: _items.asMap().entries.map((entry) {
            final item = entry.value;
            final original =
                (item['values'] as List).map((value) => '$value').toList();
            final controls = _controllers[int.parse('${item['id']}')]!;
            final quantityIndex = original.length - 1;
            return DataRow(cells: [
              for (var column = 0; column < columnCount; column++)
                DataCell(Text(
                  column < original.length ? original[column] : '',
                  style: const TextStyle(color: Colors.black),
                )),
              DataCell(quantityIndex < 0 ||
                      !RegExp(r'^\d+(\.\d+)?$')
                          .hasMatch(original[quantityIndex].trim())
                  ? const SizedBox.shrink()
                  : _newQuantityCell(
                      controls[quantityIndex],
                    )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _newQuantityCell(TextEditingController controller) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        enabled: !_completed && _canEdit,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(isDense: true),
        style: const TextStyle(
          color: Color(0xFFD00000),
          fontWeight: FontWeight.w800,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final expenses = _order!['expenses'] as List? ?? const [];
    final total = expenses.fold<double>(
        0, (sum, e) => sum + (double.tryParse('${e['amount']}') ?? 0));
    return Scaffold(
        appBar: AppBar(title: Text('PO #${widget.orderId}')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                  '${_order!['category']?['name'] ?? '-'}  •  ${_order!['branchName'] ?? '-'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, height: 1.6))),
          const SizedBox(height: 12),
          if (widget.initialSection == PurchaseOrderSection.work) ...[
            const Text('Work List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            _workTable(),
            const SizedBox(height: 12),
            if (!_completed && _canEdit)
              FilledButton.icon(
                  onPressed: _saving ? null : _saveWork,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Update Work List')),
            const SizedBox(height: 8),
            if (!_completed && _canEdit)
              FilledButton.icon(
                  onPressed: _complete,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete Quantity Work')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: _completed ? _pdf : null,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Generate Quantity Work Report')),
            const SizedBox(height: 20),
          ],
          if (widget.initialSection == PurchaseOrderSection.expenses) ...[
            Row(children: [
              const Expanded(
                  child: Text('Daily Expenses',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              Text('Total: ₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900))
            ]),
            ...expenses.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${e['category']} • ₹${e['amount']}'),
                subtitle: Text(
                    '${DateFormat('dd MMM yyyy').format(DateTime.parse('${e['expenseDate']}').toLocal())}\n${e['description']}'))),
            if (!_expensesCompleted && _canEdit)
              OutlinedButton.icon(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Daily Expense')),
            if (!_expensesCompleted && _canEdit) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: _completeExpenses,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete Expenses')),
            ],
          ],
        ]));
  }
}

class _PoExpenseDialog extends StatefulWidget {
  const _PoExpenseDialog();
  @override
  State<_PoExpenseDialog> createState() => _PoExpenseDialogState();
}

class _PoExpenseDialogState extends State<_PoExpenseDialog> {
  static const _categories = <String>[
    'Civil',
    'Carpentry',
    'Plumbing',
    'Electrical',
    'Others',
  ];

  DateTime date = DateTime.now();
  String? category;
  final description = TextEditingController();
  final amount = TextEditingController();
  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Add Daily Expense'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (picked != null) setState(() => date = picked);
                },
                icon: const Icon(Icons.event),
                label: Text(DateFormat('dd MMM yyyy').format(date))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                hint: const Text('Select category'),
                items: _categories
                    .map((value) => DropdownMenuItem<String>(
                        value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => category = value)),
            const SizedBox(height: 10),
            TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'))
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (category == null ||
                      description.text.trim().isEmpty ||
                      (double.tryParse(amount.text) ?? 0) <= 0) {
                    return;
                  }
                  Navigator.pop(context, {
                    'expenseDate': date.toIso8601String(),
                    'category': category,
                    'description': description.text.trim(),
                    'amount': double.parse(amount.text)
                  });
                },
                child: const Text('Add'))
          ]);
}
