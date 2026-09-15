import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';

import '../models/bank.dart';
import '../providers/task_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _remarks = TextEditingController();
  final _branch = TextEditingController();
  final _subActivities = TextEditingController();
  final _imagePicker = ImagePicker();
  final _priorities = const ['Normal', 'Urgent'];
  String _subActivityMode = 'normal';
  String _priority = 'Normal';
  int? _assignedUserId;
  int? _categoryId;
  DateTime? _dueDate;
  DateTime _issueDate = DateTime.now();
  XFile? _taskImage;
  Uint8List? _taskImageBytes;
  bool _saving = false;
  bool _enteringNewBranch = false;

  @override
  void initState() {
    super.initState();
    _subActivities.addListener(_onSubActivitiesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final users = context.read<UserProvider>();
      if (users.users.isEmpty && !users.loading) users.loadUsers();
      final categories = context.read<BankProvider>();
      if (categories.banks.isEmpty && !categories.loading) categories.load();
    });
  }

  @override
  void dispose() {
    _subActivities.removeListener(_onSubActivitiesChanged);
    _title.dispose();
    _description.dispose();
    _remarks.dispose();
    _branch.dispose();
    _subActivities.dispose();
    super.dispose();
  }

  void _onSubActivitiesChanged() {
    if (mounted) setState(() {});
  }

  List<_SubActivityPasteRow> _parseSubActivityRows() {
    return _subActivities.text
        .split(RegExp(r'[\r\n]+'))
        .map((line) {
          final cells = line.contains('\t')
              ? line.split('\t').map((value) => value.trim()).toList()
              : [line.trim()];
          return _SubActivityPasteRow(cells);
        })
        .where((row) => row.cells.any((cell) => cell.isNotEmpty))
        .toList();
  }

  List<Map<String, String?>> _subActivityPayload() {
    final rows = _parseSubActivityRows();
    if (_subActivityMode == 'table') {
      if (rows.isEmpty) return [];
      final columnCount = rows.fold<int>(
        1,
        (count, row) => row.cells.length > count ? row.cells.length : count,
      );
      final hasHeader = rows.length > 1;
      final columns = hasHeader
          ? _normalizeCells(rows.first.cells, columnCount)
          : List.generate(columnCount, (index) => 'Column ${index + 1}');
      final dataRows = hasHeader ? rows.skip(1).toList() : rows;

      return dataRows
          .map((row) {
            final cells = _normalizeCells(row.cells, columnCount);
            final title = cells.where((cell) => cell.isNotEmpty).join(' - ');
            return {
              'title': title,
              'remarks': jsonEncode({
                'subActivityFormat': 'table',
                'columns': columns,
                'cells': cells,
              }),
            };
          })
          .where((item) => (item['title'] ?? '').isNotEmpty)
          .toList();
    }

    return rows
        .map((row) => row.title)
        .where((value) => value.isNotEmpty)
        .map((title) => {'title': title, 'remarks': null})
        .toList();
  }

  List<String> _normalizeCells(List<String> cells, int count) {
    return List.generate(
        count, (index) => index < cells.length ? cells[index] : '');
  }

  List<String> _splitCategoryList(String? value) {
    return (value ?? '')
        .split(RegExp(r'[\r\n,;|]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Bank? _bankById(List<Bank> banks, int? id) {
    for (final bank in banks) {
      if (bank.id == id) return bank;
    }
    return null;
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'pm' : 'am';
    return '$day/$month/${value.year}, $hour:$minute $suffix';
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<DateTime?> _pickDateTime({
    required DateTime? currentValue,
    required TimeOfDay defaultTime,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentValue ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate == null || !mounted) return null;

    final initialTime = currentValue == null
        ? defaultTime
        : TimeOfDay(hour: currentValue.hour, minute: currentValue.minute);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null) return null;

    return _combineDateAndTime(pickedDate, pickedTime);
  }

  Future<void> _pickDueDate() async {
    final picked = await _pickDateTime(
      currentValue: _dueDate,
      defaultTime: const TimeOfDay(hour: 18, minute: 0),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) setState(() => _issueDate = picked);
  }

  Future<void> _pickTaskImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked != null) {
      final imageBytes = await picked.readAsBytes();
      if (mounted) {
        setState(() {
          _taskImage = picked;
          _taskImageBytes = imageBytes;
        });
      }
    }
  }

  Future<void> _pasteTaskImage() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (!mounted) return;
      if (imageBytes == null || imageBytes.isEmpty) {
        AppToast.error(context, 'No image found in the clipboard');
        return;
      }

      setState(() {
        _taskImageBytes = imageBytes;
        _taskImage = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'pasted-task-image.png',
        );
      });
      AppToast.success(context, 'Image pasted from clipboard');
    } catch (err) {
      if (mounted) AppToast.error(context, 'Unable to paste clipboard image');
    }
  }

  void _clearTaskImage() {
    setState(() {
      _taskImage = null;
      _taskImageBytes = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final selectedBank =
        _bankById(context.read<BankProvider>().banks, _categoryId);
    final payload = <String, dynamic>{
      'title': '${selectedBank?.name ?? 'Ticket'} - ${_branch.text.trim()}',
      'description': _description.text.trim(),
      'remarks': _remarks.text.trim(),
      'issueDate': _issueDate.toIso8601String(),
      'priority': 'normal',
      'categoryId': _categoryId,
      'categoryListName': _branch.text.trim(),
      if (_assignedUserId != null) 'assignedToId': _assignedUserId,
    };

    final taskProvider = context.read<TaskProvider>();

    try {
      final imageBytes = _taskImage == null
          ? null
          : (_taskImageBytes ?? await _taskImage!.readAsBytes());
      await taskProvider.createTask(
        payload,
        imageBytes: imageBytes,
        imageName: _taskImage?.name,
      );
      await context.read<BankProvider>().load(silent: true);
      if (mounted) {
        AppToast.success(context, 'Ticket created successfully');
        Navigator.pop(context);
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UserProvider>();
    final categoryProvider = context.watch<BankProvider>();
    final selectedBank = _bankById(categoryProvider.banks, _categoryId);
    final branchOptions = _splitCategoryList(selectedBank?.branchName);
    final assignableUsers = usersProvider.users.where((user) {
      final role = user.role.toLowerCase();
      return !user.isDeleted && role != 'admin' && role != 'super_admin';
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Ticket')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_saving ? 'Confirming...' : 'Confirm'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.paddingOf(context).bottom + 92),
          children: [
            _SectionCard(
              title: 'Bank and Branch',
              icon: Icons.category_outlined,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Bank',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                  ),
                  items: categoryProvider.banks
                      .map((bank) => DropdownMenuItem<int>(
                            value: bank.id,
                            child: Text(bank.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Please select a bank' : null,
                  onChanged: (value) {
                    setState(() {
                      _categoryId = value;
                      final bank = _bankById(categoryProvider.banks, value);
                      final branches = _splitCategoryList(bank?.branchName);
                      _branch.text = branches.length == 1 ? branches.first : '';
                      _enteringNewBranch = branches.isEmpty;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (_enteringNewBranch || branchOptions.isEmpty)
                  TextFormField(
                    controller: _branch,
                    enabled: _categoryId != null,
                    decoration: InputDecoration(
                      labelText: 'Branch',
                      hintText: 'Type a new branch',
                      prefixIcon: const Icon(Icons.account_tree_outlined),
                      suffixIcon: branchOptions.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Choose saved branch',
                              onPressed: () => setState(() {
                                _enteringNewBranch = false;
                                _branch.clear();
                              }),
                              icon: const Icon(Icons.arrow_drop_down),
                            ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter a branch'
                        : null,
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: branchOptions.contains(_branch.text)
                        ? _branch.text
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Branch',
                      prefixIcon: const Icon(Icons.account_tree_outlined),
                    ),
                    items: [
                      ...branchOptions.map((branch) => DropdownMenuItem(
                            value: branch,
                            child:
                                Text(branch, overflow: TextOverflow.ellipsis),
                          )),
                      const DropdownMenuItem(
                        value: '__add_new_branch__',
                        child: Text('+ Add new branch'),
                      ),
                    ],
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please select a branch'
                        : null,
                    onChanged: (value) => setState(() {
                      if (value == '__add_new_branch__') {
                        _branch.clear();
                        _enteringNewBranch = true;
                      } else {
                        _branch.text = value ?? '';
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Issue Details',
              icon: Icons.edit_note_outlined,
              children: [
                _ActionTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Issue Date',
                  value: _formatDateTime(_issueDate).split(',').first,
                  onTap: _pickIssueDate,
                ),
                const SizedBox(height: 14),
                _ImagePickerTile(
                  descriptionController: _description,
                  fileName: _taskImage?.name,
                  imageBytes: _taskImageBytes,
                  imageUrl: null,
                  onPick: _pickTaskImage,
                  onPaste: _pasteTaskImage,
                  onClear: _taskImage == null ? null : _clearTaskImage,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Assignment',
              icon: Icons.person_add_alt_1_outlined,
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: _assignedUserId,
                  decoration: InputDecoration(
                    labelText: 'Assign To',
                    prefixIcon: const Icon(Icons.group_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Select a user'),
                    ),
                    ...assignableUsers.map(
                      (user) => DropdownMenuItem<int?>(
                        value: user.id,
                        child: Text(user.name.isEmpty ? user.email : user.name),
                      ),
                    ),
                  ],
                  validator: (value) =>
                      value == null ? 'Please select a user' : null,
                  onChanged: (value) => setState(() => _assignedUserId = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Remarks',
              icon: Icons.comment_outlined,
              children: [
                TextFormField(
                  controller: _remarks,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Enter remarks (optional)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.comment_outlined),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubActivityPasteRow {
  const _SubActivityPasteRow(this.cells);

  final List<String> cells;

  String get title => cells.join(' - ').trim();
}

class _SubActivityPastePreview extends StatelessWidget {
  const _SubActivityPastePreview({required this.rows, required this.mode});

  final List<_SubActivityPasteRow> rows;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final hasTableData = mode == 'table';
    final columnCount = rows.fold<int>(
      1,
      (count, row) => row.cells.length > count ? row.cells.length : count,
    );
    final dataRows = hasTableData && rows.length > 1 ? rows.skip(1) : rows;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
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
                hasTableData
                    ? '${dataRows.length} table row${dataRows.length == 1 ? '' : 's'} ready'
                    : '${rows.length} item${rows.length == 1 ? '' : 's'} ready',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasTableData)
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
                rows: dataRows
                    .map(
                      (row) => DataRow(
                        cells: List.generate(
                          columnCount,
                          (index) => DataCell(
                            SizedBox(
                              width: 150,
                              child: Text(
                                index < row.cells.length
                                    ? row.cells[index]
                                    : '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
          else
            Column(
              children: rows
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 17, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              row.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (!hasTableData && rows.length > 5)
            Text(
              '+${rows.length - 5} more',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.descriptionController,
    required this.fileName,
    required this.imageBytes,
    required this.imageUrl,
    required this.onPick,
    required this.onPaste,
    required this.onClear,
  });

  final TextEditingController descriptionController;
  final String? fileName;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback onPick;
  final VoidCallback onPaste;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = fileName != null && fileName!.trim().isNotEmpty;
    final hasSavedImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final hasImage = hasLocalImage || hasSavedImage;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: descriptionController,
            minLines: 5,
            maxLines: 9,
            decoration: const InputDecoration(
              labelText: 'Issue Description',
              hintText: 'Type, paste text, or add an image',
              alignLabelWithHint: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty && !hasImage
                    ? 'Add description text or an image'
                    : null,
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.image_outlined, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issue Image (Optional)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocalImage
                          ? fileName!
                          : hasSavedImage
                              ? 'Saved ticket image'
                              : 'No image selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              if (hasImage)
                IconButton(
                  tooltip: 'Remove image',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (imageBytes != null && imageBytes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                imageBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ] else if (hasSavedImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  color: const Color(0xFFF3F4F6),
                  child: const Text('Unable to load saved image'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste_outlined),
                label: const Text('Paste Image'),
              ),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(hasImage ? 'Change Image' : 'Upload Image'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  Color get _color {
    switch (label) {
      case 'Normal':
        return AppTheme.primary;
      case 'Urgent':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: _color.withValues(alpha: 0.14),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _color : AppTheme.border),
      labelStyle: TextStyle(
        color: selected ? _color : AppTheme.text,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.task_alt_outlined, color: AppTheme.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Ticket',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text(
                  'Plan, assign, and prioritize work.',
                  style: TextStyle(
                      color: Color(0xFFEFF6FF), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 22),
                const SizedBox(width: 9),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}
