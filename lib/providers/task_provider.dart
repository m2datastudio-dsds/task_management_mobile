import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/sub_activity.dart';
import '../services/api_client.dart';

class TaskComment {
  const TaskComment({
    required this.id,
    required this.comments,
    this.userId,
    this.userName,
    this.userEmail,
    this.createdAt,
    this.isEdited = false,
  });

  final int id;
  final String comments;
  final int? userId;
  final String? userName;
  final String? userEmail;
  final DateTime? createdAt;
  final bool isEdited;

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    return TaskComment(
      id: int.tryParse('${json['id']}') ?? 0,
      comments: (json['comments'] ?? '').toString(),
      userId: json['userId'] == null ? null : int.tryParse('${json['userId']}'),
      userName: json['userName']?.toString(),
      userEmail: json['userEmail']?.toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse('${json['createdAt']}'),
      isEdited: json['isEdited'] == true,
    );
  }
}

class TaskProvider extends ChangeNotifier {
  TaskProvider(this._api);

  final ApiClient _api;
  List<TaskItem> tasks = [];
  int page = 1;
  int total = 0;
  bool loading = false;
  String? error;
  _TaskQuery? _lastQuery;
  int _requestVersion = 0;

  bool get hasLoadedTasks => _lastQuery != null;

  Future<void> loadTasks({
    required bool adminView,
    required int userId,
    int pageNo = 1,
    int limit = 10,
    bool silent = false,
    int? categoryId,
  }) async {
    final query = _TaskQuery(
      adminView: adminView,
      userId: userId,
      pageNo: pageNo,
      limit: limit,
      categoryId: categoryId,
    );
    _lastQuery = query;
    final requestVersion = ++_requestVersion;
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;

    try {
      final endpoint =
          adminView ? '/tasks/getAlltask' : '/tasks/tasksByuser/$userId';
      final res = await _api.get(endpoint, params: {
        'page': pageNo,
        'limit': limit,
        if (categoryId != null) 'categoryId': categoryId,
      }) as Map<String, dynamic>;
      final list = (res['data'] as List?) ?? [];
      if (requestVersion != _requestVersion) return;
      tasks = list
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .where((task) => adminView || task.status?.toLowerCase() != 'closed')
          .toList();
      page = int.tryParse('${res['page'] ?? pageNo}') ?? pageNo;
      total = int.tryParse('${res['total'] ?? tasks.length}') ?? tasks.length;
    } catch (err) {
      if (requestVersion != _requestVersion) return;
      error = err.toString();
      tasks = [];
    } finally {
      if (requestVersion == _requestVersion) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshCurrentTasks({bool silent = true}) async {
    final query = _lastQuery;
    if (query == null) return;
    await loadTasks(
      adminView: query.adminView,
      userId: query.userId,
      pageNo: query.pageNo,
      limit: query.limit,
      silent: silent,
      categoryId: query.categoryId,
    );
  }

  Future<TaskItem?> createTask(
    Map<String, dynamic> payload, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final fields = payload.map(
      (key, value) => MapEntry(key, value is String ? value : '$value'),
    );
    final res = await _api.uploadFile(
      'POST',
      '/tasks/create',
      fieldName: 'image',
      bytes: imageBytes,
      filename: imageName,
      fields: fields,
    );
    if (res is Map<String, dynamic> && res['task'] is Map<String, dynamic>) {
      return TaskItem.fromJson(res['task'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<SubActivity>> loadSubActivities(int taskId) async {
    final response = await _api.get('/sub-activities/task/$taskId') as List;
    return response
        .whereType<Map<String, dynamic>>()
        .map(SubActivity.fromJson)
        .toList();
  }

  Future<void> createSubActivity(
      int taskId, Map<String, dynamic> payload) async {
    await _api.post('/sub-activities/task/$taskId', payload);
  }

  Future<void> updateSubActivity(
      int activityId, Map<String, dynamic> payload) async {
    await _api.put('/sub-activities/$activityId', payload);
  }

  Future<void> deleteSubActivity(int activityId) async {
    await _api.delete('/sub-activities/$activityId');
  }

  Future<TaskItem?> uploadTaskImage({
    required int taskId,
    String? imagePath,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    final res = await _api.uploadFile(
      'PUT',
      '/tasks/$taskId/image',
      fieldName: 'image',
      filePath: imagePath,
      bytes: imageBytes,
      filename: fileName,
    );
    if (res is Map<String, dynamic> && res['task'] is Map<String, dynamic>) {
      return TaskItem.fromJson(res['task'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> changeStatus(
      {required int taskId, required String statusName}) async {
    await _api.post('/tasks/change-status', {
      'taskId': taskId,
      'statusName': statusName,
    });
  }

  Future<void> sendQuote({
    required int taskId,
    required Map<String, String> fields,
    Uint8List? attachmentBytes,
    String? attachmentName,
  }) async {
    await _api.uploadFile(
      'POST',
      '/tasks/$taskId/quote',
      fieldName: 'attachment',
      bytes: attachmentBytes,
      filename: attachmentName,
      fields: fields,
    );
  }

  Future<void> adminAction(Map<String, dynamic> payload) async {
    await _api.post('/tasks/admin-action', payload);
  }

  Future<void> assignTask(int taskId, Map<String, dynamic> payload) async {
    await _api.put('/tasks/$taskId/assign', payload);
  }

  Future<void> deactivateTask(int taskId) async {
    await _api.put('/tasks/$taskId/deactivate', {});
  }

  Future<TaskItem?> updateTicket(
      int taskId, Map<String, dynamic> payload) async {
    final res = await _api.put('/tasks/$taskId/ticket', payload);
    if (res is Map<String, dynamic> && res['task'] is Map<String, dynamic>) {
      return TaskItem.fromJson(res['task'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<TaskComment>> loadComments(int taskId) async {
    final res =
        await _api.get('/comments/getByTask/$taskId') as Map<String, dynamic>;
    final list = (res['data'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TaskComment.fromJson)
        .toList();
  }

  Future<void> addComment(
      {required int taskId, required String comments}) async {
    await _api.post('/comments/createcomments', {
      'taskid': taskId,
      'comments': comments,
    });
  }

  Future<void> editComment({
    required int commentId,
    required String comments,
  }) async {
    await _api.put('/comments/editComments/$commentId', {
      'comments': comments,
      'isEdited': true,
    });
  }

  Future<void> deleteComment(int commentId) async {
    await _api.delete('/comments/deleteComments/$commentId',
        body: {'isDeleted': true});
  }
}

class _TaskQuery {
  const _TaskQuery({
    required this.adminView,
    required this.userId,
    required this.pageNo,
    required this.limit,
    required this.categoryId,
  });

  final bool adminView;
  final int userId;
  final int pageNo;
  final int limit;
  final int? categoryId;
}
