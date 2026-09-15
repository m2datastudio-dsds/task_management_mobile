import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/task_provider.dart';
import '../utils/app_toast.dart';
import '../utils/roles.dart';
import '../utils/status_style.dart';

class TicketViewScreen extends StatefulWidget {
  const TicketViewScreen({super.key, required this.task});
  final TaskItem task;
  @override
  State<TicketViewScreen> createState() => _TicketViewScreenState();
}

class _TicketViewScreenState extends State<TicketViewScreen> {
  late final TextEditingController _location =
      TextEditingController(text: widget.task.bankBranchName);
  late final TextEditingController _description =
      TextEditingController(text: widget.task.description);
  late final TextEditingController _remarks =
      TextEditingController(text: widget.task.remarks);
  late DateTime _issueDate =
      widget.task.issueDate ?? widget.task.createdAt ?? DateTime.now();
  late int? _bankId = widget.task.bankId;
  String? _status;
  late String _workflowStatus = (widget.task.status ?? '').toLowerCase();
  bool _saving = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BankProvider>();
      if (provider.banks.isEmpty && !provider.loading) provider.load();
    });
  }

  @override
  void dispose() {
    _location.dispose();
    _description.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
        context: context,
        initialDate: _issueDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 1095)));
    if (value != null && mounted) setState(() => _issueDate = value);
  }

  Future<void> _save(bool isAdmin) async {
    setState(() => _saving = true);
    try {
      await context.read<TaskProvider>().updateTicket(widget.task.id, {
        'remarks': _remarks.text.trim(),
        if (_status != null) 'statusName': _status,
        if (isAdmin) ...{
          'categoryId': _bankId,
          'branchName': _location.text.trim(),
          'description': _description.text.trim(),
          'issueDate': _issueDate.toIso8601String(),
        },
      });
      if (!mounted) return;
      AppToast.success(context, 'Ticket updated successfully');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeWorkflowStatus(String status) async {
    setState(() => _saving = true);
    try {
      await context
          .read<TaskProvider>()
          .changeStatus(taskId: widget.task.id, statusName: status);
      if (!mounted) return;
      setState(() => _workflowStatus = status);
      AppToast.success(
          context, 'Ticket status changed to ${status.replaceAll('_', ' ')}');
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendQuote() async {
    final formKey = GlobalKey<FormState>();
    final description = TextEditingController();
    final items = TextEditingController();
    final quantity = TextEditingController();
    final amount = TextEditingController();
    final remarks = TextEditingController();
    XFile? attachment;

    final submit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Quote'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Quote description'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: items,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Required items/services'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    validator: (value) {
                      final number = int.tryParse((value ?? '').trim());
                      return number == null || number <= 0
                          ? 'Enter a positive whole number'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (value) {
                      final number = double.tryParse((value ?? '').trim());
                      return number == null || number < 0
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarks,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final file = await _imagePicker.pickImage(
                            source: ImageSource.gallery);
                        if (file != null) {
                          setDialogState(() => attachment = file);
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(attachment == null
                          ? 'Attachment (optional)'
                          : attachment!.name),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Send Quote'),
            ),
          ],
        ),
      ),
    );

    if (submit == true && mounted) {
      setState(() => _saving = true);
      try {
        final Uint8List? bytes =
            attachment == null ? null : await attachment!.readAsBytes();
        if (!mounted) return;
        await context.read<TaskProvider>().sendQuote(
              taskId: widget.task.id,
              fields: {
                'description': description.text.trim(),
                'requiredItems': items.text.trim(),
                'quantity': quantity.text.trim(),
                'amount': amount.text.trim(),
                'remarks': remarks.text.trim(),
              },
              attachmentBytes: bytes,
              attachmentName: attachment?.name,
            );
        if (mounted) {
          setState(() => _workflowStatus = 'quote_sent');
          AppToast.success(context, 'Quote sent for admin verification');
        }
      } catch (error) {
        if (mounted) AppToast.error(context, error);
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    description.dispose();
    items.dispose();
    quantity.dispose();
    amount.dispose();
    remarks.dispose();
  }

  static String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required' : null;

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        Roles.isAdminLike(context.watch<AuthProvider>().currentUser?.role);
    final currentUser = context.watch<AuthProvider>().currentUser;
    final canWork = !isAdmin && widget.task.assignedUserId == currentUser?.id;
    final banks = context.watch<BankProvider>().banks;
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
            color: const Color(0xFFEAF3FC),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 14, runSpacing: 14, children: [
                      SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<int>(
                            initialValue: banks.any((b) => b.id == _bankId)
                                ? _bankId
                                : null,
                            decoration:
                                const InputDecoration(labelText: 'Bank Name'),
                            items: banks
                                .map((b) => DropdownMenuItem(
                                    value: b.id, child: Text(b.displayName)))
                                .toList(),
                            onChanged: isAdmin
                                ? (value) => setState(() => _bankId = value)
                                : null,
                          )),
                      SizedBox(
                          width: 300,
                          child: TextFormField(
                              controller: _location,
                              readOnly: !isAdmin,
                              decoration: const InputDecoration(
                                  labelText: 'Location'))),
                    ]),
                    const SizedBox(height: 14),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 180,
                          child: InkWell(
                              onTap: isAdmin ? _pickDate : null,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                    labelText: 'Issue Date'),
                                child: Text(DateFormat('dd.MM.yyyy')
                                    .format(_issueDate)),
                              )),
                        )),
                    const SizedBox(height: 14),
                    Container(
                        color: isAdmin ? Colors.white : const Color(0xFFE0E0E0),
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          TextFormField(
                              controller: _description,
                              readOnly: !isAdmin,
                              minLines: 5,
                              maxLines: 10,
                              decoration: const InputDecoration(
                                  labelText: 'Issue Description',
                                  border: InputBorder.none)),
                          if (widget.task.imageUrl?.isNotEmpty == true)
                            Image.network(widget.task.imageUrl!,
                                height: 150, fit: BoxFit.contain),
                        ])),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: _remarks,
                        minLines: 4,
                        maxLines: 8,
                        decoration:
                            const InputDecoration(labelText: 'Remarks')),
                    const SizedBox(height: 20),
                    if (canWork) ...[
                      Text(
                        'Status: ${StatusStyle.label(_workflowStatus == 'assigned' ? widget.task.displayStatus : _workflowStatus).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (['assigned', 'on_hold'].contains(_workflowStatus))
                        ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _changeWorkflowStatus('in_progress'),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Work'),
                        ),
                      if (_workflowStatus == 'in_progress')
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          ElevatedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _changeWorkflowStatus('completed'),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Complete'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _sendQuote,
                            icon: const Icon(Icons.request_quote_outlined),
                            label: const Text('Send Quote'),
                          ),
                        ]),
                      const SizedBox(height: 20),
                    ],
                    if (isAdmin) ...[
                      SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'quote_sent', label: Text('Quote Sent')),
                            ButtonSegment(
                                value: 'issue_completed',
                                label: Text('Issue Completed')),
                            ButtonSegment(
                                value: 'not_required',
                                label: Text('Not Required')),
                          ],
                          selected: _status == null ? <String>{} : {_status!},
                          emptySelectionAllowed: true,
                          onSelectionChanged: (value) => setState(() =>
                              _status = value.isEmpty ? null : value.first)),
                      const SizedBox(height: 16),
                      Center(
                          child: SizedBox(
                              width: 300,
                              child: ElevatedButton(
                                onPressed:
                                    _saving ? null : () => _save(isAdmin),
                                child: Text(_saving ? 'Saving...' : 'Confirm'),
                              ))),
                    ],
                  ]),
            )),
      ]),
    );
  }
}
