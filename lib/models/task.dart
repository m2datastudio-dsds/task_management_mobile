import '../utils/app_config.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.remarks,
    this.issueDate,
    this.status,
    this.priority,
    this.imageUrl,
    this.assignedUserId,
    this.createdBy,
    this.dueDate,
    this.createdAt,
    this.pickedUpAt,
    this.completedAt,
    this.updatedAt,
    this.organizationId,
    this.bankId,
    this.bankName,
    this.bankBranchName,
    this.bankBranchCode,
    this.bankAddress,
    this.bankContactNumber,
    this.raw = const {},
  });

  final int id;
  final String title;
  final String? description;
  final String? remarks;
  final DateTime? issueDate;
  final String? status;
  final String? priority;
  final String? imageUrl;
  final int? assignedUserId;
  final int? createdBy;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;
  final int? organizationId;
  final int? bankId;
  final String? bankName;
  final String? bankBranchName;
  final String? bankBranchCode;
  final String? bankAddress;
  final String? bankContactNumber;
  final Map<String, dynamic> raw;

  /// An assigned ticket becomes user-facing Pending only when it has remained
  /// unopened for more than three calendar days from its issue date.
  String? get displayStatus {
    final normalizedStatus = (status ?? '').toLowerCase();
    if (normalizedStatus != 'assigned' || issueDate == null) return status;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final issued = issueDate!.toLocal();
    final issuedDate = DateTime(issued.year, issued.month, issued.day);
    return todayDate.difference(issuedDate).inDays > 3 ? 'pending' : status;
  }

  int get ageingDays {
    if (createdAt == null) return 0;
    final normalizedStatus = (status ?? '').toLowerCase();
    final isFinished = ['completed', 'closed'].contains(normalizedStatus);
    final end = isFinished
        ? (completedAt ?? updatedAt ?? DateTime.now())
        : DateTime.now();
    final startDate =
        DateTime(createdAt!.year, createdAt!.month, createdAt!.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final days = endDate.difference(startDate).inDays;
    return days < 0 ? 0 : days;
  }

  String get ageingLevel {
    if (ageingDays >= 8) return 'delayed';
    if (ageingDays >= 4) return 'attention';
    return 'normal';
  }

  String get ageingLabel => '$ageingDays ${ageingDays == 1 ? 'day' : 'days'}';

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final activeMap = _activeTaskUserMap(json['taskusermap']);
    final category = json['category'] is Map ? json['category'] : json['bank'];

    return TaskItem(
      id: _int(json['id']),
      title: (json['title'] ?? 'Untitled ticket').toString(),
      description: json['description']?.toString(),
      remarks: json['remarks']?.toString(),
      issueDate: _date(json['issuedate'] ?? json['issueDate']),
      status: json['status'] is Map
          ? json['status']['name']?.toString()
          : json['status']?.toString(),
      priority: json['priority']?.toString(),
      imageUrl: _imageUrl(
        json['imageUrl'] ??
            json['imageurl'] ??
            json['image_url'] ??
            json['taskImage'] ??
            json['task_image'] ??
            json['image'],
      ),
      assignedUserId: _nullableInt(
        json['userid'] ??
            json['assignedToId'] ??
            _nestedId(json['assignedUser']) ??
            activeMap?['userid'],
      ),
      createdBy:
          _nullableInt(json['createdby'] ?? _nestedId(json['createdByUser'])),
      dueDate: _date(json['duedate'] ?? json['dueDate']),
      createdAt: _date(json['createdat'] ?? json['createdAt']),
      pickedUpAt: _date(
        json['pickedupat'] ??
            json['pickedUpAt'] ??
            activeMap?['pickedupat'] ??
            activeMap?['pickedUpAt'],
      ),
      completedAt: _date(
        json['completedat'] ??
            json['completedAt'] ??
            activeMap?['completedat'] ??
            activeMap?['completedAt'],
      ),
      updatedAt: _date(
        json['updatedat'] ??
            json['updatedAt'] ??
            activeMap?['updatedat'] ??
            activeMap?['updatedAt'] ??
            activeMap?['removedat'] ??
            activeMap?['removedAt'],
      ),
      organizationId: _nullableInt(json['orgid'] ?? json['organizationId']),
      bankId: _nullableInt(json['categoryid'] ??
          json['categoryId'] ??
          json['bankid'] ??
          json['bankId'] ??
          _nestedId(category)),
      bankName: category is Map ? category['name']?.toString() : null,
      bankBranchName: json['branchName']?.toString() ??
          (category is Map
              ? (category['branchName'] ?? category['description'])?.toString()
              : null),
      bankBranchCode:
          category is Map ? category['branchCode']?.toString() : null,
      bankAddress: category is Map ? category['address']?.toString() : null,
      bankContactNumber: category is Map
          ? (category['phoneNumber'] ?? category['contactNumber'])?.toString()
          : null,
      raw: json,
    );
  }

  static int _int(dynamic value) => int.tryParse('$value') ?? 0;

  static int? _nullableInt(dynamic value) =>
      value == null ? null : int.tryParse('$value');

  static dynamic _nestedId(dynamic value) => value is Map ? value['id'] : null;

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value')?.toLocal();
  }

  static String? _imageUrl(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final apiUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      return raw;
    }

    final origin = '${apiUri.scheme}://${apiUri.authority}';
    if (raw.startsWith('/')) return '$origin$raw';
    if (raw.startsWith('uploads/')) return '$origin/$raw';
    return raw;
  }

  static Map<String, dynamic>? _activeTaskUserMap(dynamic value) {
    if (value is! List) return null;

    for (final item in value) {
      if (item is Map && item['isactive'] == true) {
        return Map<String, dynamic>.from(item);
      }
    }

    for (final item in value) {
      if (item is Map) return Map<String, dynamic>.from(item);
    }

    return null;
  }
}
