import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../models/app_user.dart';
import '../models/task.dart';
import '../services/api_client.dart';

class UserProvider extends ChangeNotifier {
  UserProvider(this._api);

  final ApiClient _api;
  List<AppUser> users = [];
  List<AppUser> admins = [];
  List<AppRole> roles = [];
  Map<int, int> taskCounts = {};
  bool loading = false;
  bool rolesLoading = false;
  String? error;
  String? rolesError;

  Future<void> loadUsers({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;

    try {
      final usersRes = await _api.get('/tasks/getAllUser', params: {
        'includeDeleted': true,
        'limit': 1000,
      }) as Map<String, dynamic>;
      final userList = (usersRes['data'] ?? usersRes['users'] ?? []) as List;
      users = userList
          .whereType<Map<String, dynamic>>()
          .map(AppUser.fromJson)
          .toList();

      try {
        final tasksRes = await _api.get('/tasks/getAlltask', params: {
          'page': 1,
          'limit': 1000,
        }) as Map<String, dynamic>;
        final taskList = (tasksRes['data'] as List?) ?? [];
        final counts = <int, int>{};
        for (final taskJson in taskList.whereType<Map<String, dynamic>>()) {
          final task = TaskItem.fromJson(taskJson);
          final userId = task.assignedUserId;
          if (userId != null) counts[userId] = (counts[userId] ?? 0) + 1;
        }
        taskCounts = counts;
      } catch (err) {
        debugPrint('Unable to load task counts for users: $err');
        taskCounts = {};
      }
    } catch (err) {
      error = _messageFromError(err);
      users = [];
      taskCounts = {};
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdmins() async {
    final res = await _api.get('/auth/admins') as Map<String, dynamic>;
    final list = (res['admins'] as List?) ?? [];
    admins =
        list.whereType<Map<String, dynamic>>().map(AppUser.fromJson).toList();
    notifyListeners();
  }

  Future<void> loadRoles({bool silent = false}) async {
    if (!silent) {
      rolesLoading = true;
      notifyListeners();
    }
    rolesError = null;

    try {
      final res = await _api.get('/auth/roles') as Map<String, dynamic>;
      final list = (res['roles'] as List?) ?? [];
      roles =
          list.whereType<Map<String, dynamic>>().map(AppRole.fromJson).toList();
    } catch (err) {
      rolesError = _messageFromError(err);
      roles = [];
    } finally {
      if (!silent) rolesLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRole(String roleName) async {
    await _api.post('/auth/roles', {'roleName': roleName});
    await loadRoles(silent: true);
  }

  Future<void> createUser(Map<String, dynamic> payload) async {
    await _api.post('/auth/register', payload);
  }

  Future<void> updateUserMobile(int userId, String mobile) async {
    await _api.put('/auth/users/$userId/mobile', {'mobile': mobile});
    users = users
        .map((user) => user.id == userId
            ? AppUser(
                id: user.id,
                name: user.name,
                email: user.email,
                mobile: mobile,
                role: user.role,
                organizationId: user.organizationId,
                organizationName: user.organizationName,
                organizationLogo: user.organizationLogo,
                createdAt: user.createdAt,
                isDeleted: user.isDeleted,
                organizations: user.organizations,
              )
            : user)
        .toList();
    notifyListeners();
  }

  Future<void> deactivateUser(int userId) async {
    await _api.put('/tasks/$userId/deactivateUser', {});
    users = users
        .map((user) => user.id == userId
            ? AppUser(
                id: user.id,
                name: user.name,
                email: user.email,
                mobile: user.mobile,
                role: user.role,
                organizationId: user.organizationId,
                organizationName: user.organizationName,
                organizationLogo: user.organizationLogo,
                createdAt: user.createdAt,
                isDeleted: true,
                organizations: user.organizations,
              )
            : user)
        .toList();
    notifyListeners();
  }

  String _messageFromError(Object err) {
    final message = err.toString().trim();
    if (message.isEmpty) return 'Something went wrong';
    return message
        .replaceFirst(RegExp(r'^(Exception|ApiException):\s*'), '')
        .trim();
  }
}
