class Roles {
  static const superAdmin = 'super_admin';
  static const admin = 'admin';
  static const employee = 'employee';
  static const intern = 'intern';

  static bool isAdminLike(String? role) {
    final normalized = (role ?? '').toLowerCase();
    return normalized == superAdmin || normalized == admin;
  }

  static bool isSuperAdmin(String? role) {
    return (role ?? '').toLowerCase() == superAdmin;
  }
}
