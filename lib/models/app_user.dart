class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.role,
    this.organizationId,
    this.organizationName,
    this.organizationLogo,
    this.organizationAddress,
    this.createdAt,
    this.isDeleted = false,
    this.organizations = const [],
  });

  final int id;
  final String name;
  final String email;
  final String mobile;
  final String role;
  final int? organizationId;
  final String? organizationName;
  final String? organizationLogo;
  final String? organizationAddress;
  final DateTime? createdAt;
  final bool isDeleted;
  final List<Map<String, dynamic>> organizations;

  factory AppUser.fromLogin(
      Map<String, dynamic> user, Map<String, dynamic>? org) {
    return AppUser(
      id: _int(user['id']),
      name: (user['name'] ?? user['fullName'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      mobile: (user['mobile'] ?? user['mobileNumber'] ?? '').toString(),
      role: (user['role'] ?? '').toString(),
      organizationId: org == null ? null : _nullableInt(org['id']),
      organizationName: org == null ? null : org['name']?.toString(),
      organizationLogo: org == null ? null : org['logo']?.toString(),
      organizationAddress: org == null ? null : _organizationAddress(org),
      createdAt: _date(user['createdat'] ?? user['createdAt']),
      isDeleted: user['isdeleted'] == true || user['isDeleted'] == true,
      organizations: _organizations(user['organizations']),
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final orgs = _organizations(json['organizations']);
    final firstOrg = orgs.isEmpty ? null : orgs.first;

    return AppUser(
      id: _int(json['id']),
      name: (json['name'] ?? json['fullName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      mobile: (json['mobile'] ?? json['mobileNumber'] ?? '').toString(),
      role: (json['role'] ?? json['roleName'] ?? '').toString(),
      organizationId: _nullableInt(
          json['organizationId'] ?? json['orgid'] ?? firstOrg?['id']),
      organizationName:
          json['organizationName']?.toString() ?? firstOrg?['name']?.toString(),
      organizationLogo: json['organizationLogo']?.toString(),
      organizationAddress: json['organizationAddress']?.toString() ??
          (firstOrg == null ? null : _organizationAddress(firstOrg)),
      createdAt: _date(json['createdat'] ?? json['createdAt']),
      isDeleted: json['isdeleted'] == true || json['isDeleted'] == true,
      organizations: orgs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'mobile': mobile,
        'role': role,
        'organizationId': organizationId,
        'organizationName': organizationName,
        'organizationLogo': organizationLogo,
        'organizationAddress': organizationAddress,
        'createdAt': createdAt?.toIso8601String(),
        'isDeleted': isDeleted,
        'organizations': organizations,
      };

  static int _int(dynamic value) => int.tryParse('$value') ?? 0;

  static int? _nullableInt(dynamic value) =>
      value == null ? null : int.tryParse('$value');

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse('$value');

  static List<Map<String, dynamic>> _organizations(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String? _organizationAddress(Map<dynamic, dynamic> organization) {
    final parts = [
      organization['addressLine1'],
      organization['addressLine2'],
      organization['city'],
      organization['state'],
      organization['country'],
      organization['postalCode'],
    ]
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
