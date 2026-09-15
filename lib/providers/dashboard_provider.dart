import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../services/api_client.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._api);

  final ApiClient _api;
  Map<String, dynamic>? overview;
  List<dynamic> statusBreakdown = [];
  List<dynamic> distribution = [];
  List<TaskItem> recentTasks = [];
  bool loading = false;
  String? error;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;

    try {
      final results = await Future.wait([
        _api.get('/dashboard/overview'),
        _api.get('/dashboard/status-breakdown'),
        _api.get('/dashboard/task-distribution-by-user'),
        _api.get('/tasks/getAlltask', params: {'page': 1, 'limit': 10}),
      ]);
      final overviewRes = results[0] as Map<String, dynamic>;
      overview = (overviewRes['data'] ?? overviewRes) as Map<String, dynamic>;
      final statusRes = results[1] as Map<String, dynamic>;
      statusBreakdown = (statusRes['data'] as List?) ?? [];
      final distributionRes = results[2] as Map<String, dynamic>;
      distribution = (distributionRes['data'] as List?) ?? [];
      final recentTasksRes = results[3] as Map<String, dynamic>;
      final recentTaskList = (recentTasksRes['data'] as List?) ?? [];
      recentTasks = recentTaskList
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList();
    } catch (err) {
      error = err.toString();
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }
}
