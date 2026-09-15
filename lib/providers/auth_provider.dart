import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';
import '../utils/roles.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api);

  final ApiClient _api;
  AppUser? _currentUser;
  String? _token;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _organizationOptions = [];

  AppUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;
  List<Map<String, dynamic>> get organizationOptions =>
      List.unmodifiable(_organizationOptions);
  bool get requiresOrganizationSelection => _organizationOptions.isNotEmpty;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isAdmin => Roles.isAdminLike(_currentUser?.role);
  bool get isSuperAdmin => Roles.isSuperAdmin(_currentUser?.role);

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userJson = prefs.getString('currentUser');
    if (userJson != null) {
      _currentUser =
          AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }
    notifyListeners();
  }

  void clearOrganizationOptions() {
    if (_organizationOptions.isEmpty) return;
    _organizationOptions = [];
    _error = null;
    notifyListeners();
  }

  Future<bool> login({
    required String mobileNumber,
    required String password,
    String? organizationName,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post('/auth/login', {
        'mobileNumber': mobileNumber.trim(),
        'password': password,
        'organizationName': organizationName?.trim() ?? '',
      }) as Map<String, dynamic>;

      if (res['organizationRequired'] == true) {
        final organizations = res['organizations'];
        _organizationOptions = organizations is List
            ? organizations
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : [];
        _error = _organizationOptions.isEmpty
            ? 'No organization found for this user'
            : null;
        return false;
      }

      final token = res['token']?.toString();
      final user = res['user'];
      if (token == null || user is! Map<String, dynamic>) {
        throw ApiException('Invalid login response', 500);
      }

      final organization = res['organization'] is Map<String, dynamic>
          ? res['organization'] as Map<String, dynamic>
          : null;
      _organizationOptions = [];
      _token = token;
      _currentUser = AppUser.fromLogin(user, organization);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('currentUser', jsonEncode(_currentUser!.toJson()));

      return true;
    } catch (err) {
      _error = err.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('currentUser');
    _organizationOptions = [];
    _token = null;
    _currentUser = null;
    notifyListeners();
  }
}
