import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../services/api_client.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider(this._api);

  final ApiClient _api;
  List<Expense> expenses = [];
  bool loading = false;
  String? error;
  int total = 0;

  Future<void> load({String? status, bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;

    try {
      final loaded = <Expense>[];
      Object? expenseError;
      Object? purchaseOrderError;

      try {
        final res = await _api.get('/expenses', params: {
          'limit': 100,
          if (status != null && status.isNotEmpty) 'status': status,
        }) as Map<String, dynamic>;
        final list = (res['data'] as List?) ?? [];
        loaded.addAll(list
            .whereType<Map>()
            .map((item) => Expense.fromJson(Map<String, dynamic>.from(item))));
      } catch (err) {
        expenseError = err;
      }

      // PO daily expenses are stored separately by the existing production API.
      // Load them from PO details so they also appear in the Expenses menu.
      try {
        final response = await _api.get('/purchase-orders');
        final rawOrders = response is Map ? response['data'] : null;
        final orders = rawOrders is List
            ? rawOrders.whereType<Map>().map(Map<String, dynamic>.from).toList()
            : <Map<String, dynamic>>[];
        final details = await Future.wait(orders.map((order) async {
          final id = int.tryParse('${order['id']}');
          if (id == null) return <Map<String, dynamic>>[];
          final response = await _api.get('/purchase-orders/$id');
          final detail = response is Map && response['data'] is Map
              ? Map<String, dynamic>.from(response['data'] as Map)
              : <String, dynamic>{};
          final bank = detail['category'] is Map
              ? '${detail['category']['name'] ?? '-'}'
              : '-';
          final branch = '${detail['branchName'] ?? '-'}';
          final rawExpenses = detail['expenses'];
          if (rawExpenses is! List) return <Map<String, dynamic>>[];
          return rawExpenses.whereType<Map>().map((item) {
            final poExpense = Map<String, dynamic>.from(item);
            final expenseId = int.tryParse('${poExpense['id']}') ?? 0;
            return <String, dynamic>{
              'id': -expenseId,
              'title': poExpense['description'] ?? 'PO Expense',
              'description': poExpense['description'],
              'amount': poExpense['amount'],
              'expenseDate': poExpense['expenseDate'],
              'createdat': poExpense['createdat'],
              'category': poExpense['category'],
              'bankName': bank,
              'branchName': branch,
              'status': 'recorded',
              'taskMaps': const [],
            };
          }).toList();
        }));
        if (status == null || status.isEmpty) {
          final existingIds = loaded.map((expense) => expense.id).toSet();
          loaded.addAll(details
              .expand((items) => items)
              .map(Expense.fromJson)
              .where((expense) => !existingIds.contains(expense.id)));
        }
      } catch (err) {
        purchaseOrderError = err;
      }

      if (expenseError != null && purchaseOrderError != null) {
        throw expenseError;
      }
      loaded.sort((first, second) {
        final firstDate = first.createdAt ?? first.expenseDate;
        final secondDate = second.createdAt ?? second.expenseDate;
        if (firstDate == null) return 1;
        if (secondDate == null) return -1;
        return secondDate.compareTo(firstDate);
      });
      expenses = loaded;
      total = loaded.length;
    } catch (err) {
      error = err.toString();
      expenses = [];
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _api.post('/expenses', payload);
  }

  Future<void> review({
    required int id,
    required String status,
    required String adminRemarks,
  }) async {
    await _api.put('/expenses/$id/review', {
      'status': status,
      'adminRemarks': adminRemarks,
    });
  }
}
