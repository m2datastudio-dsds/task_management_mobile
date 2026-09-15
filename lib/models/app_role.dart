class AppRole {
  const AppRole({
    required this.id,
    required this.name,
    required this.displayName,
    this.isProtected = false,
  });

  final int id;
  final String name;
  final String displayName;
  final bool isProtected;

  factory AppRole.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['roleName'] ?? '').toString();
    return AppRole(
      id: int.tryParse('${json['id']}') ?? 0,
      name: name,
      displayName: (json['displayName'] ?? _formatName(name)).toString(),
      isProtected: json['isProtected'] == true,
    );
  }

  static String _formatName(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
