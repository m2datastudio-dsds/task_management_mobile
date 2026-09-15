import 'package:flutter/foundation.dart';

import '../models/bank.dart';
import '../services/api_client.dart';

class BankProvider extends ChangeNotifier {
  BankProvider(this._api);

  final ApiClient _api;
  List<Bank> banks = [];
  bool loading = false;
  String? error;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;
    try {
      final response = await _api.get('/categories') as List;
      banks = response
          .whereType<Map<String, dynamic>>()
          .map(Bank.fromJson)
          .toList();
    } catch (err) {
      error = err.toString();
      if (!silent) banks = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _api.post('/categories', data);
    await load();
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    await _api.put('/categories/$id', data);
    await load();
  }

  Future<void> deactivate(int id) async {
    await _api.delete('/categories/$id');
    await load();
  }
}
