class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.logo,
    this.email,
    this.phone,
    this.website,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.isActive = true,
    this.organizationUserMap = const [],
  });

  final int id;
  final String name;
  final String code;
  final String? description;
  final String? logo;
  final String? email;
  final String? phone;
  final String? website;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final bool isActive;
  final List<Map<String, dynamic>> organizationUserMap;

  List<String> get adminNames {
    return organizationUserMap
        .where((item) =>
            (item['role'] ?? '').toString().toLowerCase() == 'admin' &&
            item['isactive'] != false)
        .map((item) {
          final user = item['user'];
          if (user is Map) {
            final name = user['name']?.toString();
            if (name != null && name.trim().isNotEmpty) return name;
            final email = user['email']?.toString();
            if (email != null && email.trim().isNotEmpty) return email;
          }
          return '';
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      description: json['description']?.toString(),
      logo: json['logo']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      website: json['website']?.toString(),
      addressLine1: json['addressLine1']?.toString(),
      addressLine2: json['addressLine2']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      postalCode: json['postalCode']?.toString(),
      isActive: json['isactive'] != false,
      organizationUserMap: _maps(json['organizationUserMap']),
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
