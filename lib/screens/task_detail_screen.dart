import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/roles.dart';
import '../widgets/app_card.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  final TaskItem task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _comment = TextEditingController();
  final _editComment = TextEditingController();
  final _imagePicker = ImagePicker();

  late String _status;
  DateTime? _pickedUpAt;
  int? _assignedUserId;
  String? _assignedUserLabel;
  bool _patching = false;
  bool _loadingComments = false;
  bool _uploadingImage = false;
  bool _savingComment = false;
  int? _editingCommentId;
  List<TaskComment> _comments = [];
  String? _taskImageUrl;

  TaskItem get task => widget.task;

  @override
  void initState() {
    super.initState();
    _status = (task.status ?? '').toLowerCase();
    _pickedUpAt = task.pickedUpAt;
    _assignedUserId = task.assignedUserId;
    _assignedUserLabel = _readAssignedUserName();
    _taskImageUrl = task.imageUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) => _acknowledgeOnOpen());
  }

  Future<void> _acknowledgeOnOpen() async {
    if (!mounted || _status != 'assigned') return;
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || _assignedUserId != currentUser.id) return;
    await _changeStatus('acknowledgement', silent: true);
  }

  @override
  void dispose() {
    _comment.dispose();
    _editComment.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await context.read<TaskProvider>().loadComments(task.id);
      if (mounted) setState(() => _comments = comments);
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _addComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) {
      AppToast.error(context, 'Please enter a comment');
      return;
    }

    setState(() => _savingComment = true);
    try {
      await context
          .read<TaskProvider>()
          .addComment(taskId: task.id, comments: text);
      _comment.clear();
      await _loadComments();
      if (mounted) AppToast.success(context, 'Comment added successfully');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _savingComment = false);
    }
  }

  Future<void> _saveEditedComment(int commentId) async {
    final text = _editComment.text.trim();
    if (text.isEmpty) return;

    setState(() => _savingComment = true);
    try {
      await context
          .read<TaskProvider>()
          .editComment(commentId: commentId, comments: text);
      _editingCommentId = null;
      _editComment.clear();
      await _loadComments();
      if (mounted) AppToast.success(context, 'Comment updated successfully');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _savingComment = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final taskProvider = context.read<TaskProvider>();
    final confirmed = await _confirm(
      title: 'Delete Comment',
      message: 'Are you sure you want to delete this comment?',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _savingComment = true);
    try {
      await taskProvider.deleteComment(commentId);
      await _loadComments();
      if (mounted) AppToast.success(context, 'Comment deleted successfully');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _savingComment = false);
    }
  }

  Future<void> _changeStatus(String nextStatus, {bool silent = false}) async {
    setState(() => _patching = true);
    try {
      final auth = context.read<AuthProvider>();
      final taskProvider = context.read<TaskProvider>();
      final currentUser = auth.currentUser;
      final isAdmin = Roles.isAdminLike(currentUser?.role);

      if (!isAdmin && currentUser != null) {
        await taskProvider.loadTasks(
          adminView: false,
          userId: currentUser.id,
          silent: true,
        );
        final freshTask = taskProvider.tasks
            .where((item) => item.id == task.id)
            .cast<TaskItem?>()
            .firstWhere((item) => item != null, orElse: () => null);

        if (freshTask == null || freshTask.assignedUserId != currentUser.id) {
          if (!mounted) return;
          setState(() => _assignedUserId = freshTask?.assignedUserId);
          AppToast.error(
            context,
            'This ticket was reassigned. You can no longer work on it.',
          );
          Navigator.pop(context, true);
          return;
        }

        setState(() {
          _assignedUserId = freshTask.assignedUserId;
          _assignedUserLabel = _readAssignedUserNameFrom(freshTask);
          _status = (freshTask.status ?? _status).toLowerCase();
          _pickedUpAt = freshTask.pickedUpAt;
        });
      }

      await taskProvider.changeStatus(taskId: task.id, statusName: nextStatus);
      if (!mounted) return;
      setState(() {
        _status = nextStatus;
        if (nextStatus == 'in_progress') {
          _pickedUpAt ??= DateTime.now();
        }
      });
      if (!silent) {
        AppToast.success(
          context,
          'Status changed to ${nextStatus.replaceAll('_', ' ')}',
        );
      }
    } catch (err) {
      if (mounted) {
        final message = err.toString();
        if (message.toLowerCase().contains('no longer assigned')) {
          setState(() => _assignedUserId = null);
        }
        AppToast.error(context, message);
      }
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  Future<void> _uploadTaskImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    await _uploadTaskImageBytes(await picked.readAsBytes(), picked.name);
  }

  Future<void> _sendQuote() async {
    final formKey = GlobalKey<FormState>();
    final description = TextEditingController();
    final items = TextEditingController();
    final quantity = TextEditingController();
    final amount = TextEditingController();
    final remarks = TextEditingController();
    XFile? attachment;

    final submitted = await showDialog<bool>(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: description,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Quote description'),
                      validator: _requiredField,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: items,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Required items/services'),
                      validator: _requiredField,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        return parsed == null || parsed <= 0
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
                        final parsed = double.tryParse((value ?? '').trim());
                        return parsed == null || parsed < 0
                            ? 'Enter a valid amount'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: remarks,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Remarks'),
                      validator: _requiredField,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                            maxWidth: 1800,
                          );
                          if (picked != null) {
                            setDialogState(() => attachment = picked);
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(attachment == null
                            ? 'Add attachment (optional)'
                            : attachment!.name),
                      ),
                    ),
                  ],
                ),
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

    if (submitted == true && mounted) {
      setState(() => _patching = true);
      try {
        await context.read<TaskProvider>().sendQuote(
              taskId: task.id,
              fields: {
                'description': description.text.trim(),
                'requiredItems': items.text.trim(),
                'quantity': quantity.text.trim(),
                'amount': amount.text.trim(),
                'remarks': remarks.text.trim(),
              },
              attachmentBytes:
                  attachment == null ? null : await attachment!.readAsBytes(),
              attachmentName: attachment?.name,
            );
        if (mounted) {
          setState(() => _status = 'quote_sent');
          AppToast.success(context, 'Quote sent for admin verification');
        }
      } catch (err) {
        if (mounted) AppToast.error(context, err);
      } finally {
        if (mounted) setState(() => _patching = false);
      }
    }
    description.dispose();
    items.dispose();
    quantity.dispose();
    amount.dispose();
    remarks.dispose();
  }

  static String? _requiredField(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required' : null;

  Future<void> _pasteTaskImage() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (!mounted) return;
      if (imageBytes == null || imageBytes.isEmpty) {
        AppToast.error(context, 'No image found in the clipboard');
        return;
      }
      await _uploadTaskImageBytes(imageBytes, 'pasted-task-image.png');
    } catch (err) {
      if (mounted) AppToast.error(context, 'Unable to paste clipboard image');
    }
  }

  Future<void> _uploadTaskImageBytes(
    List<int> imageBytes,
    String fileName,
  ) async {
    final taskProvider = context.read<TaskProvider>();
    setState(() => _uploadingImage = true);
    try {
      final updatedTask = await taskProvider.uploadTaskImage(
        taskId: task.id,
        imageBytes: Uint8List.fromList(imageBytes),
        fileName: fileName,
      );
      if (!mounted) return;
      setState(() => _taskImageUrl = updatedTask?.imageUrl ?? _taskImageUrl);
      AppToast.success(context, 'Ticket image uploaded successfully');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _adminAction(String action) async {
    setState(() => _patching = true);
    try {
      await context
          .read<TaskProvider>()
          .adminAction({'taskId': task.id, 'actionType': action});
      if (mounted) {
        AppToast.success(context, 'Ticket $action successfully');
        if (action == 'quote_verified' || action == 'not_verified') {
          setState(() => _status = action);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  Future<void> _deactivateTask() async {
    final taskProvider = context.read<TaskProvider>();
    final confirmed = await _confirm(
      title: 'Delete Ticket',
      message:
          'Are you sure you want to delete this ticket? It will be deactivated.',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _patching = true);
    try {
      await taskProvider.deactivateTask(task.id);
      if (mounted) {
        AppToast.success(context, 'Ticket deleted successfully');
        Navigator.pop(context, true);
      }
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = Roles.isAdminLike(auth.currentUser?.role);
    final isAssignedToMe = _assignedUserId == auth.currentUser?.id;
    final canWork = isAssignedToMe && !auth.isSuperAdmin;
    final canTakeAcknowledgedAction = canWork && _status == 'acknowledgement';
    final canStart = canWork && _status == 'on_hold';
    final canMarkComplete =
        canWork && (_status == 'in_progress' || _status == 'quote_verified');
    final canSendQuote =
        canWork && (_status == 'in_progress' || _status == 'not_verified');
    final canAdminReview = isAdmin && !auth.isSuperAdmin;
    return Scaffold(
      backgroundColor: AppTheme.workspace,
      appBar: AppBar(
        title: const Text('Ticket Details'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          if (_patching) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],
          _TaskSummaryCard(
            task: task,
            status: _status,
            assignedUserName: _assignedUserName(),
            createdByName: _createdByName(),
            createdDate: _dateOnly(task.createdAt),
            issueDate: _dateOnly(task.issueDate),
            pickedUpDate: _dateTime(_pickedUpAt),
            dueDate: task.dueDate == null
                ? 'No due date'
                : DateFormat('dd MMM yyyy, hh:mm a')
                    .format(task.dueDate!.toLocal()),
          ),
          if (canWork || canAdminReview) ...[
            const SizedBox(height: 16),
            _TaskImageCard(
              imageUrl: _taskImageUrl,
              uploading: _uploadingImage,
              onUpload: _uploadingImage ? null : _uploadTaskImage,
              onPaste: _uploadingImage ? null : _pasteTaskImage,
            ),
          ],
          if ((task.raw['quotes'] as List? ?? const []).isNotEmpty) ...[
            const SizedBox(height: 16),
            _QuoteReviewCard(
              quote: Map<String, dynamic>.from(
                  (task.raw['quotes'] as List).first as Map),
              status: _status,
              isAdmin: canAdminReview,
              busy: _patching,
              onVerified: () => _adminAction('quote_verified'),
              onNotVerified: () => _adminAction('not_verified'),
            ),
          ],
          if (canTakeAcknowledgedAction) ...[
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(
                    icon: Icons.task_alt_outlined,
                    title: 'Ticket Actions',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: !_patching
                            ? () => _changeStatus('sent_quote')
                            : null,
                        icon: const Icon(Icons.request_quote_outlined),
                        label: const Text('Sent Quote'),
                      ),
                      ElevatedButton.icon(
                        onPressed: !_patching
                            ? () => _changeStatus('completed')
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Completed'),
                      ),
                      OutlinedButton.icon(
                        onPressed: !_patching
                            ? () => _changeStatus('not_relevant')
                            : null,
                        icon: const Icon(Icons.not_interested_outlined),
                        label: const Text('Not Relevant'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (canStart || canSendQuote || canMarkComplete) ...[
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(
                    icon: Icons.task_alt_outlined,
                    title: 'My Work',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canStart)
                        ElevatedButton.icon(
                          onPressed: !_patching
                              ? () => _changeStatus('in_progress')
                              : null,
                          icon: const Icon(Icons.play_arrow_outlined),
                          label: Text(_status == 'on_hold'
                              ? 'Resume Work'
                              : 'Start Work'),
                        ),
                      if (canSendQuote)
                        OutlinedButton.icon(
                          onPressed: !_patching ? _sendQuote : null,
                          icon: const Icon(Icons.request_quote_outlined),
                          label: const Text('Send Quote'),
                        ),
                      if (canMarkComplete)
                        OutlinedButton.icon(
                          onPressed: !_patching
                              ? () => _changeStatus('completed')
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Completed'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (canAdminReview &&
              ['sent_quote', 'completed', 'not_relevant']
                  .contains(_status)) ...[
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(
                    icon: Icons.fact_check_outlined,
                    title: 'Ticket Verification',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            !_patching ? () => _changeStatus('closed') : null,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verified'),
                      ),
                      OutlinedButton.icon(
                        onPressed: !_patching
                            ? () => _changeStatus('not_verified')
                            : null,
                        icon: const Icon(Icons.gpp_bad_outlined),
                        label: const Text('Not Verified'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reassignTask() async {
    final usersProvider = context.read<UserProvider>();
    if (usersProvider.users.isEmpty && !usersProvider.loading) {
      await usersProvider.loadUsers();
    }
    if (!mounted) return;

    final selected = await showDialog<AppUser>(
      context: context,
      builder: (context) => _ReassignTaskDialog(
        users: usersProvider.users
            .where((user) =>
                user.id != _assignedUserId &&
                !user.isDeleted &&
                _canReceiveReassignedTask(user))
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _patching = true);
    try {
      await context.read<TaskProvider>().assignTask(
        task.id,
        {'assignedToId': selected.id},
      );
      if (!mounted) return;
      setState(() {
        _assignedUserId = selected.id;
        _assignedUserLabel =
            selected.name.isEmpty ? selected.email : selected.name;
        _status = 'assigned';
        _pickedUpAt = null;
      });
      AppToast.success(
        context,
        'Ticket reassigned to ${_assignedUserLabel ?? 'selected user'}',
      );
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  bool _canReceiveReassignedTask(AppUser user) {
    final role = user.role.toLowerCase().trim();
    return role == 'employee' || role == 'intern';
  }

  String _assignedUserName() {
    if (_assignedUserLabel != null && _assignedUserLabel!.trim().isNotEmpty) {
      return _assignedUserLabel!;
    }
    final assigned = task.raw['assignedUser'];
    if (assigned is Map) {
      final name = assigned['name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name;
      final email = assigned['email']?.toString();
      if (email != null && email.trim().isNotEmpty) return email;
    }
    return _assignedUserId?.toString() ?? 'Unassigned';
  }

  String? _readAssignedUserName() {
    return _readAssignedUserNameFrom(task);
  }

  String? _readAssignedUserNameFrom(TaskItem source) {
    final assigned = source.raw['assignedUser'];
    if (assigned is Map) {
      final name = assigned['name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name;
      final email = assigned['email']?.toString();
      if (email != null && email.trim().isNotEmpty) return email;
    }
    return null;
  }

  String _createdByName() {
    final createdBy = task.raw['createdByUser'];
    if (createdBy is Map) {
      final name = createdBy['name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name;
      final email = createdBy['email']?.toString();
      if (email != null && email.trim().isNotEmpty) return email;
    }
    return task.createdBy?.toString() ?? 'Unknown';
  }

  String _dateOnly(DateTime? value) => value == null
      ? 'Unknown'
      : DateFormat('dd MMM yyyy').format(value.toLocal());

  String _dateTime(DateTime? value) => value == null
      ? 'Not picked up yet'
      : DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
}

class _ReassignTaskDialog extends StatefulWidget {
  const _ReassignTaskDialog({required this.users});

  final List<AppUser> users;

  @override
  State<_ReassignTaskDialog> createState() => _ReassignTaskDialogState();
}

class _ReassignTaskDialogState extends State<_ReassignTaskDialog> {
  AppUser? _selectedUser;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reassign Ticket'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select the new owner for this ticket.',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (widget.users.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'No other users available.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            DropdownButtonFormField<AppUser>(
              initialValue: _selectedUser,
              decoration: const InputDecoration(
                labelText: 'Assign to',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: widget.users
                  .map(
                    (user) => DropdownMenuItem<AppUser>(
                      value: user,
                      child: Text(
                        user.name.isEmpty ? user.email : user.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedUser = value),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _selectedUser == null
              ? null
              : () => Navigator.pop(context, _selectedUser),
          icon: const Icon(Icons.swap_horiz_outlined),
          label: const Text('Reassign'),
        ),
      ],
    );
  }
}

class _QuoteReviewCard extends StatelessWidget {
  const _QuoteReviewCard({
    required this.quote,
    required this.status,
    required this.isAdmin,
    required this.busy,
    required this.onVerified,
    required this.onNotVerified,
  });

  final Map<String, dynamic> quote;
  final String status;
  final bool isAdmin;
  final bool busy;
  final VoidCallback onVerified;
  final VoidCallback onNotVerified;

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse('${quote['amount'] ?? 0}') ?? 0;
    final awaitingReview = status == 'quote_sent';
    final verificationText = switch (status) {
      'quote_verified' => 'Verified',
      'not_verified' => 'Not Verified',
      _ => 'Awaiting Admin Verification',
    };
    final verificationColor = switch (status) {
      'quote_verified' => const Color(0xFF15803D),
      'not_verified' => const Color(0xFFDC2626),
      _ => const Color(0xFFB45309),
    };
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.request_quote_outlined,
            title: 'Submitted Quote',
          ),
          const SizedBox(height: 12),
          Text('Description: ${quote['description'] ?? '-'}'),
          const SizedBox(height: 6),
          Text('Required items/services: ${quote['requiredItems'] ?? '-'}'),
          const SizedBox(height: 6),
          Text('Quantity: ${quote['quantity'] ?? '-'}'),
          const SizedBox(height: 6),
          Text(
            'Amount: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount)}',
          ),
          const SizedBox(height: 6),
          Text('Remarks: ${quote['remarks'] ?? '-'}'),
          if ('${quote['attachmentUrl'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              'Attachment: ${quote['attachmentUrl']}',
              style: const TextStyle(color: AppTheme.primary),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            verificationText,
            style: TextStyle(
              color: verificationColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isAdmin && awaitingReview) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: busy ? null : onVerified,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verified'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onNotVerified,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Not Verified'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({
    required this.task,
    required this.status,
    required this.assignedUserName,
    required this.createdByName,
    required this.createdDate,
    required this.issueDate,
    required this.pickedUpDate,
    required this.dueDate,
  });

  final TaskItem task;
  final String status;
  final String assignedUserName;
  final String createdByName;
  final String createdDate;
  final String issueDate;
  final String pickedUpDate;
  final String dueDate;

  @override
  Widget build(BuildContext context) {
    final priority = (task.priority ?? 'normal').replaceAll('_', ' ');
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.task_alt_outlined,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _LightPill(
                                icon: Icons.flag_outlined,
                                label: _statusLabel(status),
                              ),
                              _LightPill(
                                icon: Icons.priority_high_outlined,
                                label: priority,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.notes_outlined,
                  title: 'Description',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    task.description?.isNotEmpty == true
                        ? task.description!
                        : 'No description provided.',
                    style: TextStyle(
                      color: Colors.grey[800],
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (task.remarks?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  const _SectionTitle(
                    icon: Icons.comment_outlined,
                    title: 'Remarks',
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(task.remarks!,
                        style:
                            TextStyle(color: Colors.grey[800], height: 1.42)),
                  ),
                ],
                const SizedBox(height: 16),
                _InfoGrid(
                  children: [
                    _InfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Issue date',
                      value: issueDate,
                    ),
                    _InfoTile(
                      icon: Icons.person_outline,
                      label: 'Assigned to',
                      value: assignedUserName,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String value) {
    if (value.trim().isEmpty) return 'Unknown';
    if (value.toLowerCase() == 'not_verified') return 'Not Verified';
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _LightPill extends StatelessWidget {
  const _LightPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 430 ? 2 : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskImageCard extends StatelessWidget {
  const _TaskImageCard({
    required this.imageUrl,
    required this.uploading,
    required this.onUpload,
    required this.onPaste,
  });

  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onUpload;
  final VoidCallback? onPaste;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.image_outlined,
            title: 'Ticket Image',
          ),
          const SizedBox(height: 12),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  color: const Color(0xFFF3F4F6),
                  child: const Text('Unable to load image'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'No image uploaded for this ticket.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
                onPressed: onUpload,
                icon: uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(uploading
                    ? 'Uploading...'
                    : hasImage
                        ? 'Change Image'
                        : 'Upload Image'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({
    required this.comments,
    required this.controller,
    required this.editController,
    required this.loading,
    required this.saving,
    required this.editingCommentId,
    required this.currentUserEmail,
    required this.isAdmin,
    required this.onAdd,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
  });

  final List<TaskComment> comments;
  final TextEditingController controller;
  final TextEditingController editController;
  final bool loading;
  final bool saving;
  final int? editingCommentId;
  final String? currentUserEmail;
  final bool isAdmin;
  final VoidCallback onAdd;
  final ValueChanged<TaskComment> onStartEdit;
  final VoidCallback onCancelEdit;
  final ValueChanged<int> onSaveEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.comment_outlined,
                  title: 'Comments',
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${comments.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ] else if (comments.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text('No comments yet.',
                  style: TextStyle(
                      color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
          ] else ...[
            ...comments.map((comment) => _CommentTile(
                  comment: comment,
                  editController: editController,
                  editing: editingCommentId == comment.id,
                  canManage: isAdmin || comment.userEmail == currentUserEmail,
                  saving: saving,
                  onStartEdit: () => onStartEdit(comment),
                  onCancelEdit: onCancelEdit,
                  onSaveEdit: () => onSaveEdit(comment.id),
                  onDelete: () => onDelete(comment.id),
                )),
            const SizedBox(height: 4),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Add a comment',
                hintText: 'Write your comment...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: saving ? null : onAdd,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_comment_outlined),
              label: Text(saving ? 'Adding...' : 'Add Comment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.editController,
    required this.editing,
    required this.canManage,
    required this.saving,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
  });

  final TaskComment comment;
  final TextEditingController editController;
  final bool editing;
  final bool canManage;
  final bool saving;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  comment.userName?.isNotEmpty == true
                      ? comment.userName!
                      : (comment.userEmail ?? 'User'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment.createdAt == null
                    ? ''
                    : DateFormat('dd MMM, hh:mm a')
                        .format(comment.createdAt!.toLocal()),
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (editing) ...[
            TextField(
              controller: editController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Update comment'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: saving ? null : onSaveEdit,
                  child: const Text('Save'),
                ),
                OutlinedButton(
                  onPressed: saving ? null : onCancelEdit,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else ...[
            Text(comment.comments, style: TextStyle(color: Colors.grey[800])),
            if (comment.isEdited) ...[
              const SizedBox(height: 4),
              Text('Edited',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ],
            if (canManage) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: saving ? null : onStartEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit comment',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: saving ? null : onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: const Color(0xFFDC2626),
                    tooltip: 'Delete comment',
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
