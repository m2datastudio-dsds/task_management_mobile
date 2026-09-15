import 'package:flutter/foundation.dart';

import '../models/organization.dart';
import '../services/api_client.dart';

class OrganizationProvider extends ChangeNotifier {
  OrganizationProvider(this._api);

  final ApiClient _api;
  List<Organization> organizations = [];
  bool loading = false;
  String? error;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;

    try {
      final res = await _api.get('/organizations/getallOrganization');
      final list = res is List
          ? res
          : ((res as Map<String, dynamic>)['data'] as List? ?? []);
      organizations = list
          .whereType<Map<String, dynamic>>()
          .map(Organization.fromJson)
          .toList();
    } catch (err) {
      error = err.toString();
      organizations = [];
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _api.post('/organizations/createOrganization', payload);
  }

  Future<void> update(int id, Map<String, dynamic> payload) async {
    await _api.put('/organizations/updateOrganization/$id', payload);
  }

  Future<void> delete(int id) async {
    await _api.delete('/organizations/deleteOrganization/$id');
  }
}
